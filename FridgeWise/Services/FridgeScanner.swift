//
//  FridgeScanner.swift
//  FridgeWise
//
//  Reconocimiento de ingredientes.
//
//  El backend real (Vision + un modelo de detección, o una API remota) se
//  enchufa después. Lo que importa ahora es que el CONTRATO ya esté fijo, así
//  la UI se construye contra la interfaz final y no hay que reescribirla:
//
//    · Emite progreso, no solo un resultado → la pantalla de escaneo puede
//      contar una historia en lugar de mostrar un spinner.
//    · Devuelve confianza por ítem + caja de detección → podemos anclar pins
//      sobre la foto y marcar en ámbar lo que conviene que el usuario revise.
//    · Es `async` y cancelable → si el usuario cierra la cámara, se corta.
//
//  Al implementar el real: `VNCoreMLRequest` con un modelo de detección de
//  objetos alimentarios, o subida a un endpoint propio. Si va a un servidor,
//  hay que declararlo en el Privacy Manifest y en la nutrition label.
//

import SwiftUI

// MARK: - Contrato

protocol FridgeScanning: Sendable {
    /// Analiza una foto de nevera y va emitiendo el avance.
    func scan(_ image: UIImage) -> AsyncThrowingStream<ScanPhase, Error>
}

/// Etapas del análisis. Cada una tiene copy propio en la UI: el usuario ve
/// "Buscando en los estantes" y no una barra anónima.
enum ScanPhase: Sendable, Equatable {
    case preparing
    case analyzing(progress: Double)
    /// Un ingrediente apareció: la UI lo hace aparecer con spring + háptico.
    case detected(Ingredient)
    case finished(ScanResult)

    var caption: String {
        switch self {
        case .preparing:          String(localized: "Enfocando la nevera")
        case .analyzing(let p) where p < 0.4: String(localized: "Recorriendo los estantes")
        case .analyzing(let p) where p < 0.75: String(localized: "Identificando ingredientes")
        case .analyzing:          String(localized: "Casi listo")
        case .detected(let item): String(localized: "Encontré \(item.name)")
        case .finished:           String(localized: "Listo")
        }
    }
}

enum ScanError: LocalizedError {
    case cameraUnavailable
    case imageTooDark
    case noIngredientsFound
    case limitReached(resetsAt: Date)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            String(localized: "No pudimos acceder a la cámara.")
        case .imageTooDark:
            String(localized: "La foto salió muy oscura para reconocer nada.")
        case .noIngredientsFound:
            String(localized: "No reconocimos ingredientes en esta foto.")
        case .limitReached:
            String(localized: "Llegaste al límite de escaneos de hoy.")
        case .cancelled:
            String(localized: "Escaneo cancelado.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cameraUnavailable:
            String(localized: "Activa el permiso de cámara en Ajustes para escanear tu nevera.")
        case .imageTooDark:
            String(localized: "Abre la puerta del todo o enciende la luz de la cocina.")
        case .noIngredientsFound:
            String(localized: "Prueba acercándote un poco o añade los ingredientes a mano.")
        case .limitReached:
            String(localized: "Vuelve mañana, canjea puntos por escaneos extra, o pásate a Premium.")
        case .cancelled:
            nil
        }
    }
}

// MARK: - Mock

/// Implementación de desarrollo. Simula latencia, confianza variable y cajas de
/// detección plausibles para que la UI se pueda pulir con datos realistas.
struct MockFridgeScanner: FridgeScanning {

    func scan(_ image: UIImage) -> AsyncThrowingStream<ScanPhase, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.preparing)
                    try await Task.sleep(for: .milliseconds(520))

                    let candidates = SampleData.detectableIngredients.shuffled()
                        .prefix(Int.random(in: 6...9))
                    var detected: [Ingredient] = []

                    for (index, template) in candidates.enumerated() {
                        try Task.checkCancellation()

                        let progress = Double(index + 1) / Double(candidates.count)
                        continuation.yield(.analyzing(progress: progress))
                        try await Task.sleep(for: .milliseconds(Int.random(in: 240...420)))

                        var item = template
                        item.id = UUID()
                        item.confidence = Double.random(in: 0.62...0.98)
                        item.detectionBox = CGRect(
                            x: Double.random(in: 0.08...0.72),
                            y: Double.random(in: 0.12...0.78),
                            width: Double.random(in: 0.14...0.24),
                            height: Double.random(in: 0.12...0.20)
                        )
                        detected.append(item)
                        continuation.yield(.detected(item))
                    }

                    let overall = detected.compactMap(\.confidence).reduce(0, +)
                        / Double(max(detected.count, 1))

                    continuation.yield(.finished(
                        ScanResult(detected: detected, overallConfidence: overall)
                    ))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: ScanError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
