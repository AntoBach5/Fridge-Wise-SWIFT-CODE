//
//  ScanFlowView.swift
//  FridgeWise
//
//  El momento que define el producto.
//
//  Cuatro estados, cada uno con su propia personalidad:
//    permiso  → explicación honesta, con salida alternativa si dicen que no
//    encuadre → cámara limpia, esquinas de visor, un solo botón
//    análisis → la foto congelada + haz que barre + pins que aparecen uno a uno
//    revisión → hoja donde el usuario confirma o corrige antes de guardar
//
//  El análisis es deliberadamente teatral: no porque tarde, sino porque el
//  usuario necesita VER que la app miró su nevera. Un spinner de 3 segundos
//  y un listado de golpe se siente como magia barata; los pins apareciendo
//  sobre su propia foto se siente como que algo entendió lo que hay adentro.
//
//  El visor escanea dos cosas: la nevera/alacena o el ticket de la compra. Se
//  elige en el propio visor, como en la cámara nativa se elige entre foto y
//  vídeo, y no en dos entradas distintas de la app: es la misma intención
//  ("cargar lo que tengo") resuelta por dos motores distintos, y esa diferencia
//  es un problema nuestro, no del usuario.
//

import SwiftUI

struct ScanFlowView: View {

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var camera = CameraController()
    @State private var stage: Stage = .framing
    @State private var subject: ScanSubject = .pantry
    @State private var capturedImage: UIImage?
    @State private var detected: [Ingredient] = []
    @State private var caption: String = ""
    @State private var progress: Double = 0
    @State private var scanTask: Task<Void, Never>?
    @State private var failure: ScanError?

    @Namespace private var subjectNamespace

    enum Stage: Equatable {
        case permission, framing, analyzing, review
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch stage {
            case .permission:
                permissionGate
            case .framing:
                framingStage
            case .analyzing, .review:
                analysisStage
            }

