//
//  Surfaces.swift
//  FridgeWise
//
//  Contenedores. Toda la app se construye con estas tres piezas —
//  no existe un `.background(Color.gray)` suelto en ningún lado.
//

import SwiftUI

// MARK: - Tarjeta

/// Tarjeta base: papel apenas más claro que el lienzo, hairline que la define,
/// y una sombra tan suave que se lee como profundidad y no como drop shadow.
struct SoftCard<Content: View>: View {
    var padding: CGFloat = Space.lg
    var radius: CGFloat = Radius.card
    /// Tinte de acento opcional, muy diluido, para tarjetas con carga semántica.
    var tint: Color? = nil
    var elevated: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle.soft(radius)
                        .fill(elevated ? Palette.surfaceRaised : Palette.surface)
                    if let tint {
                        RoundedRectangle.soft(radius)
                            .fill(tint.opacity(0.07))
                    }
                }
            }
            .overlay {
                RoundedRectangle.soft(radius)
                    .strokeBorder(tint?.opacity(0.22) ?? Palette.hairline,
                                  lineWidth: Stroke.hairline)
            }
            .shadow(color: Palette.cardShadow,
                    radius: elevated ? 26 : 16,
                    x: 0,
                    y: elevated ? 12 : 6)
    }
}

// MARK: - Encabezado de sección

/// `INGREDIENTES DETECTADOS ····························· 12`
/// El eyebrow + línea de puntos + valor es el ritmo visual que estructura las pantallas.
struct SectionHeader<Trailing: View>: View {
    let title: String
    var accent: Color = Palette.inkFaint
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: Space.sm) {
            Text(title).eyebrow(accent)

            Rectangle()
                .fill(Palette.hairline)
                .frame(height: Stroke.hairline)
                .frame(maxWidth: .infinity)

            trailing
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, accent: Color = Palette.inkFaint) {
        self.init(title: title, accent: accent) { EmptyView() }
    }
}

// MARK: - Chips

/// Chip informativo. Tres densidades según cuánta jerarquía necesite.
struct InfoChip: View {
    enum Weight { case quiet, tinted, solid }

    let label: String
    var systemImage: String? = nil
    var accent: Color = Palette.inkSoft
    var weight: Weight = .quiet

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10.5, weight: .semibold))
            }
            Text(label)
                .font(Typeface.micro)
                .fontWeight(.semibold)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 5.5)
        .background {
            Capsule(style: .continuous).fill(background)
        }
        .overlay {
            if weight == .quiet {
                Capsule(style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
        }
        .fixedSize()
    }

    private var foreground: Color {
        switch weight {
        case .quiet:  Palette.inkSoft
        case .tinted: accent
        case .solid:  Palette.onInk
        }
    }

    private var background: Color {
        switch weight {
        case .quiet:  .clear
        case .tinted: accent.opacity(0.13)
        case .solid:  accent
        }
    }
}

// MARK: - Punto de color

/// Marcador circular que precede a las filas. Viene directo de la referencia:
/// es lo que convierte una lista plana en algo con ritmo y categoría legible.
struct AccentDot: View {
    var color: Color
    var size: CGFloat = 9
    var filled: Bool = true

    var body: some View {
        Circle()
            .fill(filled ? color : .clear)
            .overlay {
                if !filled {
                    Circle().strokeBorder(color, lineWidth: Stroke.regular)
                }
            }
            .frame(width: size, height: size)
    }
}

// MARK: - Separador

/// Hairline con márgenes. Reemplaza `Divider()`, que en iOS trae un gris de sistema
/// que no combina con el papel cálido.
struct Hairline: View {
    var inset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: Stroke.hairline)
            .padding(.leading, inset)
    }
}
