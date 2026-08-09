//
//  RecipeHeroArt.swift
//  FridgeWise
//
//  Arte procedural para las recetas que todavía no tienen foto.
//
//  El problema real: una app de comida sin fotos se ve muerta, pero un
//  placeholder gris se ve rota. La solución es generar una composición abstracta
//  DETERMINISTA a partir del título — la misma receta siempre da la misma imagen,
//  así el usuario la reconoce, y cada receta se ve distinta de la de al lado.
//
//  La composición imita el desenfoque de una foto cenital de ingredientes:
//  formas orgánicas superpuestas, paleta derivada del acento de la receta,
//  y grano encima para que no parezca un degradado de Figma.
//

import SwiftUI

struct RecipeHeroArt: View {
    let recipe: Recipe
    var intensity: Double = 1

    var body: some View {
        ZStack {
            if let imageName = recipe.imageName, UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                proceduralArt
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var proceduralArt: some View {
        let accent = recipe.accent.color
        let seed = recipe.heroSeed

        return Canvas { context, size in
            // Base: dos tonos del acento en diagonal.
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [
                        accent.opacity(0.30 * intensity),
                        accent.opacity(0.14 * intensity)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )

            // Cinco blobs con posiciones derivadas de la semilla.
            let companions = Self.companionColors(for: recipe.accent)
            for index in 0..<5 {
                let phase = Double(seed + index * 47)
                let radius = size.width * (0.20 + 0.16 * abs(sin(phase * 0.7)))
                let cx = size.width * (0.15 + 0.72 * abs(sin(phase * 0.31)))
                let cy = size.height * (0.18 + 0.66 * abs(cos(phase * 0.23)))
                let color = companions[index % companions.count]

                context.fill(
                    Path(ellipseIn: CGRect(
                        x: cx - radius, y: cy - radius,
                        width: radius * 2, height: radius * 2.0 * (0.7 + 0.4 * abs(cos(phase)))
                    )),
                    with: .color(color.opacity((0.16 + 0.10 * abs(sin(phase * 1.3))) * intensity))
                )
            }
        }
        .blur(radius: 18)
        .overlay {
            // Viñeta suave: le da volumen y evita que el texto compita.
            RadialGradient(
                colors: [.clear, Palette.ink.opacity(0.10)],
                center: .center, startRadius: 40, endRadius: 220
            )
        }
        .overlay { PaperGrain(opacity: 0.05) }
        .background(Palette.canvasSunken)
    }

    /// Colores acompañantes: el acento propio más dos vecinos de la paleta.
    /// Nunca colores al azar — la coherencia cromática es lo que hace que
    /// una grilla de 20 tarjetas se lea como un sistema y no como confeti.
    private static func companionColors(for family: AccentFamily) -> [Color] {
        switch family {
        case .tomato:   [Palette.tomato, Palette.clay, Palette.turmeric]
        case .clay:     [Palette.clay, Palette.turmeric, Palette.tomato]
        case .sage:     [Palette.sage, Palette.basil, Palette.turmeric]
        case .basil:    [Palette.basil, Palette.sage, Palette.mist]
        case .turmeric: [Palette.turmeric, Palette.clay, Palette.sage]
        case .plum:     [Palette.plum, Palette.mist, Palette.clay]
        case .mist:     [Palette.mist, Palette.plum, Palette.sage]
        }
    }
}

// MARK: - Insignia de origen

/// Marca de dónde viene la receta. En el caso de IA es OBLIGATORIO ser explícito:
/// presentar contenido generado como si fuera curado por humanos es engañoso
/// y, para recetas, además es un riesgo de seguridad alimentaria.
struct SourceBadge: View {
    let source: RecipeSource
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: source.icon)
                .font(.system(size: compact ? 9 : 10, weight: .semibold))
            if !compact {
                Text(source.label)
                    .font(Typeface.micro)
                    .fontWeight(.semibold)
            }
        }
        .foregroundStyle(source.accent.color)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 5 : 5.5)
        .background {
            Capsule().fill(Palette.surface.opacity(0.92))
        }
        .overlay {
            Capsule().strokeBorder(source.accent.color.opacity(0.28), lineWidth: Stroke.hairline)
        }
        .accessibilityLabel(source.label)
    }
}
