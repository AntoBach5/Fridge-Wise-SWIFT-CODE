//
//  Palette.swift
//  FridgeWise
//
//  Lenguaje visual "Warm Pantry".
//
//  Reglas del sistema:
//  · El lienzo NUNCA es blanco puro ni negro puro. Es papel cálido / tinta cálida.
//  · Un solo color de tinta para texto y superficies oscuras (pill del tab bar, botones).
//  · Los acentos derivan de produce real (tomate, salvia, cúrcuma, ciruela) y viven
//    desaturados: son marcadores semánticos, nunca relleno decorativo.
//  · Cero azul de sistema. El azul por defecto de SwiftUI está prohibido en esta app.
//

import SwiftUI

enum Palette {

    // MARK: - Lienzo y superficies

    /// Fondo base de toda la app. Papel hueso cálido.
    static let canvas = adaptive(light: 0xF4F1E9, dark: 0x14140F)

    /// Fondo hundido: usado detrás de secciones agrupadas y en pull-to-refresh.
    static let canvasSunken = adaptive(light: 0xEDE8DC, dark: 0x0F0F0B)

    /// Superficie de tarjeta. Apenas más clara que el lienzo — el contraste lo da el borde.
    static let surface = adaptive(light: 0xFCFAF5, dark: 0x1F1F1A)

    /// Superficie elevada (sheets, popovers, filas destacadas).
    static let surfaceRaised = adaptive(light: 0xFFFFFF, dark: 0x282821)

    /// Hairline de 0.75pt que define las tarjetas. Hace el 80% del refinamiento.
    static let hairline = adaptive(light: 0xE4DED0, dark: 0x33332B,
                                   highContrastLight: 0xB9B2A2, highContrastDark: 0x5A5A4F)

    // MARK: - Tinta (texto y superficies oscuras)

    /// Tinta primaria. Carbón con sesgo verde-azulado, no negro.
    static let ink = adaptive(light: 0x23282B, dark: 0xF2EFE5)

    /// Texto secundario / subtítulos.
    static let inkSoft = adaptive(light: 0x5E6560, dark: 0xA8A498,
                                  highContrastLight: 0x434944, highContrastDark: 0xC9C5B8)

    /// Labels en versalitas, metadatos, placeholders.
    /// Ajustado para llegar a 4,5:1 sobre el lienzo en claro y en oscuro
    /// (HIG · Accessibility: contraste mínimo del texto).
    static let inkFaint = adaptive(light: 0x697068, dark: 0x8F8C81,
                                   highContrastLight: 0x4F554E, highContrastDark: 0xB3B0A4)

    /// Superficie oscura constante (tab bar, botones primarios) — NO invierte en dark mode.
    /// Mantenerla fija es lo que preserva la identidad de la marca entre modos.
    static let inkSolid = adaptive(light: 0x23282B, dark: 0x2E2E27)

    /// Texto sobre `inkSolid`.
    static let onInk = adaptive(light: 0xF6F3EA, dark: 0xF2EFE5)

    // MARK: - Acentos de produce

    /// Tomate / pimiento. Alerta suave, ingredientes por vencer, dificultad alta.
    static let tomato = adaptive(light: 0xC2685B, dark: 0xD97D6E,
                                 highContrastLight: 0xA34B3D)

    /// Arcilla / cebolla morada. Categoría proteínas.
    static let clay = adaptive(light: 0xB78A72, dark: 0xC79A81,
                               highContrastLight: 0x8C624C)

    /// Salvia. Verduras, frescura, estados "ok".
    static let sage = adaptive(light: 0x8BA482, dark: 0x9BB491,
                               highContrastLight: 0x5D7656)

    /// Albahaca. Salud nutricional positiva, confirmaciones.
    static let basil = adaptive(light: 0x6C8F67, dark: 0x86A87F,
                                highContrastLight: 0x557A50)

    /// Cúrcuma. Puntos, recompensas, gamificación, premium.
    static let turmeric = adaptive(light: 0xD8A34C, dark: 0xE0B061,
                                   highContrastLight: 0x8F6516)

    /// Ciruela. IA / generación, comunidad.
    static let plum = adaptive(light: 0x93849F, dark: 0xA898B4,
                               highContrastLight: 0x6F6080)

    /// Niebla. Lácteos, congelados, estados fríos.
    static let mist = adaptive(light: 0x94A3C4, dark: 0xA3B1D0,
                               highContrastLight: 0x5B6A8C)

    // MARK: - Semántica

    static let positive = basil
    static let caution = turmeric
    static let critical = tomato
    static let premium = turmeric
    static let intelligence = plum

    // MARK: - Sombras

    /// Sombra ambiental de tarjeta. Muy baja opacidad: el papel no proyecta sombras duras.
    static let cardShadow = Color.black.opacity(0.055)
    static let cardShadowDeep = Color.black.opacity(0.10)

    // MARK: - Utilidades

    /// Devuelve el acento canónico de una categoría de despensa.
    static func accent(for family: AccentFamily) -> Color {
        switch family {
        case .tomato:   tomato
        case .clay:     clay
        case .sage:     sage
        case .basil:    basil
        case .turmeric: turmeric
        case .plum:     plum
        case .mist:     mist
        }
    }

    /// Color con variantes claro/oscuro y, opcionalmente, una variante para
    /// "Aumentar contraste" (HIG · Color: cada color propio necesita versión
    /// de alto contraste). Sin variante explícita, se usa la normal.
    private static func adaptive(
        light: UInt32,
        dark: UInt32,
        highContrastLight: UInt32? = nil,
        highContrastDark: UInt32? = nil
    ) -> Color {
        Color(UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHighContrast = traits.accessibilityContrast == .high
            let hex = switch (isDark, isHighContrast) {
            case (false, false): light
            case (true, false):  dark
            case (false, true):  highContrastLight ?? light
            case (true, true):   highContrastDark ?? dark
            }
            return UIColor(rgbHex: hex)
        })
    }
}

/// Familias de acento nombradas para que los modelos no acarreen `Color` (no es `Codable`).
enum AccentFamily: String, Codable, CaseIterable, Sendable {
    case tomato, clay, sage, basil, turmeric, plum, mist

    var color: Color { Palette.accent(for: self) }
}

// MARK: - Hex

extension UIColor {
    fileprivate convenience init(rgbHex: UInt32) {
        self.init(
            red: CGFloat((rgbHex >> 16) & 0xFF) / 255,
            green: CGFloat((rgbHex >> 8) & 0xFF) / 255,
            blue: CGFloat(rgbHex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension ShapeStyle where Self == Color {
    static var ink: Color { Palette.ink }
    static var inkSoft: Color { Palette.inkSoft }
    static var inkFaint: Color { Palette.inkFaint }
    static var canvas: Color { Palette.canvas }
    static var surface: Color { Palette.surface }
    static var hairline: Color { Palette.hairline }
}
