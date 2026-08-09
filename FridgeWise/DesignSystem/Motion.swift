//
//  Motion.swift
//  FridgeWise
//
//  Curvas de animación nombradas. Nadie escribe `.easeInOut` suelto en esta app:
//  el timing es parte de la marca igual que el color.
//
//  Todos los springs son críticamente amortiguados o cerca. Nada rebota dos veces —
//  el rebote doble es la firma visual del prototipo sin terminar.
//

import SwiftUI

enum Motion {

    /// Transición estándar de layout. El 80% de las animaciones de la app.
    static let standard = Animation.spring(response: 0.42, dampingFraction: 0.86)

    /// Elementos que entran o crecen. Un pelín más de rebote.
    static let entrance = Animation.spring(response: 0.5, dampingFraction: 0.78)

    /// Feedback inmediato al tacto (press states). Corto y seco.
    static let tap = Animation.spring(response: 0.24, dampingFraction: 0.9)

    /// Morphing del indicador del segmented y del tab bar.
    static let morph = Animation.spring(response: 0.38, dampingFraction: 0.82)

    /// Barras de progreso, anillos y contadores que "cuentan".
    static let meter = Animation.spring(response: 0.85, dampingFraction: 0.95)

    /// Loops ambientales (haz del escáner, shimmer). Lineal para que no pulse raro.
    static let ambient = Animation.linear(duration: 2.6).repeatForever(autoreverses: false)

    /// Respiración lenta de fondos y gradientes.
    static let breathe = Animation.easeInOut(duration: 4.2).repeatForever(autoreverses: true)

    /// Escalonado para listas que aparecen. Se corta a los 8 ítems para que
    /// el último elemento nunca espere más de ~0.4s.
    static func stagger(_ index: Int, base: Animation = entrance) -> Animation {
        base.delay(Double(min(index, 8)) * 0.045)
    }
}

// MARK: - Accesibilidad

/// Envuelve una animación respetando "Reducir movimiento".
/// Se usa en TODA la app: es requisito de accesibilidad y de review de App Store.
struct MotionAwareModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .easeInOut(duration: 0.15) : animation, value: value)
    }
}

extension View {
    /// `.motion(.standard, value: isOpen)` — como `.animation(_:value:)` pero
    /// degrada a un fade corto si el usuario pidió reducir movimiento.
    func motion<V: Equatable>(_ animation: Animation = Motion.standard, value: V) -> some View {
        modifier(MotionAwareModifier(animation: animation, value: value))
    }
}

/// Lee "Reducir movimiento" para apagar loops ambientales (haz del escáner,
/// gradientes fluidos) que no se pueden expresar como `.animation(_:value:)`.
struct AmbientMotionKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var ambientMotionEnabled: Bool {
        get { self[AmbientMotionKey.self] }
        set { self[AmbientMotionKey.self] = newValue }
    }
}
