//
//  RecipeFeedView.swift
//  FridgeWise
//
//  Feed de recetas con tres pestañas: lo generado para ti, lo de la comunidad
//  y lo guardado. La publicidad se intercala cada 6 tarjetas y solo si el plan
//  lo amerita — la decisión la toma `AdCoordinator`, no esta vista.
//

import SwiftUI

struct RecipeFeedView: View {

    @Environment(\.app) private var app
    @Binding var isTabBarDimmed: Bool

    @State private var scope: Scope = .forYou
    @State private var activeTags: Set<RecipeTag> = []
    @State private var isGenerating = false
    @State private var isComposing = false

    enum Scope: String, CaseIterable, Hashable {
        case forYou, community, saved

        var title: String {
            switch self {
            case .forYou:    String(localized: "Para ti")
            case .community: String(localized: "Comunidad")
            case .saved:     String(localized: "Guardadas")
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                header
                segments
                generateCard
                composeCard

                if scope != .saved {
                    filterRail
                }

                feed

                if scope == .saved {
                    recentlyViewedSection
                }
            }
            .padding(.top, Space.xs)
            .padding(.bottom, Space.tabBarInset)
            .readsScrollDirection(into: $isTabBarDimmed)
        }
        .coordinateSpace(name: "scroll")
        .scrollIndicators(.hidden)
        .editorialScrollFeel()
        .canvasBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isGenerating) {
            GenerationSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Palette.canvas)
        }
        .sheet(isPresented: $isComposing) {
            RecipeComposerSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Palette.canvas)
        }
        .task { await app.ads.loadNativeAd() }
        .onChange(of: scope) { _, _ in
            Task { await app.ads.loadNativeAd() }
        }
    }

    // MARK: - Encabezado

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "Qué puedes")).displayStyle(31)
            HStack(spacing: 9) {
                Text(String(localized: "cocinar"))
                    .font(Typeface.displayItalic(31))
                    .foregroundStyle(Palette.ink)
                    .squiggleUnderline(Palette.sage)
                Text(String(localized: "hoy")).displayStyle(31)
            }
            .padding(.bottom, Space.xxs)
        }
        .screenPadding()
        .accessibilityElement(children: .combine)
    }

    private var segments: some View {
        MorphingSegments(
            items: Scope.allCases,
            title: \.title,
            badge: { scope in
                scope == .saved && !app.savedRecipeIDs.isEmpty ? app.savedRecipeIDs.count : nil
            },
            selection: $scope
        )
        .screenPadding()
    }

    // MARK: - Generar

    private var generateCard: some View {
        Button {
            Haptics.commit()
            isGenerating = true
        } label: {
            HStack(spacing: Space.md) {
                ZStack {
                    Circle().fill(Palette.plum.opacity(0.15))
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Palette.plum)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Generar con lo que tienes"))
                        .font(Typeface.headline)
                        .foregroundStyle(Palette.ink)
                    Text(generateSubtitle)
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkSoft)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.plum)
            }
            .padding(Space.md)
            .background {
                RoundedRectangle.soft(Radius.card)
                    .fill(Palette.surface)
                    .overlay {
                        FluidBackdrop(palette: .intelligence, intensity: 0.22)
                            .clipShape(RoundedRectangle.soft(Radius.card))
                    }
            }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(Palette.plum.opacity(0.22), lineWidth: Stroke.hairline)
            }
        }
        .buttonStyle(.pressableCard)
        .screenPadding()
    }

    private var generateSubtitle: String {
        let remaining = app.remaining(.aiGeneration)
        if app.profile.isPremium { return String(localized: "\(app.pantry.count) ingredientes en tu despensa") }
        return remaining == .max
            ? String(localized: "\(app.pantry.count) ingredientes en tu despensa")
            : String(localized: "Te quedan \(remaining) generaciones hoy")
    }

    /// Más discreta que la de generar a propósito: escribir una receta entera es
    /// una acción de minoría, y competir con el botón principal la haría ruido.
    private var composeCard: some View {
        Button {
            Haptics.select()
            isComposing = true
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.mist)

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "Escribir una receta tuya"))
                        .font(Typeface.action)
                        .foregroundStyle(Palette.ink)
                    Text(String(localized: "La revisamos y la publicas en la comunidad"))
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkFaint)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.inkFaint)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 13)
            .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface.opacity(0.7)) }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
        }
        .buttonStyle(.pressableCard)
        .screenPadding()
    }

    // MARK: - Vistas hace poco

    @ViewBuilder
    private var recentlyViewedSection: some View {
        // Lo ya guardado no se repite: estaría dos veces en la misma pantalla.
        let recent = app.recentlyViewed.filter { !app.savedRecipeIDs.contains($0.id) }

        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader(title: String(localized: "Vistas hace poco"), accent: Palette.mist) {
                    Text("\(recent.count)")
                        .font(Typeface.percentage)
                        .foregroundStyle(Palette.inkFaint)
                }
                .screenPadding()

                ScrollView(.horizontal) {
                    HStack(spacing: Space.sm) {
                        ForEach(recent.prefix(10)) { recipe in
                            NavigationLink(value: Route.recipeDetail(recipe.id)) {
                                RecipeCard(recipe: recipe, style: .rail)
                            }
                            .buttonStyle(.pressableCard)
                        }
                    }
                    .padding(.horizontal, Space.screen)
                }
                .scrollIndicators(.hidden)
                .tightHorizontalRail()
            }
            .padding(.top, Space.xs)
        }
    }

    // MARK: - Filtros

    private var filterRail: some View {
        FilterRail(
            items: RecipeTag.allCases,
            title: \.title,
            accent: { $0.accent.color },
            selection: $activeTags
        )
    }

    // MARK: - Feed

    @ViewBuilder
    private var feed: some View {
        let recipes = filteredRecipes

        if recipes.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: Space.md) {
                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    NavigationLink(value: Route.recipeDetail(recipe.id)) {
                        RecipeCard(recipe: recipe)
                    }
                    .buttonStyle(.pressableCard)
                    // Las tarjetas se atenúan y encogen apenas al salir del viewport.
                    // Es sutil a propósito: si se nota, está mal calibrado.
                    .scrollTransition(.interactive, axis: .vertical) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.55)
                            .scaleEffect(phase.isIdentity ? 1 : 0.97)
                    }

                    if app.ads.shouldInsertAd(afterIndex: index),
                       let ad = app.ads.currentNativeAd {
                        NativeAdCard(payload: ad) {
                            app.isPresentingPaywall = true
                        }
                    }
                }
            }
            .screenPadding()
        }
    }

    private var filteredRecipes: [Recipe] {
        let base: [Recipe] = switch scope {
        case .forYou:
            (app.lastGeneration + app.feed).filter { $0.source != .community }
        case .community:
            app.feed.filter { $0.source == .community }
        case .saved:
            // Sale de la biblioteca, no del feed: una receta generada y guardada
            // no está en el feed, y antes desaparecía al reabrir la app.
            app.savedRecipes
        }

        guard !activeTags.isEmpty else { return base }
        return base.filter { !Set($0.tags).isDisjoint(with: activeTags) }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch scope {
        case .saved:
            EmptyStateView(
                headline: String(localized: "Todavía no guardaste"),
                emphasis: String(localized: "nada"),
                message: String(localized: "Toca el marcador de cualquier receta y la vas a encontrar aquí."),
                systemImage: "bookmark",
                accent: Palette.clay,
                palette: .pantry
            )
        case .community:
            EmptyStateView(
                headline: String(localized: "La comunidad está"),
                emphasis: String(localized: "callada"),
                message: String(localized: "Cuando alguien publique una receta que use lo que tienes, aparece aquí."),
                systemImage: "person.2",
                accent: Palette.mist,
                palette: .intelligence
            )
        case .forYou:
            EmptyStateView(
                headline: String(localized: "Nada que sugerir"),
                emphasis: String(localized: "todavía"),
                message: String(localized: "Escanea tu nevera y armamos recetas con lo que haya adentro."),
                systemImage: "viewfinder",
                accent: Palette.sage,
                palette: .scanning,
                actionTitle: String(localized: "Escanear ahora"),
                action: { app.isPresentingScanner = true }
            )
        }
    }
}
