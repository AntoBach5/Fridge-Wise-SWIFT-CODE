//
//  Haptics.swift
//  FridgeWise
//
//  Vocabulario háptico. Cada evento de la app mapea a UNA sensación y siempre la misma.
//  La consistencia háptica es la mitad de por qué una app "se siente" cara.
//

import UIKit
import SwiftUI

@MainActor
enum Haptics {

    /// Toque de selección: chips, segmentos, filas de lista.
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Acción confirmada: tildar un ítem, guardar receta.
    static func tick() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Acción de peso: escanear, generar receta, canjear puntos.
    static func commit() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Celebración: ingredientes detectados, recompensa desbloqueada, subida de nivel.
    static func celebrate() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Límite alcanzado en el plan gratuito, error de red, validación fallida.
    static func reject() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Pre-carga el generador antes de una interacción prevista (ej.: al abrir la cámara)
    /// para que el primer háptico no llegue tarde.
    static func prepare() {
        UIImpactFeedbackGenerator(style: .medium).prepare()
    }
}
