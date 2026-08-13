//
//  GenerationSheet.swift
//  FridgeWise
//
//  Generación de recetas con IA.
//
//  Dos cosas que la mayoría de las apps con IA hacen mal y aquí no:
//  1. La espera cuenta algo. Las fases ("mirando qué tienes" → "probando
//     combinaciones" → "equilibrando la nutrición") describen trabajo real y
//     dejan al usuario entender qué se está optimizando.
//  2. El resultado se declara como generado, con su disclaimer de alérgenos y
//     de estimación nutricional. No es letra chica legal: es una app de comida
//     y alguien con alergia puede leer esto como si fuera un hecho verificado.
//

import SwiftUI

struct GenerationSheet: View {

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .setup
    @State private var preferences = GenerationPreferences()
    @State private var phase: GenerationPhase = .reading
    @State private var results: [Recipe] = []
    @State private var failure: String?
    @State private var task: Task<Void, Never>?

    @State private var thinkingController = RiveController(.thinking)
    @FocusState private var isTypingRequest: Bool

    enum Stage: Equatable { case setup, working, done }

    var body: some View {
        ZStack {
            CanvasBackground()

            switch stage {
            case .setup:   setupStage
            case .working: workingStage
            case .done:    resultsStage
            }
        }
        .onDisappear { task?.cancel() }
    }

    // MARK: - Configuración

