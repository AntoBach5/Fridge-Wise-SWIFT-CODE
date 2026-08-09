//
//  Buttons.swift
//  FridgeWise
//
//  Cero botones azules de sistema. Tres estilos y nada más:
//  · Ink    → acción primaria. Pill de tinta, texto crema. Uno por pantalla.
//  · Quiet  → acción secundaria. Contorno hairline sobre papel.
//  · Accent → acción con carga semántica (premium, canjear, reportar).
//
//  Todos comparten la misma física de press: escala 0.965 + un pelín de
//  reducción de sombra. Nada de opacidad al 50%, que es el tell del prototipo.
//

import SwiftUI

// MARK: - Primario

struct InkButtonStyle: ButtonStyle {
    var fill: Color = Palette.inkSolid
    var foreground: Color = Palette.onInk
    var horizontalPadding: CGFloat = Space.lg
    var verticalPadding: CGFloat = 13
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.action)
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background {
                Capsule(style: .continuous).fill(fill)
            }
            .shadow(color: fill.opacity(configuration.isPressed ? 0.10 : 0.22),
                    radius: configuration.isPressed ? 6 : 14,
                    x: 0, y: configuration.isPressed ? 2 : 7)
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

// MARK: - Secundario

struct QuietButtonStyle: ButtonStyle {
    var foreground: Color = Palette.ink
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.action)
            .foregroundStyle(foreground)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 11)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background {
                Capsule(style: .continuous)
                    .fill(Palette.surface.opacity(configuration.isPressed ? 1 : 0.6))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

// MARK: - Acento

struct AccentButtonStyle: ButtonStyle {
    var accent: Color
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.action)
            .foregroundStyle(accent)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 11)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background {
                Capsule(style: .continuous).fill(accent.opacity(configuration.isPressed ? 0.22 : 0.14))
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

// MARK: - Icono

/// Botón circular de icono para las barras superiores. Área táctil de 44pt garantizada
/// aunque el glifo se vea de 34 — requisito de las HIG que casi nadie respeta.
struct IconButton: View {
    let systemImage: String
    var accent: Color = Palette.ink
    var background: Color = Palette.surface
    var accessibilityLabel: String
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(background)
                }
                .overlay {
                    Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
                }
                .contentShape(Circle())
                .frame(width: 44, height: 44)     // área táctil
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.9 : 1)
        .motion(Motion.tap, value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Tarjeta presionable

/// Convierte cualquier tarjeta en algo tocable con la física correcta.
/// Se usa en vez de meter la tarjeta en un `Button` (que le mete el tinte de sistema).
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.978 : 1)
            .brightness(configuration.isPressed ? -0.015 : 0)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableCardStyle {
    static var pressableCard: PressableCardStyle { PressableCardStyle() }
}

extension ButtonStyle where Self == InkButtonStyle {
    static var ink: InkButtonStyle { InkButtonStyle() }
    static func ink(fullWidth: Bool) -> InkButtonStyle { InkButtonStyle(fullWidth: fullWidth) }
}

extension ButtonStyle where Self == QuietButtonStyle {
    static var quiet: QuietButtonStyle { QuietButtonStyle() }
}