            chrome
        }
        .statusBarHidden()
        .task {
            app.ads.enterProtectedContext(.scanning)
            camera.refreshAccess()
            if camera.access == .unknown {
                await camera.requestAccess()
            }
            stage = camera.access == .authorized ? .framing : .permission
            if stage == .framing { await camera.start() }
        }
        .onDisappear {
            scanTask?.cancel()
            camera.stop()
            app.ads.exitProtectedContext(.scanning)
        }
        .sheet(isPresented: Binding(
            get: { stage == .review },
            set: { if !$0 { stage = .analyzing } }
        )) {
            ScanReviewSheet(
                detected: $detected,
                subject: subject,
                onConfirm: { confirmed in
                    app.commitScan(ScanResult(detected: confirmed, overallConfidence: 1))
                    dismiss()
                },
                onRetake: {
                    detected = []
                    capturedImage = nil
                    progress = 0
                    stage = .framing
                    Task { await camera.start() }
                }
            )
            .presentationDetents([.height(560), .large])
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Palette.canvas)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .alert(
            failure?.errorDescription ?? "",
            isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            ),
            presenting: failure
        ) { _ in
            // Volver al visor tiene que volver a encender la cámara: la
            // captura la había parado, y sin esto el usuario se queda mirando
            // su última foto congelada creyendo que la app se colgó.
            Button(String(localized: "Volver a intentar")) {
                detected = []
                capturedImage = nil
                progress = 0
                stage = .framing
                Task { await camera.start() }
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "")
        }
    }

    // MARK: - Chrome

    /// Barra superior constante en todos los estados: cerrar siempre disponible.
    private var chrome: some View {
        VStack {
            HStack {
                Button {
                    Haptics.select()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(Typeface.scaled(14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .liquidGlass(in: Circle(), role: .overlay, interactive: true, shadow: false)
                        .hitTarget(size: 36)
                }
                .accessibilityLabel(String(localized: "Cerrar"))

                Spacer()

                if stage == .framing, !app.profile.isPremium {
                    remainingBadge
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.xs)

            Spacer()
        }
    }

    private var remainingBadge: some View {
        let left = app.remaining(.scan)
        return HStack(spacing: 5) {
            Image(systemName: "viewfinder")
                .font(Typeface.scaled(10, weight: .semibold))
            Text(left == .max
                 ? String(localized: "Sin límite")
                 : String(localized: "\(left) esta semana"))
                .font(Typeface.micro)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassCapsule(role: .overlay, shadow: false)
    }

    // MARK: - Permiso

    private var permissionGate: some View {
        VStack(spacing: Space.lg) {
            Spacer()

            ZStack {
                Circle().fill(.white.opacity(0.08))
                Image(systemName: camera.access == .denied ? "camera.badge.ellipsis" : "camera")
                    .font(Typeface.scaled(30, weight: .light, relativeTo: .title1))
                    .foregroundStyle(.white)
            }
            .frame(width: 96, height: 96)

            VStack(spacing: 6) {
                Text(String(localized: "Necesitamos la cámara"))
                    .font(Typeface.display(26))
                    .foregroundStyle(.white)
                Text(String(localized: "solo para esto"))
                    .font(Typeface.displayItalic(26))
                    .foregroundStyle(.white)
            }

            Text(String(localized: "La foto se analiza para reconocer ingredientes y se descarta enseguida. No la guardamos ni la compartimos con nadie."))
                .font(Typeface.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 300)

            VStack(spacing: Space.xs) {
                if camera.access == .denied || camera.access == .restricted {
                    Button(String(localized: "Abrir Ajustes")) {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(InkButtonStyle(fill: .white, foreground: .black, fullWidth: true))
                } else {
                    Button(String(localized: "Permitir cámara")) {
                        Task {
                            await camera.requestAccess()
                            if camera.access == .authorized {
                                stage = .framing
                                await camera.start()
                            }
                        }
                    }
                    .buttonStyle(InkButtonStyle(fill: .white, foreground: .black, fullWidth: true))
                }

                // Salida alternativa: nunca dejamos al usuario en una pantalla muerta.
                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "Cargar ingredientes a mano"))
                        .font(Typeface.action)
                        .foregroundStyle(.white.opacity(0.75))
                        .hitTarget(horizontal: 8, vertical: 12)
                }
                .buttonStyle(.plain)
                .padding(.top, Space.xxs)
            }
            .padding(.horizontal, Space.xl)

            Spacer()
        }
        .padding(Space.lg)
    }

    // MARK: - Encuadre

    private var framingStage: some View {
        ZStack {
            if camera.isRunning {
                CameraPreview(session: camera.session) { point in
                    camera.focus(at: point)
                    Haptics.select()
                }
                .ignoresSafeArea()
            } else {
                // Simulador o cámara no disponible: fondo vivo en vez de negro muerto.
                FluidBackdrop(palette: .scanning, intensity: 0.9)
                    .ignoresSafeArea()
            }

            // Viñeta: concentra la mirada en el centro del encuadre.
            RadialGradient(
                colors: [.clear, .black.opacity(0.45)],
                center: .center, startRadius: 140, endRadius: 420
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // El marco cambia de proporción con el modo. Que la forma del visor
            // responda a lo que se va a fotografiar es la única instrucción que
            // el usuario lee sin leer nada.
            ViewfinderCorners()
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: subject.viewfinderSize.width,
                       height: subject.viewfinderSize.height)
                .shadow(color: .black.opacity(0.3), radius: 8)
                .motion(Motion.morph, value: subject)

            VStack {
                Spacer()

                if camera.isTooDark {
                    lowLightHint
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Text(subject.framingHint)
                    .font(Typeface.callout)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, 8)
                    .glassCapsule(role: .overlay, shadow: false)
                    .padding(.horizontal, Space.screen)
                    .contentTransition(.opacity)
                    .padding(.bottom, Space.md)

                subjectSelector
                    .padding(.bottom, Space.lg)

                shutterButton
                    .padding(.bottom, Space.xxl)
            }
            .motion(Motion.standard, value: camera.isTooDark)
        }
    }

    /// Selector de modo, con la física del de la cámara nativa: cristal líquido,
    /// el indicador viaja, y el háptico confirma antes de que el ojo lo registre.
    private var subjectSelector: some View {
        GlassRail(spacing: Space.xs) {
            HStack(spacing: 4) {
                ForEach(ScanSubject.allCases) { option in
                    subjectOption(option)
                }
            }
            .padding(4)
            .glassCapsule(role: .overlay, shadow: false)
        }
    }

    private func subjectOption(_ option: ScanSubject) -> some View {
        let isSelected = option == subject

        return Button {
            guard !isSelected else { return }
            Haptics.select()
            withAnimation(Motion.morph) { subject = option }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(Typeface.scaled(11, weight: .semibold))
                Text(option.title)
                    .font(Typeface.action)
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.75))
            .padding(.horizontal, Space.md)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(.white)
                        .matchedGeometryEffect(id: "subject", in: subjectNamespace)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option == .pantry
            ? String(localized: "Escanear nevera o alacena")
            : String(localized: "Escanear ticket de compra"))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var lowLightHint: some View {
        HStack(spacing: 7) {
            Image(systemName: "bolt.fill")
                .font(Typeface.scaled(11, weight: .semibold))
            Text(String(localized: "Hay poca luz. Vamos a usar el flash."))
                .font(Typeface.micro)
                .fontWeight(.medium)
        }
        .foregroundStyle(Palette.turmeric)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassCapsule(role: .overlay, shadow: false)
        .padding(.bottom, Space.sm)
    }

    private var shutterButton: some View {
        Button {
            Task { await capture() }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 74, height: 74)
                Circle()
                    .fill(.white)
                    .frame(width: 60, height: 60)
                    .scaleEffect(camera.isCapturing ? 0.85 : 1)
                if camera.isCapturing {
                    ProgressView().tint(.black)
                }
            }
            .motion(Motion.tap, value: camera.isCapturing)
        }
        .disabled(camera.isCapturing)
        .accessibilityLabel(subject == .receipt
            ? String(localized: "Sacar foto del ticket")
            : String(localized: "Sacar foto de la nevera"))
    }

    // MARK: - Análisis

    private var analysisStage: some View {
        GeometryReader { proxy in
            ZStack {
                photoBackdrop

                if !reduceMotion, stage == .analyzing {
                    ScanBeam()
                }

                // Pins de detección sobre la foto.
                ForEach(detected) { item in
                    if let box = item.detectionBox {
                        DetectionPin(ingredient: item)
                            .position(
                                x: box.midX * proxy.size.width,
                                y: box.midY * proxy.size.height
                            )
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }

                VStack {
                    Spacer()
                    analysisFooter
                }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var photoBackdrop: some View {
        if let capturedImage {
            Image(uiImage: capturedImage)
                .resizable()
                .scaledToFill()
                .overlay { Color.black.opacity(0.35) }
                .blur(radius: stage == .review ? 6 : 0)
                .motion(Motion.standard, value: stage)
        } else {
            FluidBackdrop(palette: .scanning, intensity: 0.9)
        }
    }

    private var analysisFooter: some View {
        VStack(spacing: Space.md) {
            HStack(spacing: Space.xs) {
                Image(systemName: "sparkles")
                    .font(Typeface.scaled(12, weight: .semibold))
                    .foregroundStyle(Palette.turmeric)
                    .symbolEffect(.variableColor.iterative, isActive: stage == .analyzing)

                Text(caption)
                    .font(Typeface.action)
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: caption)

                Spacer()

                Text("\(detected.count)")
                    .font(Typeface.statSmall)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(detected.count)))
            }

            ProgressTrack(value: progress, accent: Palette.turmeric, height: 4)
        }
        .padding(Space.md)
        .liquidGlass(in: RoundedRectangle.soft(Radius.lg), role: .overlay)
        .padding(.horizontal, Space.screen)
        .padding(.bottom, Space.xxl)
    }

    // MARK: - Acciones

    private func capture() async {
        // La cuota se consume ANTES de sacar la foto y se comunica si falla:
        // enterarte del límite después de encuadrar es la peor versión posible.
        guard app.consume(.scan) else {
            dismiss()
            return
        }

        Haptics.commit()
        let image = await camera.capturePhoto()
        camera.stop()

        capturedImage = image
        stage = .analyzing
        progress = 0
        detected = []

        // Sin cámara real (simulador) igual corremos el flujo con la imagen nil:
        // el escáner mock no la necesita y así se puede diseñar sin dispositivo.
        await runScan(on: image ?? UIImage())
    }

    /// El motor lo elige el modo del visor. La pantalla no sabe cuál corrió:
    /// los dos hablan `ScanPhase`, y por eso añadir el ticket no tocó el teatro
    /// del análisis ni la hoja de revisión.
    private func phases(for image: UIImage) -> AsyncThrowingStream<ScanPhase, Error> {
        switch subject {
        case .pantry:  app.scanner.scan(image)
        case .receipt: app.receiptScanner.scan(image)
        }
    }

    private func runScan(on image: UIImage) async {
        scanTask?.cancel()
        let task = Task {
            do {
                for try await phase in phases(for: image) {
                    guard !Task.isCancelled else { return }

                    switch phase {
                    case .preparing:
                        caption = phase.caption(for: subject)

                    case .analyzing(let value):
                        caption = phase.caption(for: subject)
                        withAnimation(Motion.meter) { progress = value * 0.95 }

                    case .detected(let ingredient):
                        withAnimation(Motion.entrance) {
                            detected.append(ingredient)
                        }
                        Haptics.tick()

                    case .finished(let result):
                        withAnimation(Motion.meter) { progress = 1 }
                        caption = String(localized: "\(result.detected.count) ingredientes")
                        Haptics.celebrate()
                        try? await Task.sleep(for: .milliseconds(650))
                        guard !Task.isCancelled else { return }
                        detected = result.detected
                        stage = .review
                    }
                }
            } catch let error as ScanError {
                // Un escaneo que no devolvió nada no se cobra. Gastar una de
                // las tres de la semana porque el ticket salió borroso es la
                // clase de detalle que decide si la cuota se percibe justa.
                if case .cancelled = error {} else { app.refund(.scan) }
                failure = error
            } catch {
                app.refund(.scan)
                failure = .noIngredientsFound
            }
        }
        scanTask = task
        await task.value
    }
}