    private var setupStage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Armemos algo")).displayStyle(30)
                    Text(String(localized: "con lo que hay"))
                        .font(Typeface.displayItalic(30))
                        .foregroundStyle(Palette.ink)
                        .squiggleUnderline(Palette.plum)
                        .padding(.bottom, Space.xxs)
                }
                .padding(.top, Space.lg)

                pantrySummary
                servingsControl
                timeControl
                tagControl

                Spacer(minLength: Space.lg)
            }
            .screenPadding()
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .dismissKeyboardOnDrag()
        .safeAreaInset(edge: .bottom) { setupFooter }
    }

    private var pantrySummary: some View {
        SoftCard(tint: Palette.sage) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    Text(String(localized: "Tu despensa")).eyebrow(Palette.sage)
                    Spacer()
                    Text("\(app.pantry.count)")
                        .font(Typeface.percentage)
                        .foregroundStyle(Palette.sage)
                }

                Text(app.pantry.prefix(8).map(\.name).joined(separator: " · "))
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !app.expiringSoon.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 10, weight: .semibold))
                        Text(String(localized: "Vamos a priorizar lo que vence pronto"))
                            .font(Typeface.micro)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Palette.turmeric)
                }
            }
        }
    }

    private var servingsControl: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "Porciones"))

            HStack(spacing: Space.xs) {
                ForEach([1, 2, 4, 6], id: \.self) { count in
                    let isOn = preferences.servings == count
                    Button {
                        Haptics.select()
                        withAnimation(Motion.morph) { preferences.servings = count }
                    } label: {
                        Text("\(count)")
                            .font(Typeface.action)
                            .monospacedDigit()
                            .foregroundStyle(isOn ? Palette.onInk : Palette.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle.soft(Radius.md)
                                    .fill(isOn ? Palette.inkSolid : Palette.surface)
                            }
                            .overlay {
                                RoundedRectangle.soft(Radius.md)
                                    .strokeBorder(isOn ? .clear : Palette.hairline,
                                                  lineWidth: Stroke.hairline)
                            }
                    }
                    .buttonStyle(.pressableCard)
                    .accessibilityLabel(String(localized: "\(count) porciones"))
                    .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
    }

    private var timeControl: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: String(localized: "Tiempo máximo")) {
                Text(preferences.maxMinutes.map { "\($0) min" } ?? String(localized: "Sin límite"))
                    .font(Typeface.percentage)
                    .foregroundStyle(Palette.ink)
            }

            HStack(spacing: Space.xs) {
                ForEach([15, 30, 45], id: \.self) { minutes in
                    timeChip(String(localized: "\(minutes) min"), value: minutes)
                }
                timeChip(String(localized: "Sin límite"), value: nil)
            }
        }
    }

    private func timeChip(_ title: String, value: Int?) -> some View {
        let isOn = preferences.maxMinutes == value
        return Button {
            Haptics.select()
            withAnimation(Motion.morph) { preferences.maxMinutes = value }
        } label: {
            Text(title)
                .font(Typeface.micro)
                .fontWeight(.semibold)
                .foregroundStyle(isOn ? Palette.onInk : Palette.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    Capsule().fill(isOn ? Palette.inkSolid : Palette.surface)
                }
                .overlay {
                    Capsule().strokeBorder(isOn ? .clear : Palette.hairline,
                                           lineWidth: Stroke.hairline)
                }
        }
        .buttonStyle(.pressableCard)
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }

    private var tagControl: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "Qué buscas"))

            FlowLayout(spacing: Space.xs) {
                ForEach(RecipeTag.allCases) { tag in
                    let isOn = preferences.tags.contains(tag)
                    Button {
                        Haptics.select()
                        withAnimation(Motion.morph) {
                            if isOn { preferences.tags.remove(tag) } else { preferences.tags.insert(tag) }
                        }
                    } label: {
                        Text(tag.title)
                            .font(Typeface.micro)
                            .fontWeight(.semibold)
                            .foregroundStyle(isOn ? Palette.onInk : Palette.inkSoft)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8.5)
                            .background {
                                Capsule().fill(isOn ? tag.accent.color : Palette.surface)
                            }
                            .overlay {
                                Capsule().strokeBorder(isOn ? .clear : Palette.hairline,
                                                       lineWidth: Stroke.hairline)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
                }
            }

            customRequestField
        }
    }

    /// Escape hatch para cuando ninguna etiqueta describe lo que la persona
    /// quiere. Ocho chips no cubren "sin horno" ni "algo para llevar", y sin
    /// esto la única salida es conformarse.
    private var customRequestField: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: Space.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isTypingRequest ? Palette.plum : Palette.inkFaint)

                TextField(
                    String(localized: "O dilo tú: «algo picante», «sin horno»…"),
                    text: $preferences.customRequest
                )
                .font(Typeface.body)
                .foregroundStyle(Palette.ink)
                .focused($isTypingRequest)
                .submitLabel(.done)

                if !preferences.customRequest.isEmpty {
                    Button {
                        Haptics.tick()
                        withAnimation(Motion.tap) { preferences.customRequest = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel(String(localized: "Borrar lo escrito"))
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 12)
            .background { Capsule().fill(Palette.surface) }
            .overlay {
                Capsule().strokeBorder(
                    isTypingRequest ? Palette.plum.opacity(0.4) : Palette.hairline,
                    lineWidth: Stroke.hairline
                )
            }
            .motion(Motion.standard, value: isTypingRequest)
            .motion(Motion.tap, value: preferences.customRequest.isEmpty)

            if !preferences.customRequest.isEmpty {
                Text(String(localized: "Lo tenemos en cuenta para ordenar las propuestas, no para descartarlas."))
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.inkFaint)
                    .padding(.horizontal, Space.xxs)
                    .transition(.opacity)
            }
        }
        .padding(.top, Space.xxs)
    }

    private var setupFooter: some View {
        VStack(spacing: Space.xs) {
            Button(String(localized: "Generar recetas")) {
                startGeneration()
            }
            .buttonStyle(InkButtonStyle(fullWidth: true))
            .disabled(app.pantry.count < 3)

            if app.pantry.count < 3 {
                Text(String(localized: "Necesitamos al menos 3 ingredientes. Escanea tu nevera primero."))
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.tomato)
                    .multilineTextAlignment(.center)
            } else if !app.profile.isPremium {
                Text(String(localized: "Te quedan \(app.remaining(.aiGeneration)) generaciones hoy"))
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.inkFaint)
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

    // MARK: - Trabajando

    private var workingStage: some View {
        VStack(spacing: Space.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Palette.surface)
                    .overlay {
                        FluidBackdrop(palette: .intelligence, intensity: 0.55)
                            .clipShape(Circle())
                    }
                    .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }

                RiveStage(controller: thinkingController) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .ultraLight))
                        .foregroundStyle(Palette.ink)
                        .symbolEffect(.variableColor.iterative)
                }
                .frame(width: 90, height: 90)
            }
            .frame(width: 148, height: 148)

            VStack(spacing: Space.xs) {
                Text(phase.caption)
                    .font(Typeface.display(24))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: phase.caption)

                Text(String(localized: "Tarda unos segundos"))
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.inkFaint)
            }

            ProgressTrack(value: phase.progress, accent: Palette.plum)
                .frame(width: 180)

            Spacer()

            Button(String(localized: "Cancelar")) {
                task?.cancel()
                stage = .setup
            }
            .font(Typeface.action)
            .foregroundStyle(Palette.inkSoft)
            .padding(.bottom, Space.xl)
        }
        .screenPadding()
        .onAppear { thinkingController.setNumber("progress", phase.progress * 100) }
        .onChange(of: phase.progress) { _, value in
            thinkingController.setNumber("progress", value * 100)
        }
    }

    // MARK: - Resultados

    private var resultsStage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Te armamos")).displayStyle(30)
                    HStack(spacing: 8) {
                        Text("\(results.count)")
                            .font(Typeface.display(30))
                            .foregroundStyle(Palette.ink)
                        Text(String(localized: "opciones"))
                            .font(Typeface.displayItalic(30))
                            .foregroundStyle(Palette.ink)
                            .squiggleUnderline(Palette.plum, delay: 0.2)
                    }
                    .padding(.bottom, Space.xxs)
                }
                .padding(.top, Space.lg)

                aiDisclaimer

                LazyVStack(spacing: Space.md) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, recipe in
                        NavigationLink(value: Route.recipeDetail(recipe.id)) {
                            RecipeCard(recipe: recipe)
                        }
                        .buttonStyle(.pressableCard)
                        .modifier(StaggeredEntrance(index: index))
                    }
                }

                Button(String(localized: "Generar otras")) {
                    startGeneration()
                }
                .buttonStyle(QuietButtonStyle(fullWidth: true))
                .padding(.top, Space.xs)
            }
            .screenPadding()
            .padding(.bottom, Space.xxl)
        }
        .scrollIndicators(.hidden)
    }

    /// Guideline 1.4.1 + sentido común: lo que estima un modelo se presenta
    /// como estimación, y los alérgenos nunca se dan por verificados.
    private var aiDisclaimer: some View {
        HStack(alignment: .top, spacing: Space.xs) {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.inkFaint)
                .padding(.top, 1)

            Text(String(localized: "Recetas generadas automáticamente. Los valores nutricionales son estimaciones y la lista de alérgenos puede estar incompleta: revisa los ingredientes antes de cocinar si tienes alguna alergia."))
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.sm)
        .background {
            RoundedRectangle.soft(Radius.md).fill(Palette.canvasSunken)
        }
    }

    // MARK: - Acciones

    private func startGeneration() {
        guard app.consume(.aiGeneration) else {
            dismiss()
            return
        }

        Haptics.commit()
        stage = .working
        phase = .reading
        results = []
        failure = nil

        task?.cancel()
        task = Task {
            do {
                for try await next in app.generator.generate(from: app.pantry, preferences: preferences) {
                    guard !Task.isCancelled else { return }
                    withAnimation(Motion.standard) { phase = next }

                    if case .ready(let recipes) = next {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { return }
                        results = recipes
                        app.lastGeneration = recipes
                        Haptics.celebrate()
                        withAnimation(Motion.entrance) { stage = .done }
                    }
                }
            } catch {
                failure = error.localizedDescription
                stage = .setup
                Haptics.reject()
            }
        }
    }
}

// MARK: - Entrada escalonada

/// Cada tarjeta entra con un retraso creciente. Es lo que convierte un
/// "aparecieron 5 resultados" en "se fueron armando".
private struct StaggeredEntrance: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 18)
            .task {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    try? await Task.sleep(for: .milliseconds(index * 70))
                    withAnimation(Motion.entrance) { shown = true }
                }
            }
    }
}
