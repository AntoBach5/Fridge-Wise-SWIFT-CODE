//
//  RecipeFeedView.swift
//  FridgeWise
//
//  Feed de recetas con tres pestañas: lo generado para vos, lo de la comunidad
//  y lo guardado. La publicidad se intercala cada 6 tarjetas y sólo si el plan
//  lo amerita — la decisión la toma `AdCoordinator`, no esta vista.
//

import SwiftUI

struct RecipeFeedView: View {

    @Environment(\.app) private var app
    @Binding var isTabBarDimmed: Bool

    @State private var scope: Scope = .forYou
    @State private var activeTags: Set<RecipeTag> = []
    @State private var isGenerating = false

    enum Scope: String, CaseIterable, Hashable {
        case forYou, community, saved

        var title: String {
            switch self {
            case .forYou:    String(localized: "Para vos")
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

                if scope != .saved {
                    filterRail
                }

                feed
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
        .task { await app.ads.loadNativeAd() }
        .onChange(of: scope) { _, _ in
            Task { await app.ads.loadNativeAd() }
        }
    }

    // MARK: - Encabezado

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "Qué podés")).displayStyle(31)
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
                    Text(String(localized: "Generar con lo que tenés"))
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
            app.feed.filter { app.savedRecipeIDs.contains($0.id) }
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
                message: String(localized: "Tocá el marcador de cualquier receta y la vas a encontrar acá."),
                systemImage: "bookmark",
                accent: Palette.clay,
                palette: .pantry
            )
        case .community:
            EmptyStateView(
                headline: String(localized: "La comunidad está"),
                emphasis: String(localized: "callada"),
                message: String(localized: "Cuando alguien publique una receta que use lo que tenés, aparece acá."),
                systemImage: "person.2",
                accent: Palette.mist,
                palette: .intelligence
            )
        case .forYou:
            EmptyStateView(
                headline: String(localized: "Nada que sugerir"),
                emphasis: String(localized: "todavía"),
                message: String(localized: "Escaneá tu heladera y armamos recetas con lo que haya adentro."),
                systemImage: "viewfinder",
                accent: Palette.sage,
                palette: .scanning,
                actionTitle: String(localized: "Escanear ahora"),
                action: { app.isPresentingScanner = true }
            )
        }
    }
}
