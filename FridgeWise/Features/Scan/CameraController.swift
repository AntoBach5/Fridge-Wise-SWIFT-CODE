//
//  CameraController.swift
//  FridgeWise
//
//  Captura con AVFoundation.
//
//  Modelo de concurrencia (explícito, porque aquí es donde se rompen estas clases):
//  · El ESTADO OBSERVABLE vive en `@MainActor` — es lo que lee SwiftUI.
//  · Los objetos de AVFoundation (`session`, `photoOutput`, `device`) se tocan
//    SOLO desde `sessionQueue`, y por eso están marcados `nonisolated(unsafe)`:
//    la exclusión mutua la da la cola serial, no el actor.
//  · `startRunning()` bloquea; hacerlo en main es el motivo #1 de que la cámara
//    de una app "tarde en abrir".
//
//  App Store: `NSCameraUsageDescription` tiene que explicar el uso real.
//  Un texto genérico es rechazo por Guideline 5.1.1.
//

import AVFoundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class CameraController: NSObject {

    enum Access: Equatable {
        case unknown, authorized, denied, restricted, unavailable
    }

    // MARK: Estado observable (MainActor)

    private(set) var access: Access = .unknown
    private(set) var isRunning = false
    private(set) var isCapturing = false
    /// Luz insuficiente estimada. Avisamos antes de gastar un escaneo de la cuota.
    private(set) var isTooDark = false

    // MARK: Objetos de captura (solo desde sessionQueue)

    nonisolated let session = AVCaptureSession()
    nonisolated private let photoOutput = AVCapturePhotoOutput()
    nonisolated private let sessionQueue = DispatchQueue(label: "app.fridgewise.camera.session")

    nonisolated(unsafe) private var device: AVCaptureDevice?
    nonisolated(unsafe) private var isConfigured = false
    nonisolated(unsafe) private var captureContinuation: CheckedContinuation<UIImage?, Never>?

    private var lightMonitor: Task<Void, Never>?

    // MARK: Permisos

    func refreshAccess() {
        access = switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    .authorized
        case .denied:        .denied
        case .restricted:    .restricted
        case .notDetermined: .unknown
        @unknown default:    .unknown
        }
    }

    func requestAccess() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else {
            refreshAccess()
            return
        }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        access = granted ? .authorized : .denied
    }

    // MARK: Sesión

    func start() async {
        refreshAccess()
        guard access == .authorized else { return }

        let configured = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            sessionQueue.async { [self] in
                configureIfNeeded()
                if isConfigured, !session.isRunning {
                    session.startRunning()
                }
                continuation.resume(returning: isConfigured)
            }
        }

        guard configured else {
            access = .unavailable
            return
        }
        isRunning = true
        startLightMonitor()
    }

    func stop() {
        lightMonitor?.cancel()
        lightMonitor = nil
        isRunning = false
        sessionQueue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    /// Corre exclusivamente en `sessionQueue`.
    nonisolated private func configureIfNeeded() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back
              ),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input),
              session.canAddOutput(photoOutput)
        else { return }

        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .balanced

        device = camera
        isConfigured = true
    }

    // MARK: Luz

    /// Una nevera con la puerta entornada da fotos inservibles.
    private func startLightMonitor() {
        lightMonitor?.cancel()
        lightMonitor = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning else { return }
                let dark = await self.readIsTooDark()
                if dark != self.isTooDark {
                    self.isTooDark = dark
                }
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
    }

    private func readIsTooDark() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            sessionQueue.async { [self] in
                guard let device else { continuation.resume(returning: false); return }
                let offset = device.exposureTargetOffset
                let isoRatio = device.iso / max(device.activeFormat.maxISO, 1)
                continuation.resume(returning: offset < -1.5 || isoRatio > 0.85)
            }
        }
    }

    // MARK: Foco

    func focus(at devicePoint: CGPoint) {
        sessionQueue.async { [self] in
            guard let device, device.isFocusPointOfInterestSupported,
                  (try? device.lockForConfiguration()) != nil else { return }
            device.focusPointOfInterest = devicePoint
            device.focusMode = .autoFocus
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        }
    }

    // MARK: Captura

    func capturePhoto() async -> UIImage? {
        guard !isCapturing else { return nil }
        isCapturing = true
        defer { isCapturing = false }

        let useFlash = isTooDark

        return await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                guard isConfigured else {
                    continuation.resume(returning: nil)
                    return
                }
                captureContinuation = continuation

                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .balanced
                if let device, device.isFlashAvailable {
                    settings.flashMode = useFlash ? .on : .off
                }
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

// MARK: - Delegate

extension CameraController: AVCapturePhotoCaptureDelegate {
    /// AVFoundation llama esto en su propia cola; reanudamos la continuación
    /// desde `sessionQueue` para no cruzar el estado con main.
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image: UIImage? = {
            guard error == nil, let data = photo.fileDataRepresentation() else { return nil }
            return UIImage(data: data)
        }()

        sessionQueue.async { [self] in
            captureContinuation?.resume(returning: image)
            captureContinuation = nil
        }
    }
}

// MARK: - Preview

/// Capa de preview. Se usa `layerClass` para que el layer del `UIView` SEA el
/// preview: nada de sub-layers que haya que redimensionar a mano en `layoutSubviews`.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var onTapToFocus: ((CGPoint) -> Void)?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.onTapToFocus = onTapToFocus
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapToFocus: onTapToFocus)
    }

    @MainActor
    final class Coordinator: NSObject {
        var onTapToFocus: ((CGPoint) -> Void)?
        weak var view: PreviewView?

        init(onTapToFocus: ((CGPoint) -> Void)?) {
            self.onTapToFocus = onTapToFocus
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view else { return }
            let location = recognizer.location(in: view)
            // Conversión a coordenadas del dispositivo: sin esto el foco apunta
            // a cualquier lado en cuanto el aspect ratio no coincide.
            let devicePoint = view.previewLayer.captureDevicePointConverted(fromLayerPoint: location)
            onTapToFocus?(devicePoint)
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
