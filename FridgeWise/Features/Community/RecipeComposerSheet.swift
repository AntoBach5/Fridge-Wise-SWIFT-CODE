//
//  RecipeComposerSheet.swift
//  FridgeWise
//
//  Escribir una receta propia y publicarla en la comunidad.
//
//  El paso de revisión no está para poner trabas: está para que el autor vea los
//  problemas ANTES de exponer su nombre. Publicar algo con la mitad de los
//  ingredientes sin usar y enterarte por un comentario ajeno es peor que
//  cualquier validación.
//
//  Por eso los avisos no bloquean — se muestran y se decide. Solo se bloquea lo
//  que no se puede publicar: contenido inseguro, spam, o algo que directamente
//  no es una receta.
//

import SwiftUI

struct RecipeComposerSheet: View {

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var draft = RecipeDraft(
        ingredients: [.init(), .init()],
        steps: [.init(), .init()]
    )
    @State private var caloriesText = ""
    @State private var allergensText = ""

    @State private var stage: Stage = .writing
    @State private var verdict: RecipeVerdict?
    @State private var isConfirmingPublish = false
    @State private var showsAgreement = false
    @State private var blockedReason: String?

    @FocusState private var focus: Field?

    private let vetter: RecipeVetting = HeuristicRecipeVetter()

