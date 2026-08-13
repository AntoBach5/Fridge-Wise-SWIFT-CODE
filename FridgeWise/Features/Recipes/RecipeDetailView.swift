//
//  RecipeDetailView.swift
//  FridgeWise
//
//  Detalle de receta.
//
//  El panel nutricional es la traducción directa del "mood distribution" de la
//  referencia: filas con punto de color, label, barra fina y porcentaje a la
//  derecha. Funciona igual de bien para macros porque el problema visual es el
//  mismo — tres o cuatro proporciones que suman 100 y hay que comparar de un
//  vistazo, sin la mentira de un gráfico de torta.
//
//  El hero hace parallax con `.visualEffect`, que corre en el render server:
//  cero trabajo en el hilo principal mientras se scrollea.
//

import SwiftUI

struct RecipeDetailView: View {

    /// Copia con la que se navegó hasta aquí. Solo se usa como red de seguridad
    /// si la receta ya no está en el estado.
    private let fallback: Recipe

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var showsCookMode = false
    @State private var isWritingReview = false
    @State private var isConfirmingPublish = false
    @State private var isConfirmingPublishFinal = false
    @State private var showsAgreement = false
    @State private var publishError: String?

    private let heroHeight: CGFloat = 320

    init(recipe: Recipe) {
        self.fallback = recipe
    }

