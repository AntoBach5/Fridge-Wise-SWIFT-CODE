//
//  Typography.swift
//  FridgeWise
//
//  Dos familias, cero fuentes custom (New York y SF Pro vienen con el sistema,
//  soportan Dynamic Type y óptico automático — no hay nada que licenciar ni empaquetar):
//
//  · SERIF (New York) → titulares editoriales. Le da a la app la voz de una revista
//    de cocina en lugar de la de un dashboard.
//  · SANS (SF Pro)    → todo lo que es UI: labels, datos, botones, metadatos.
//
//  La jerarquía se construye con TAMAÑO y TRACKING, no con peso. Los serif pesados
//  se ven baratos; el titular respira en `.regular` y grande.
//

import SwiftUI

enum Typeface {

    // MARK: - Serif editorial

    /// Titular hero de pantalla. Una sola vez por vista, arriba de todo.
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    /// Titular hero en cursiva — reservado para la palabra enfatizada bajo el squiggle.
    static func displayItalic(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .regular, design: .serif).italic()
    }

    /// Título de sección grande ("Recetas para hoy").
    static let title = Font.system(size: 26, weight: .regular, design: .serif)

    /// Título de tarjeta / receta.
    static let cardTitle = Font.system(size: 19, weight: .medium, design: .serif)

    /// Cita o texto reflexivo dentro de una tarjeta.
    static let quote = Font.system(size: 17, weight: .regular, design: .serif)

    // MARK: - Sans UI

    /// Label en versalitas con tracking abierto. La firma tipográfica del sistema.
    /// Se usa SIEMPRE junto con `.eyebrow()` para heredar color y `textCase`.
    static let eyebrow = Font.system(size: 11, weight: .semibold, design: .default)

    static let headline = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 15.5, weight: .regular)
    static let callout = Font.system(size: 14, weight: .regular)
    static let caption = Font.system(size: 12.5, weight: .medium)
    static let micro = Font.system(size: 11, weight: .medium)

    /// Botones y chips.
    static let action = Font.system(size: 14.5, weight: .semibold)

    // MARK: - Datos

    /// Cifra grande (puntos, calorías, racha). Dígitos de ancho fijo para que
    /// no "salte" cuando anima con `.contentTransition(.numericText())`.
    static func stat(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .semibold).monospacedDigit()
    }

    static let statSmall = Font.system(size: 15, weight: .semibold).monospacedDigit()
    static let percentage = Font.system(size: 12.5, weight: .semibold).monospacedDigit()
}

// MARK: - Modificadores de texto

extension View {

    /// Micro-label en versalitas: `INGREDIENTES DETECTADOS`.
    func eyebrow(_ color: Color = Palette.inkFaint) -> some View {
        self.font(Typeface.eyebrow)
            .textCase(.uppercase)
            .tracking(1.35)
            .foregroundStyle(color)
    }

    /// Titular hero con el tracking negativo que necesita el serif a tamaño grande.
    func displayStyle(_ size: CGFloat = 34) -> some View {
        self.font(Typeface.display(size))
            .tracking(size > 28 ? -0.6 : -0.3)
            .foregroundStyle(Palette.ink)
            .lineSpacing(size * 0.06)
    }

    /// Cuerpo con el interlineado generoso que hace que el papel respire.
    func bodyStyle(_ color: Color = Palette.inkSoft) -> some View {
        self.font(Typeface.body)
            .foregroundStyle(color)
            .lineSpacing(4.5)
    }
}