    private enum Stage: Equatable { case writing, checking, reviewed }
    private enum Field: Hashable {
        case title, subtitle, calories, allergens
        case ingredientName(UUID), ingredientAmount(UUID), step(UUID)
    }

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    header
                    if let verdict { verdictCard(verdict) }
                    basicsSection
                    metricsSection
                    ingredientsSection
                    stepsSection
                    tagsSection
                    extrasSection
                    disclaimer
                }
                .screenPadding()
                .padding(.top, Space.lg)
                .padding(.bottom, 140)
            }
            .scrollIndicators(.hidden)
            .dismissKeyboardOnDrag()
            .safeAreaInset(edge: .bottom) { footer }
        }
        .sheet(isPresented: $showsAgreement) {
            CommunityAgreementSheet(
                onAccept: {
                    app.profile.agreement = CommunityAgreement(
                        acceptedVersion: CommunityAgreement.currentVersion,
                        acceptedAt: .now
                    )
                    showsAgreement = false
                    isConfirmingPublish = true
                },
                onDecline: { showsAgreement = false }
            )
            .presentationDetents([.height(520)])
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Palette.canvas)
            .interactiveDismissDisabled()
        }
        .alert(
            String(localized: "¿Publicar «\(draft.title)»?"),
            isPresented: $isConfirmingPublish
        ) {
            Button(String(localized: "Publicar")) { publish() }
            Button(String(localized: "Ahora no"), role: .cancel) {}
        } message: {
            Text(String(localized: "Se publicará con tu nombre y cualquiera podrá verla, guardarla y comentarla."))
        }
        .alert(
            String(localized: "No se ha publicado"),
            isPresented: Binding(
                get: { blockedReason != nil },
                set: { if !$0 { blockedReason = nil } }
            )
        ) {
            Button(String(localized: "Entendido"), role: .cancel) {}
        } message: {
            Text(blockedReason ?? "")
        }
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Tu receta")).displayStyle(30)
                Text(String(localized: "para todos"))
                    .font(Typeface.displayItalic(30))
                    .foregroundStyle(Palette.ink)
                    .squiggleUnderline(Palette.mist)
                    .padding(.bottom, Space.xxs)
            }

            Spacer()

            Button {
                Haptics.select()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 34, height: 34)
                    .background { Circle().fill(Palette.surface) }
                    .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "Cerrar"))
        }
    }

    // MARK: - Veredicto

    @ViewBuilder
    private func verdictCard(_ verdict: RecipeVerdict) -> some View {
        switch verdict {
        case .looksGood:
            noticeCard(
                icon: "checkmark.seal.fill",
                accent: Palette.basil,
                title: String(localized: "Se ve bien"),
                lines: [String(localized: "Los pasos usan lo que listaste y no hemos visto nada raro. Puedes publicarla.")]
            )

        case .needsWork(let warnings):
            noticeCard(
                icon: "exclamationmark.triangle.fill",
                accent: Palette.turmeric,
                title: String(localized: "Puedes publicarla, pero…"),
                lines: warnings
            )

        case .rejected(let reason):
            noticeCard(
                icon: "hand.raised.fill",
                accent: Palette.tomato,
                title: String(localized: "Esto no se puede publicar"),
                lines: [reason]
            )
        }
    }

    private func noticeCard(icon: String, accent: Color, title: String, lines: [String]) -> some View {
        SoftCard(padding: Space.md, tint: accent) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(title)
                        .font(Typeface.headline)
                        .foregroundStyle(Palette.ink)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 7) {
                            AccentDot(color: accent, size: 5)
                                .padding(.top, 6)
                            Text(line)
                                .font(Typeface.callout)
                                .foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Básicos

    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "Lo esencial"))

            field(String(localized: "Nombre de la receta"),
                  text: $draft.title, focus: .title)

            field(String(localized: "Una frase que la presente"),
                  text: $draft.subtitle, focus: .subtitle)
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "Tiempo y raciones"))

            HStack(spacing: Space.xs) {
                stepper(label: String(localized: "Minutos"),
                        value: $draft.minutes, range: 1...600, step: 5)
                stepper(label: String(localized: "Raciones"),
                        value: $draft.servings, range: 1...12, step: 1)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(String(localized: "Dificultad")).eyebrow()
                HStack(spacing: Space.xs) {
                    ForEach(1...3, id: \.self) { level in
                        let isOn = draft.difficulty == level
                        Button {
                            Haptics.select()
                            withAnimation(Motion.morph) { draft.difficulty = level }
                        } label: {
                            Text(difficultyName(level))
                                .font(Typeface.micro)
                                .fontWeight(.semibold)
                                .foregroundStyle(isOn ? Palette.onInk : Palette.inkSoft)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background { Capsule().fill(isOn ? Palette.inkSolid : Palette.surface) }
                                .overlay {
                                    Capsule().strokeBorder(isOn ? .clear : Palette.hairline,
                                                           lineWidth: Stroke.hairline)
                                }
                        }
                        .buttonStyle(.pressableCard)
                        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
                    }
                }
            }
        }
    }

    private func difficultyName(_ level: Int) -> String {
        switch level {
        case 1:  String(localized: "Fácil")
        case 2:  String(localized: "Intermedio")
        default: String(localized: "Avanzado")
        }
    }

    // MARK: - Ingredientes

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: String(localized: "Ingredientes")) {
                Text("\(draft.cleanIngredients.count)")
                    .font(Typeface.percentage)
                    .foregroundStyle(Palette.inkSoft)
            }

            VStack(spacing: Space.xs) {
                ForEach($draft.ingredients) { $ingredient in
                    HStack(spacing: Space.xs) {
                        capsuleField(String(localized: "Ingrediente"),
                                     text: $ingredient.name,
                                     focus: .ingredientName(ingredient.id))

                        capsuleField(String(localized: "Cantidad"),
                                     text: $ingredient.amount,
                                     focus: .ingredientAmount(ingredient.id))
                            .frame(width: 108)

                        removeButton(disabled: draft.ingredients.count <= 2) {
                            withAnimation(Motion.standard) {
                                draft.ingredients.removeAll { $0.id == ingredient.id }
                            }
                        }
                    }
                }
            }

            addButton(String(localized: "Añadir ingrediente")) {
                withAnimation(Motion.standard) {
                    draft.ingredients.append(.init())
                }
            }
        }
    }

    // MARK: - Pasos

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: String(localized: "Preparación")) {
                Text("\(draft.cleanSteps.count)")
                    .font(Typeface.percentage)
                    .foregroundStyle(Palette.inkSoft)
            }

            VStack(spacing: Space.xs) {
                ForEach(Array(draft.steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: Space.sm) {
                        Text("\(index + 1)")
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .foregroundStyle(Palette.mist)
                            .frame(width: 20, alignment: .leading)
                            .padding(.top, 12)

                        TextField(String(localized: "Qué hay que hacer"),
                                  text: stepBinding(step.id),
                                  axis: .vertical)
                            .font(Typeface.body)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1...5)
                            .focused($focus, equals: .step(step.id))
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, 11)
                            .background { RoundedRectangle.soft(Radius.md).fill(Palette.surface) }
                            .overlay {
                                RoundedRectangle.soft(Radius.md)
                                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
                            }

                        removeButton(disabled: draft.steps.count <= 2) {
                            withAnimation(Motion.standard) {
                                draft.steps.removeAll { $0.id == step.id }
                            }
                        }
                        .padding(.top, 6)
                    }
                }
            }

            addButton(String(localized: "Añadir paso")) {
                withAnimation(Motion.standard) { draft.steps.append(.init()) }
            }
        }
    }

    // MARK: - Etiquetas y extras

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "Etiquetas"))

            FlowLayout(spacing: Space.xs) {
                ForEach(RecipeTag.allCases) { tag in
                    let isOn = draft.tags.contains(tag)
                    Button {
                        Haptics.select()
                        withAnimation(Motion.morph) {
                            if isOn { draft.tags.remove(tag) } else { draft.tags.insert(tag) }
                        }
                    } label: {
                        Text(tag.title)
                            .font(Typeface.micro)
                            .fontWeight(.semibold)
                            .foregroundStyle(isOn ? Palette.onInk : Palette.inkSoft)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8.5)
                            .background { Capsule().fill(isOn ? tag.accent.color : Palette.surface) }
                            .overlay {
                                Capsule().strokeBorder(isOn ? .clear : Palette.hairline,
                                                       lineWidth: Stroke.hairline)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
    }

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "Opcional"))

            field(String(localized: "Kcal por ración"), text: $caloriesText,
                  focus: .calories, keyboard: .numberPad)

            field(String(localized: "Alérgenos, separados por comas"),
                  text: $allergensText, focus: .allergens)

            Text(String(localized: "Si sabes que lleva gluten, lactosa o frutos secos, dilo. Alguien lo va a agradecer."))
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
                .padding(.horizontal, Space.xxs)
        }
    }

    /// Guideline 1.4.1: dejar claro que el dato nutricional no lo verifica nadie.
    private var disclaimer: some View {
        HStack(alignment: .top, spacing: Space.xs) {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.inkFaint)
                .padding(.top, 1)

            Text(String(localized: "Las recetas de la comunidad las escriben personas, no las verifica Fridge Wise. Publica solo recetas tuyas y no incluyas datos nutricionales o médicos que no puedas sostener."))
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.sm)
        .background { RoundedRectangle.soft(Radius.md).fill(Palette.canvasSunken) }
    }

    // MARK: - Pie

    private var footer: some View {
        VStack(spacing: Space.xs) {
            if stage == .reviewed, verdict?.canPublish == true {
                Button {
                    Haptics.select()
                    if app.profile.agreement.needsAcceptance {
                        showsAgreement = true
                    } else {
                        isConfirmingPublish = true
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(String(localized: "Publicar en la comunidad"))
                    }
                }
                .buttonStyle(InkButtonStyle(fullWidth: true))

                Button(String(localized: "Seguir editando")) {
                    withAnimation(Motion.standard) {
                        stage = .writing
                        verdict = nil
                    }
                }
                .font(Typeface.action)
                .foregroundStyle(Palette.inkSoft)
            } else {
                Button {
                    review()
                } label: {
                    if stage == .checking {
                        HStack(spacing: 8) {
                            ProgressView().tint(Palette.onInk)
                            Text(String(localized: "Revisando…"))
                        }
                    } else {
                        HStack(spacing: 7) {
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.system(size: 12, weight: .semibold))
                            Text(String(localized: "Revisar antes de publicar"))
                        }
                    }
                }
                .buttonStyle(InkButtonStyle(fullWidth: true))
                .disabled(stage == .checking || !hasMinimumContent)

                if !hasMinimumContent {
                    Text(String(localized: "Faltan el nombre, dos ingredientes y dos pasos."))
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkFaint)
                }
            }
        }
        .padding(.horizontal, Space.screen)
        .padding(.vertical, Space.md)
        .background {
            Rectangle().fill(Palette.canvas)
                .mask { LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .bottom) }
                .ignoresSafeArea()
        }
    }

    private var hasMinimumContent: Bool {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4
            && draft.cleanIngredients.count >= 2
            && draft.cleanSteps.count >= 2
    }

    /// Binding por id, no por índice: si se borra una fila mientras el teclado
    /// está abierto, el índice viejo apuntaría a otra fila o fuera del array.
    private func stepBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { draft.steps.first { $0.id == id }?.text ?? "" },
            set: { newValue in
                guard let index = draft.steps.firstIndex(where: { $0.id == id }) else { return }
                draft.steps[index].text = newValue
            }
        )
    }

    // MARK: - Campos reutilizables

    private func field(
        _ placeholder: String,
        text: Binding<String>,
        focus field: Field,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(placeholder, text: text)
            .font(Typeface.body)
            .foregroundStyle(Palette.ink)
            .keyboardType(keyboard)
            .focused($focus, equals: field)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 12)
            .background { RoundedRectangle.soft(Radius.md).fill(Palette.surface) }
            .overlay {
                RoundedRectangle.soft(Radius.md)
                    .strokeBorder(focus == field ? Palette.mist.opacity(0.45) : Palette.hairline,
                                  lineWidth: Stroke.hairline)
            }
            .motion(Motion.standard, value: focus == field)
    }

    private func capsuleField(
        _ placeholder: String,
        text: Binding<String>,
        focus field: Field
    ) -> some View {
        TextField(placeholder, text: text)
            .font(Typeface.callout)
            .foregroundStyle(Palette.ink)
            .focused($focus, equals: field)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 11)
            .background { Capsule().fill(Palette.surface) }
            .overlay {
                Capsule().strokeBorder(focus == field ? Palette.mist.opacity(0.45) : Palette.hairline,
                                       lineWidth: Stroke.hairline)
            }
    }

    private func stepper(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).eyebrow()

            HStack(spacing: 0) {
                stepperButton("minus") {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                }

                Text("\(value.wrappedValue)")
                    .font(Typeface.action)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity)

                stepperButton("plus") {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                }
            }
            .padding(.vertical, 4)
            .background { Capsule().fill(Palette.surface) }
            .overlay { Capsule().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepperButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tick()
            withAnimation(Motion.tap) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
                .frame(width: 38, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func removeButton(disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tick()
            action()
        } label: {
            Image(systemName: "minus.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(disabled ? Palette.hairline : Palette.inkFaint)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(String(localized: "Quitar"))
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(Typeface.micro)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Palette.mist)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Acciones

    private func review() {
        focus = nil
        draft.allergens = allergensText
        withAnimation(Motion.standard) {
            stage = .checking
            verdict = nil
        }

        Task {
            let result = await vetter.vet(draft)

            // El filtro de la comunidad corre igual: uno mira que sea una receta,
            // el otro mira que no sea un insulto. Son dos problemas distintos.
            let screening = app.moderation.screen("\(draft.title). \(draft.subtitle). \(draft.cleanSteps.joined(separator: " "))")

            withAnimation(Motion.entrance) {
                verdict = screening.canPublish
                    ? result
                    : .rejected(screening.advisory ?? String(localized: "Este texto incluye lenguaje que no permitimos."))
                stage = .reviewed
            }

            if verdict?.canPublish == true {
                Haptics.commit()
            } else {
                Haptics.reject()
            }
        }
    }

    private func publish() {
        let recipe = buildRecipe()
        if case .rejected(let reason) = app.publishToCommunity(recipe) {
            blockedReason = reason
            return
        }
        dismiss()
    }

    private func buildRecipe() -> Recipe {
        let pantryNames = Set(app.pantry.map { $0.name.lowercased() })

        let ingredients = draft.cleanIngredients.map { item in
            RecipeIngredient(
                name: item.name.trimmingCharacters(in: .whitespaces),
                amount: item.amount.trimmingCharacters(in: .whitespaces),
                category: .condiments,
                isInPantry: pantryNames.contains(item.name.lowercased().trimmingCharacters(in: .whitespaces))
            )
        }

        let steps = draft.cleanSteps.enumerated().map { index, instruction in
            RecipeStep(order: index + 1, instruction: instruction, minutes: nil, tip: nil)
        }

        let allergens = allergensText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return Recipe(
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: draft.subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            source: .community,
            minutes: draft.minutes,
            difficulty: draft.difficulty,
            calories: Int(caloriesText) ?? 0,
            servings: draft.servings,
            grade: .c,
            // Sin desglose: no lo escribió nadie y no vamos a inventarlo.
            // `Recipe.hasNutritionData` hace que el detalle lo diga en vez de
            // pintar un gráfico de ceros.
            macros: Macros(proteinGrams: 0, carbGrams: 0, fatGrams: 0, fiberGrams: 0),
            ingredients: ingredients,
            steps: steps,
            tags: Array(draft.tags),
            allergens: allergens,
            accent: draft.tags.first?.accent ?? .mist,
            imageName: nil,
            rating: 0,
            ratingCount: 0,
            savedCount: 0,
            authorName: app.profile.displayName,
            authorInitials: app.profile.initials
        )
    }
}