// MARK: - Haz de escaneo

/// Barrido vertical con estela. Se dibuja una sola vez y se mueve con `offset`,
/// así no hay re-layout por frame.
private struct ScanBeam: View {
    @State private var travel: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [
                    .clear,
                    Palette.turmeric.opacity(0.0),
                    Palette.turmeric.opacity(0.35),
                    .white.opacity(0.85),
                    Palette.turmeric.opacity(0.35),
                    .clear
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 180)
            .blur(radius: 6)
            .offset(y: travel * proxy.size.height)
            .blendMode(.plusLighter)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                    travel = 1
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Pin de detección

/// Cápsula que aparece sobre el ingrediente reconocido. Si la confianza es baja
/// se marca en ámbar: mostrar una duda como certeza es peor que no mostrarla.
private struct DetectionPin: View {
    let ingredient: Ingredient

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(ingredient.needsReview ? Palette.turmeric : Palette.sage)
                .frame(width: 6, height: 6)

            Text(ingredient.name)
                .font(Typeface.scaled(11.5, weight: .semibold))
                .foregroundStyle(.white)

            if ingredient.needsReview {
                Image(systemName: "questionmark")
                    .font(Typeface.scaled(8, weight: .bold))
                    .foregroundStyle(Palette.turmeric)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5.5)
        .glassCapsule(role: .overlay)
        .accessibilityLabel(ingredient.needsReview
            ? String(localized: "\(ingredient.name), detección dudosa")
            : ingredient.name)
    }
}