    /// La receta se resuelve contra el estado en cada render: al publicarla
    /// deja de ser `.generated` y esta pantalla tiene que enterarse.
    private var recipe: Recipe {
        app.recipe(for: fallback.id) ?? fallback
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                hero
                metricsStrip
                nutritionPanel
                allergenNotice
                ingredientsSection
                stepsSection

                // Una receta generada es privada: se armó contra la despensa de
                // una persona concreta, así que no admite comentarios de nadie
                // más. En su lugar se ofrece publicarla, y ahí sí se abre.
                if recipe.source == .generated {
                    publishSection
                } else {
                    communitySection
                }
            }
            // `safeAreaInset` ya reserva el alto de la barra de acciones; esto
            // es solo aire para que el último bloque no quede pegado.
            .padding(.bottom, Space.lg)
        }
        .scrollIndicators(.hidden)
        .editorialScrollFeel()
        .canvasBackground()
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .keepInteractivePopGesture()
        .overlay(alignment: .top) { floatingNav }
        .safeAreaInset(edge: .bottom) { actionBar }
        .fullScreenCover(isPresented: $showsCookMode) {
            CookModeView(recipe: recipe)
        }
        .sheet(isPresented: $isWritingReview) {
            ReviewComposerSheet(recipe: recipe)
                .presentationDetents([.height(480)])
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Palette.canvas)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsAgreement) {
            CommunityAgreementSheet(
                onAccept: {
                    app.profile.agreement = CommunityAgreement(
                        acceptedVersion: CommunityAgreement.currentVersion,
                        acceptedAt: .now
                    )
                    showsAgreement = false
                    isConfirmingPublishFinal = true
                },
                onDecline: { showsAgreement = false }
            )
            .presentationDetents([.height(520)])
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Palette.canvas)
            .interactiveDismissDisabled()
        }
        // Doble confirmación: publicar es irreversible desde la app y lleva el
        // nombre del usuario. Un solo toque no alcanza para eso.
        .confirmationDialog(
            String(localized: "¿Publicar «\(recipe.title)»?"),
            isPresented: $isConfirmingPublish,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Continuar")) {
                if app.profile.agreement.needsAcceptance {
                    showsAgreement = true
                } else {
                    isConfirmingPublishFinal = true
                }
            }
            Button(String(localized: "Cancelar"), role: .cancel) {}
        } message: {
            Text(String(localized: "Cualquier persona podrá verla, guardarla y comentarla. Se publicará con tu nombre y pasará por moderación."))
        }
        .alert(
            String(localized: "Última confirmación"),
            isPresented: $isConfirmingPublishFinal
        ) {
            Button(String(localized: "Publicar")) { publish() }
            Button(String(localized: "Ahora no"), role: .cancel) {}
        } message: {
            Text(String(localized: "Una vez publicada aparecerá en el feed de la comunidad. Para retirarla tendrás que escribir a soporte."))
        }
        .alert(
            String(localized: "No se ha publicado"),
            isPresented: Binding(
                get: { publishError != nil },
                set: { if !$0 { publishError = nil } }
            )
        ) {
            Button(String(localized: "Entendido"), role: .cancel) {}
        } message: {
            Text(publishError ?? "")
        }
    }

    private func publish() {
        if case .rejected(let reason) = app.publishToCommunity(recipe) {
            publishError = reason
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RecipeHeroArt(recipe: recipe)
                .frame(height: heroHeight)
                .frame(maxWidth: .infinity)
                // Parallax: la imagen se estira al tirar hacia abajo y se mueve
                // a la mitad de velocidad al subir.
                .visualEffect { content, proxy in
                    let offset = proxy.frame(in: .scrollView).minY
                    return content
                        .offset(y: offset > 0 ? -offset * 0.55 : 0)
                        .scaleEffect(offset > 0 ? 1 + offset / 900 : 1, anchor: .bottom)
                }

            LinearGradient(
                colors: [.clear, Palette.canvas.opacity(0.55), Palette.canvas],
                startPoint: .center, endPoint: .bottom
            )
            .frame(height: heroHeight)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: Space.sm) {
                SourceBadge(source: recipe.source)

                Text(recipe.title)
                    .font(Typeface.display(31))
                    .tracking(-0.5)
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(recipe.subtitle)
                    .font(Typeface.quote)
                    .italic()
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .screenPadding()
            .padding(.bottom, Space.md)
        }
        .frame(height: heroHeight)
    }

    // MARK: - Navegación flotante

    private var floatingNav: some View {
        HStack {
            circleButton("chevron.left", label: String(localized: "Volver")) { dismiss() }
            Spacer()
            circleButton(
                app.isSaved(recipe) ? "bookmark.fill" : "bookmark",
                label: String(localized: "Guardar"),
                tint: app.isSaved(recipe) ? Palette.clay : Palette.ink
            ) {
                app.toggleSave(recipe)
            }
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 38, height: 38)
                    .background { Circle().fill(Palette.surface.opacity(0.9)) }
                    .background { Circle().fill(.ultraThinMaterial) }
                    .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
            }
            .simultaneousGesture(TapGesture().onEnded {
                app.ledger.award(.recipeShared, note: recipe.title)
            })
        }
        .padding(.horizontal, Space.md)
        .padding(.top, Space.xxxl)
    }

    private var shareText: String {
        String(localized: "\(recipe.title) — \(recipe.minutes) min, \(recipe.calories) kcal por porción. Vía Fridge Wise.")
    }

    private func circleButton(
        _ icon: String,
        label: String,
        tint: Color = Palette.ink,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background { Circle().fill(Palette.surface.opacity(0.9)) }
                .background { Circle().fill(.ultraThinMaterial) }
                .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Métricas

    private var metricsStrip: some View {
        SoftCard(padding: Space.md) {
            HStack(spacing: 0) {
                MetricStat(value: "\(recipe.minutes) min",
                           label: String(localized: "Tiempo"),
                           systemImage: "clock", accent: Palette.mist)

                verticalRule

                VStack(alignment: .leading, spacing: 5) {
                    DifficultyMeter(level: recipe.difficulty, showsLabel: false)
                        .frame(height: 17)
                    Text(String(localized: "Dificultad")).eyebrow()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                verticalRule

                MetricStat(value: "\(recipe.calories)",
                           label: String(localized: "Kcal/porción"),
                           systemImage: "flame", accent: Palette.tomato)

                verticalRule

                MetricStat(value: "\(recipe.servings)",
                           label: String(localized: "Porciones"),
                           systemImage: "person.2", accent: Palette.sage)
            }
        }
        .screenPadding()
    }

    private var verticalRule: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(width: Stroke.hairline, height: 30)
            .padding(.horizontal, Space.xs)
    }

    // MARK: - Nutrición

    private var nutritionPanel: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(String(localized: "Salud nutricional"))
                .screenPadding()

            SoftCard {
                VStack(alignment: .leading, spacing: Space.lg) {
                    HStack(alignment: .center, spacing: Space.lg) {
                        NutritionScoreRing(score: recipe.grade, diameter: 62)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.grade.caption)
                                .font(Typeface.cardTitle)
                                .foregroundStyle(Palette.ink)
                            Text(gradeExplanation)
                                .font(Typeface.callout)
                                .foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Hairline()

                    VStack(spacing: Space.sm) {
                        ForEach(recipe.macros.caloricDistribution, id: \.label) { macro in
                            DistributionRow(label: macro.label,
                                            value: macro.value,
                                            accent: macro.accent)
                        }
                        DistributionRow(
                            label: String(localized: "Fibra"),
                            value: min(recipe.macros.fiberGrams / 30, 1),
                            accent: Palette.basil,
                            trailingText: "\(Int(recipe.macros.fiberGrams)) g"
                        )
                    }

                    Text(String(localized: "Estimación por porción, calculada sobre los ingredientes listados. No reemplaza el consejo de un profesional de la nutrición."))
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .screenPadding()
        }
    }

    private var gradeExplanation: String {
        switch recipe.grade {
        case .a: String(localized: "Buen balance de proteína y fibra, con grasas moderadas.")
        case .b: String(localized: "Nutritiva y equilibrada para una comida principal.")
        case .c: String(localized: "Está bien de vez en cuando; alta en carbohidratos.")
        case .d: String(localized: "Rica pero pesada. Acompáñala con algo verde.")
        case .e: String(localized: "Un gusto. Nada de malo en eso, con moderación.")
        }
    }

    // MARK: - Alérgenos

    @ViewBuilder
    private var allergenNotice: some View {
        if !recipe.allergens.isEmpty {
            SoftCard(padding: Space.md, tint: Palette.tomato) {
                HStack(alignment: .top, spacing: Space.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.tomato)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Contiene")).eyebrow(Palette.tomato)
                        Text(recipe.allergens.joined(separator: " · "))
                            .font(Typeface.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(Palette.ink)
                    }
                    Spacer(minLength: 0)
                }
            }
            .screenPadding()
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Ingredientes

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: String(localized: "Ingredientes")) {
                Text("\(recipe.ingredients.count)")
                    .font(Typeface.percentage)
                    .foregroundStyle(Palette.inkSoft)
            }
            .screenPadding()

            VStack(spacing: 0) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    ingredientRow(ingredient)
                    if index < recipe.ingredients.count - 1 {
                        Hairline(inset: 30)
                    }
                }
            }
            .padding(.vertical, Space.xxs)
            .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
            .screenPadding()

            if !recipe.missingIngredients.isEmpty {
                missingCallout
            }
        }
    }

    private func ingredientRow(_ ingredient: RecipeIngredient) -> some View {
        HStack(spacing: Space.sm) {
            AccentDot(
                color: ingredient.isInPantry ? Palette.basil : Palette.hairline,
                size: 8,
                filled: ingredient.isInPantry
            )

            Text(ingredient.name)
                .font(Typeface.body)
                .foregroundStyle(ingredient.isInPantry ? Palette.ink : Palette.inkSoft)

            if ingredient.isOptional {
                Text(String(localized: "opcional"))
                    .font(Typeface.micro)
                    .italic()
                    .foregroundStyle(Palette.inkFaint)
            }

            Spacer(minLength: Space.xs)

            Text(ingredient.amount)
                .font(Typeface.caption)
                .monospacedDigit()
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ingredient.isInPantry
            ? String(localized: "\(ingredient.name), \(ingredient.amount), lo tienes")
            : String(localized: "\(ingredient.name), \(ingredient.amount), te falta"))
    }

    /// La integración que justifica el sistema dual de listas.
    private var missingCallout: some View {
        Button {
            app.addMissingIngredients(from: recipe)
        } label: {
            HStack(spacing: Space.sm) {
                ZStack {
                    Circle().fill(Palette.turmeric.opacity(0.16))
                    Image(systemName: "basket")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.turmeric)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "Te faltan \(recipe.missingIngredients.count)"))
                        .font(Typeface.headline)
                        .foregroundStyle(Palette.ink)
                    Text(recipe.missingIngredients.map(\.name).joined(separator: ", "))
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(String(localized: "A To Buy"))
                    .font(Typeface.micro)
                    .fontWeight(.bold)
                    .foregroundStyle(Palette.turmeric)
            }
            .padding(Space.sm)
            .background {
                RoundedRectangle.soft(Radius.md).fill(Palette.turmeric.opacity(0.09))
            }
            .overlay {
                RoundedRectangle.soft(Radius.md)
                    .strokeBorder(Palette.turmeric.opacity(0.25), lineWidth: Stroke.hairline)
            }
        }
        .buttonStyle(.pressableCard)
        .screenPadding()
    }

    // MARK: - Pasos

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: String(localized: "Preparación")) {
                Text(String(localized: "\(recipe.totalActiveMinutes) min activos"))
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.inkFaint)
            }
            .screenPadding()

            VStack(alignment: .leading, spacing: Space.lg) {
                ForEach(recipe.steps) { step in
                    stepRow(step)
                }
            }
            .screenPadding()
        }
    }

    private func stepRow(_ step: RecipeStep) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            // Número en serif: le da a la instrucción un tono de libro de cocina.
            Text("\(step.order)")
                .font(.system(size: 19, weight: .regular, design: .serif))
                .foregroundStyle(recipe.accent.color)
                .frame(width: 26, alignment: .leading)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(step.instruction)
                    .font(Typeface.body)
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(4.5)
                    .fixedSize(horizontal: false, vertical: true)

                if let minutes = step.minutes {
                    InfoChip(label: String(localized: "\(minutes) min"),
                             systemImage: "timer", weight: .quiet)
                }

                if let tip = step.tip {
                    HStack(alignment: .top, spacing: 7) {
                        Rectangle()
                            .fill(recipe.accent.color.opacity(0.4))
                            .frame(width: 2)
                        Text(tip)
                            .font(Typeface.quote)
                            .italic()
                            .foregroundStyle(Palette.inkSoft)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Paso \(step.order). \(step.instruction)"))
    }

    // MARK: - Publicar

    private var publishSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(String(localized: "Solo tuya"), accent: Palette.plum)
                .screenPadding()

            SoftCard(tint: Palette.plum) {
                VStack(alignment: .leading, spacing: Space.md) {
                    HStack(alignment: .top, spacing: Space.sm) {
                        ZStack {
                            Circle().fill(Palette.plum.opacity(0.14))
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Palette.plum)
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "Hecha con tu despensa"))
                                .font(Typeface.headline)
                                .foregroundStyle(Palette.ink)

                            Text(String(localized: "Está calculada sobre lo que tienes ahora mismo, así que no lleva comentarios: por ahora no la ve nadie más. Si crees que le sirve a cualquiera, publícala."))
                                .font(Typeface.callout)
                                .foregroundStyle(Palette.inkSoft)
                                .lineSpacing(2.5)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    Button {
                        Haptics.select()
                        isConfirmingPublish = true
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "paperplane")
                                .font(.system(size: 11, weight: .semibold))
                            Text(String(localized: "Publicar en la comunidad"))
                            Spacer(minLength: 0)
                            Text(String(localized: "+\(PointsEvent.recipePublished.amount) pts"))
                                .font(Typeface.micro)
                                .fontWeight(.bold)
                        }
                    }
                    .buttonStyle(AccentButtonStyle(accent: Palette.plum, fullWidth: true))
                }
            }
            .screenPadding()
        }
    }

    // MARK: - Comunidad

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: String(localized: "Qué dice la gente")) {
                NavigationLink(value: Route.communityThread(recipe.id)) {
                    Text(String(localized: "Ver todo"))
                        .font(Typeface.micro)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.plum)
                }
            }
            .screenPadding()

            SoftCard {
                VStack(alignment: .leading, spacing: Space.md) {
                    HStack(alignment: .center, spacing: Space.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.1f", recipe.rating))
                                .font(Typeface.display(30))
                                .foregroundStyle(Palette.ink)
                            StarRating(rating: recipe.rating, size: 11)
                        }

                        Rectangle()
                            .fill(Palette.hairline)
                            .frame(width: Stroke.hairline, height: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "\(recipe.ratingCount) valoraciones"))
                                .font(Typeface.caption)
                                .foregroundStyle(Palette.inkSoft)
                            Text(String(localized: "\(recipe.savedCount) la guardaron"))
                                .font(Typeface.caption)
                                .foregroundStyle(Palette.inkFaint)
                        }

                        Spacer(minLength: 0)
                    }

                    Hairline()

                    ForEach(app.reviews(for: recipe).prefix(2)) { review in
                        ReviewRow(review: review, recipe: recipe, compact: true)
                    }

                    Button {
                        Haptics.select()
                        isWritingReview = true
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 11, weight: .semibold))
                            Text(String(localized: "Escribir un comentario"))
                            Spacer(minLength: 0)
                            Text(String(localized: "+\(PointsEvent.reviewPosted.amount) pts"))
                                .font(Typeface.micro)
                                .fontWeight(.bold)
                        }
                    }
                    .buttonStyle(AccentButtonStyle(accent: Palette.plum, fullWidth: true))
                }
            }
            .screenPadding()
        }
    }

    // MARK: - Barra de acciones

    private var actionBar: some View {
        HStack(spacing: Space.xs) {
            Button {
                app.planToCook(recipe, on: Date())
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityLabel(String(localized: "Planificar para cocinar"))

            Button {
                Haptics.commit()
                showsCookMode = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(String(localized: "Empezar a cocinar"))
                }
            }
            .buttonStyle(InkButtonStyle(fullWidth: true))
        }
        .padding(.horizontal, Space.screen)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.md)
        .background {
            Rectangle()
                .fill(Palette.canvas)
                .mask {
                    LinearGradient(colors: [.clear, .black, .black],
                                   startPoint: .top, endPoint: .bottom)
                }
                .ignoresSafeArea()
        }
    }
}
