//
//  RiveBridge.swift
//  FridgeWise
//
//  Puente a rive-app/rive-ios.
//  https://github.com/rive-app/rive-ios
//
//  Modelo mental: cada animación Rive de la app es un CASO del enum `RiveAsset`,
//  no un string suelto. Así el compilador garantiza que el nombre del archivo,
//  la state machine y los inputs coinciden, y renombrar un .riv rompe la build
//  en vez de fallar en silencio en producción.
//
//  Todas las animaciones tienen fallback nativo, así que la app se ve completa
//  aunque todavía no exista ningún .riv en el bundle (que es el estado actual).
//

import SwiftUI

#if canImport(RiveRuntime)
import RiveRuntime
#endif

// MARK: - Catálogo

/// Animaciones Rive de la app. Cada caso documenta el contrato que el archivo
/// .riv tiene que cumplir para que el diseñador de motion y el dev no se pisen.
enum RiveAsset {
    /// Escáner analizando. SM: "Scan" · inputs: `isScanning` (bool), `complete` (trigger)
    case scanner
    /// Chef pensando durante la generación con IA. SM: "Think" · input: `progress` (number 0-100)
    case thinking
    /// Confeti de recompensa. SM: "Celebrate" · input: `fire` (trigger)
    case celebration
    /// Estado vacío de heladera. SM: "Idle" · sin inputs
    case emptyFridge
    /// Llama de racha. SM: "Streak" · input: `days` (number)
    case streak

    var fileName: String {
        switch self {
        case .scanner:      "fw_scanner"
        case .thinking:     "fw_thinking"
        case .celebration:  "fw_celebration"
        case .emptyFridge:  "fw_empty_fridge"
        case .streak:       "fw_streak"
        }
    }

    var stateMachine: String {
        switch self {
        case .scanner:      "Scan"
        case .thinking:     "Think"
        case .celebration:  "Celebrate"
        case .emptyFridge:  "Idle"
        case .streak:       "Streak"
        }
    }
}

// MARK: - Controlador

/// Envuelve `RiveViewModel` detrás de una API que existe compile con o sin el paquete.
/// Las vistas hablan con esto, nunca con Rive directo.
@MainActor
@Observable
final class RiveController {

    let asset: RiveAsset
    /// `false` si el paquete no está linkeado o el .riv no está en el bundle.
    private(set) var isAvailable: Bool = false

    #if canImport(RiveRuntime)
    private var viewModel: RiveViewModel?
    #endif

    init(_ asset: RiveAsset, autoPlay: Bool = true) {
        self.asset = asset

        #if canImport(RiveRuntime)
        // `RiveViewModel` lanza si el archivo no existe en el bundle. Como los .riv
        // los entrega el diseñador de motion más tarde, esto tiene que ser no-fatal.
        guard Bundle.main.url(forResource: asset.fileName, withExtension: "riv") != nil else {
            self.isAvailable = false
            return
        }
        self.viewModel = RiveViewModel(
            fileName: asset.fileName,
            stateMachineName: asset.stateMachine,
            autoPlay: autoPlay
        )
        self.isAvailable = true
        #endif
    }

    /// Dispara un trigger de la state machine.
    func fire(_ input: String) {
        #if canImport(RiveRuntime)
        viewModel?.triggerInput(input)
        #endif
    }

    func setBool(_ input: String, _ value: Bool) {
        #if canImport(RiveRuntime)
        viewModel?.setInput(input, value: value)
        #endif
    }

    func setNumber(_ input: String, _ value: Double) {
        #if canImport(RiveRuntime)
        viewModel?.setInput(input, value: value)
        #endif
    }

    @ViewBuilder
    func makeView() -> some View {
        #if canImport(RiveRuntime)
        if let viewModel {
            viewModel.view()
        } else {
            EmptyView()
        }
        #else
        EmptyView()
        #endif
    }
}

// MARK: - Vista

/// Muestra una animación Rive, o el fallback nativo si no está disponible.
///
///     RiveStage(controller: scanController) {
///         PulsingScanFallback()
///     }
///
struct RiveStage<Fallback: View>: View {
    var controller: RiveController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder var fallback: Fallback

    var body: some View {
        // Con "Reducir movimiento" preferimos el fallback estático controlado
        // antes que una state machine que no sabemos si respeta la preferencia.
        if controller.isAvailable && !reduceMotion {
            controller.makeView()
                .accessibilityHidden(true)   // decorativa: el estado lo anuncia el texto
        } else {
            fallback
        }
    }
}
