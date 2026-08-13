//
//  CookModeView.swift
//  FridgeWise
//
//  Modo cocina: pasos a pantalla completa mientras cocinas.
//
//  Restricciones de diseño, todas nacidas de la situación real (manos sucias,
//  teléfono apoyado a un metro, ruido de fondo):
//  · Tipografía grande. El paso se lee de pie desde lejos.
//  · Áreas táctiles enormes — se toca con el nudillo o el dorso del dedo.
//  · La pantalla no se apaga (`isIdleTimerDisabled`), y se restaura al salir.
//  · Cero anuncios: se registra como contexto protegido en `AdCoordinator`.
//  · El temporizador es opcional y no bloquea el avance: nadie quiere pelear
//    con una cuenta regresiva porque su hornalla calienta distinto.
//

import SwiftUI

struct CookModeView: View {

    let recipe: Recipe

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var secondsRemaining: Int?
    @State private var timerTask: Task<Void, Never>?
    @State private var showsFinish = false

    private var step: RecipeStep { recipe.steps[min(index, recipe.steps.count - 1)] }
    private var isLastStep: Bool { index >= recipe.steps.count - 1 }

    var body: some View {
        ZStack {
            CanvasBackground()
            FluidBackdrop(palette: .pantry, intensity: 0.18)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                progressRail
                Spacer(minLength: Space.md)
                stepContent
                Spacer(minLength: Space.md)
                controls
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            app.ads.enterProtectedContext(.cookingMode)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            app.ads.exitProtectedContext(.cookingMode)
            timerTask?.cancel()
        }
        .sheet(isPresented: $showsFinish) {
            finishSheet
                .presentationDetents([.height(420)])
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Palette.canvas)
        }
    }

    // MARK: - Barra superior

    private var topBar: some View {
        HStack {
            Button {
                Haptics.select()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background { Circle().fill(Palette.surface) }
                    .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
            }
            .accessibilityLabel(String(localized: "Salir del modo cocina"))

            Spacer()

            VStack(spacing: 1) {
                Text(String(localized: "Paso \(index + 1) de \(recipe.steps.count)"))
                    .font(Typeface.micro)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.inkSoft)
                Text(recipe.title)
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.inkFaint)
                    .lineLimit(1)
            }

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, Space.md)
        .padding(.top, Space.xs)
    }

    private var progressRail: some View {
        HStack(spacing: 3) {
            ForEach(recipe.steps.indices, id: \.self) { position in
                Capsule()
                    .fill(position <= index ? recipe.accent.color : Palette.hairline)
                    .frame(height: 3)
            }
        }
        .screenPadding()
        .padding(.top, Space.md)
        .motion(Motion.standard, value: index)
    }

    // MARK: - Paso

    private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("\(step.order)")
                    .font(.system(size: 64, weight: .regular, design: .serif))
                    .foregroundStyle(recipe.accent.color.opacity(0.35))

                Text(step.instruction)
                    .font(.system(size: 25, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)

                if let tip = step.tip {
                    HStack(alignment: .top, spacing: Space.sm) {
                        Rectangle()
                            .fill(recipe.accent.color.opacity(0.45))
                            .frame(width: 2.5)
                        Text(tip)
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(Palette.inkSoft)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let minutes = step.minutes {
                    timerCard(minutes: minutes)
                }
            }
            .screenPadding()
        }
        .scrollIndicators(.hidden)
        .id(index)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < -60, !isLastStep { advance() }
                    if value.translation.width > 60, index > 0 { retreat() }
                }
        )
    }

    private func timerCard(minutes: Int) -> some View {
        SoftCard(padding: Space.md, tint: recipe.accent.color) {
            HStack(spacing: Space.md) {
                Image(systemName: "timer")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(recipe.accent.color)

                VStack(alignment: .leading, spacing: 1) {
                    if let secondsRemaining {
                        Text(format(secondsRemaining))
                            .font(.system(size: 26, weight: .medium, design: .serif))
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.numericText(countsDown: true))
                    } else {
                        Text(String(localized: "\(minutes) minutos"))
                            .font(Typeface.cardTitle)
                            .foregroundStyle(Palette.ink)
                    }
                    Text(secondsRemaining == nil
                         ? String(localized: "Toca para arrancar")
                         : String(localized: "Corriendo"))
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkFaint)
                }

                Spacer(minLength: 0)

                Button {
                    toggleTimer(minutes: minutes)
                } label: {
                    Image(systemName: secondsRemaining == nil ? "play.fill" : "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.onInk)
                        .frame(width: 46, height: 46)
                        .background { Circle().fill(recipe.accent.color) }
                }
                .accessibilityLabel(secondsRemaining == nil
                    ? String(localized: "Iniciar temporizador")
                    : String(localized: "Detener temporizador"))
            }
        }
    }

    private func format(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func toggleTimer(minutes: Int) {
        Haptics.commit()
        if secondsRemaining == nil {
            secondsRemaining = minutes * 60
            timerTask = Task {
                while let current = secondsRemaining, current > 0, !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    secondsRemaining = (secondsRemaining ?? 1) - 1
                }
                if secondsRemaining == 0 {
                    Haptics.celebrate()
                    secondsRemaining = nil
                }
            }
        } else {
            timerTask?.cancel()
            secondsRemaining = nil
        }
    }

    // MARK: - Controles

    private var controls: some View {
        HStack(spacing: Space.sm) {
            if index > 0 {
                Button {
                    retreat()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel(String(localized: "Paso anterior"))
            }

            Button {
                if isLastStep {
                    Haptics.celebrate()
                    showsFinish = true
                } else {
                    advance()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(isLastStep
                         ? String(localized: "Terminé")
                         : String(localized: "Siguiente paso"))
                    Image(systemName: isLastStep ? "checkmark" : "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .buttonStyle(InkButtonStyle(
                fill: isLastStep ? Palette.basil : Palette.inkSolid,
                verticalPadding: 18,
                fullWidth: true
            ))
        }
        .screenPadding()
        .padding(.bottom, Space.lg)
    }

    private func advance() {
        Haptics.tick()
        timerTask?.cancel()
        secondsRemaining = nil
        withAnimation(Motion.standard) { index += 1 }
    }

    private func retreat() {
        Haptics.tick()
        timerTask?.cancel()
        secondsRemaining = nil
        withAnimation(Motion.standard) { index -= 1 }
    }

    // MARK: - Final

    private var finishSheet: some View {
        VStack(spacing: Space.lg) {
            ZStack {
                Circle().fill(Palette.basil.opacity(0.14))
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Palette.basil)
                    .symbolEffect(.bounce)
            }
            .frame(width: 88, height: 88)

            VStack(spacing: 4) {
                Text(String(localized: "Lo lograste")).displayStyle(27)
                Text(String(localized: "+\(PointsEvent.recipeCooked.amount) puntos"))
                    .font(Typeface.displayItalic(21))
                    .foregroundStyle(Palette.turmeric)
                    .squiggleUnderline(Palette.turmeric, delay: 0.2)
            }

            Text(String(localized: "Sumamos esta receta a tu historial y descontamos lo que usaste de la despensa."))
                .bodyStyle()
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)

            VStack(spacing: Space.xs) {
                Button(String(localized: "Listo")) {
                    app.markCooked(recipe)
                    showsFinish = false
                    dismiss()
                }
                .buttonStyle(InkButtonStyle(fill: Palette.basil, fullWidth: true))

                Button(String(localized: "Contar cómo salió")) {
                    app.markCooked(recipe)
                    showsFinish = false
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle(fullWidth: true))
            }
        }
        .padding(.top, Space.xl)
        .padding(.bottom, Space.lg)
        .screenPadding()
        .canvasBackground()
    }
}
