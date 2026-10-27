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

    // Dynamic Type (HIG · Typography): cada estilo parte de un text style del
    // sistema, así crece y se reduce con el tamaño de texto que elige la persona.
    // Los tamaños por defecto son los de siempre (±1 pt); lo que cambia es que
    // ahora escalan. Los titulares con tamaño propio escalan con `scaled(_:)`.

    // MARK: - Serif editorial

    /// Titular hero de pantalla. Una sola vez por vista, arriba de todo.
    @MainActor static func display(_ size: CGFloat = 34) -> Font {
        scaled(size, weight: .regular, design: .serif, relativeTo: .largeTitle)
    }

    /// Titular hero en cursiva — reservado para la palabra enfatizada bajo el squiggle.
    @MainActor static func displayItalic(_ size: CGFloat = 34) -> Font {
        display(size).italic()
    }

    /// Título de sección grande ("Recetas para hoy").
    @MainActor static var title: Font { scaled(26, weight: .regular, design: .serif, relativeTo: .title1) }

    /// Título de tarjeta / receta.
    static let cardTitle = Font.system(.title3, design: .serif, weight: .medium)

    /// Cita o texto reflexivo dentro de una tarjeta.
    static let quote = Font.system(.body, design: .serif, weight: .regular)

    // MARK: - Sans UI

    /// Label en versalitas con tracking abierto. La firma tipográfica del sistema.
    /// Se usa SIEMPRE junto con `.eyebrow()` para heredar color y `textCase`.
    static let eyebrow = Font.system(.caption2, design: .default, weight: .semibold)

    static let headline = Font.system(.callout, weight: .semibold)
    static let body = Font.system(.subheadline, weight: .regular)
    static let callout = Font.system(.footnote, weight: .regular)
    static let caption = Font.system(.caption, weight: .medium)
    static let micro = Font.system(.caption2, weight: .medium)

    /// Botones y chips.
    static let action = Font.system(.subheadline, weight: .semibold)

    // MARK: - Datos

    /// Cifra grande (puntos, calorías, racha). Dígitos de ancho fijo para que
    /// no "salte" cuando anima con `.contentTransition(.numericText())`.
    @MainActor static func stat(_ size: CGFloat = 30) -> Font {
        scaled(size, weight: .semibold, relativeTo: .title1).monospacedDigit()
    }

    static let statSmall = Font.system(.subheadline, weight: .semibold).monospacedDigit()
    static let percentage = Font.system(.caption, weight: .semibold).monospacedDigit()

    // MARK: - Tamaño propio con Dynamic Type

    /// Fuente del sistema a un tamaño concreto que escala con Dynamic Type
    /// igual que `textStyle`. Para titulares e iconos con tamaño de diseño propio.
    @MainActor static func scaled(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: UIFont.TextStyle = .body
    ) -> Font {
        .system(size: scaledValue(size, relativeTo: textStyle), weight: weight, design: design)
    }

    /// Mismo tope que aplica `FridgeWiseApp` con `.dynamicTypeSize`.
    static let maximumContentSize: UIContentSizeCategory = .accessibilityExtraExtraLarge

    /// Un tamaño propio (titular, glifo dentro de un círculo) no crece más de
    /// 1,6 veces su valor de diseño: más allá desborda su contenedor. El texto
    /// de lectura usa text styles y sí escala por completo.
    static let maximumCustomScale: CGFloat = 1.6

    @MainActor static func scaledValue(_ value: CGFloat, relativeTo textStyle: UIFont.TextStyle = .body) -> CGFloat {
        var category = UIApplication.shared.preferredContentSizeCategory
        if category == .unspecified { category = .large }
        if category > maximumContentSize { category = maximumContentSize }
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        let scaled = UIFontMetrics(forTextStyle: textStyle).scaledValue(for: value, compatibleWith: traits)
        return min(scaled, value * maximumCustomScale)
    }
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
