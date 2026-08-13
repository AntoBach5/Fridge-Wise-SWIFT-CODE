//
//  FluidGradientBridge.swift
//  FridgeWise
//
//  Puente a Cindori/FluidGradient.
//  https://github.com/Cindori/FluidGradient
//
//  Por qué un puente y no usar la librería directo:
//  1. El proyecto compila y corre ANTES de resolver los paquetes SPM.
//  2. Si Apple cambia algo y la lib se rompe, la app sigue andando con el fallback.
//  3. Centraliza la receta de color: nadie inventa su propio gradiente por ahí suelto.
//
//  Dónde se usa (y dónde NO):
//  ✓ Hero de la Cocina, tarjeta de escaneo, paywall, celebración de recompensa, empty states.
//  ✗ Detrás de texto largo, en listas, o en más de un elemento por pantalla.
//    El gradiente fluido es un acento; si está en todos lados deja de ser especial.
//

import SwiftUI

#if canImport(FluidGradient)
import FluidGradient
#endif

/// Paletas curadas para el gradiente fluido. Todas derivan de `Palette`
/// y están desaturadas a propósito: el movimiento ya llama la atención,
/// el color no necesita gritar.
enum FluidPalette {
    /// Hero de la Cocina — atardecer de despensa.
    case pantry
    /// Escaneo en curso — frío / IA.
    case scanning
    /// Recompensas y premium — dorado cálido.
    case reward
    /// Generación de receta con IA.
    case intelligence

    var blobs: [Color] {
        switch self {
        case .pantry:       [Palette.sage, Palette.turmeric, Palette.clay]
        case .scanning:     [Palette.mist, Palette.sage, Palette.plum]
        case .reward:       [Palette.turmeric, Palette.clay, Palette.tomato]
        case .intelligence: [Palette.plum, Palette.mist, Palette.sage]
        }
    }

    var highlights: [Color] {
        switch self {
        case .pantry:       [Palette.turmeric, Palette.basil]
        case .scanning:     [Palette.mist, Palette.basil]
        case .reward:       [Palette.turmeric, Palette.tomato]
        case .intelligence: [Palette.plum, Palette.turmeric]
        }
    }

    /// Fallback estático coherente con el gradiente animado, para cuando
    /// "Reducir movimiento" está activo.
    var staticStops: [Color] {
        Array(blobs.prefix(2)) + Array(highlights.prefix(1))
    }
}

/// Fondo orgánico animado. Se degrada en tres niveles:
///   1. FluidGradient real (paquete resuelto + movimiento permitido)
///   2. Gradiente de malla nativo animado (paquete ausente)
///   3. Gradiente estático (Reducir movimiento activo)
struct FluidBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var palette: FluidPalette
    var speed: CGFloat = 0.42
    var blur: CGFloat = 0.72
    /// Opacidad global. Sobre papel cálido, por encima de ~0.5 se ve chillón.
    var intensity: Double = 0.38

    var body: some View {
        Group {
            if reduceMotion {
                StaticBlend(colors: palette.staticStops)
            } else {
                #if canImport(FluidGradient)
                FluidGradient(
                    blobs: palette.blobs,
                    highlights: palette.highlights,
                    speed: speed,
                    blur: blur
                )
                #else
                DriftingBlobs(colors: palette.blobs + palette.highlights, speed: speed)
                #endif
            }
        }
        .opacity(intensity)
        .allowsHitTesting(false)
        // El multiply integra el gradiente con el grano del papel en lugar de
        // flotar por encima como una calcomanía.
        .blendMode(.plusDarker)
    }
}

// MARK: - Fallbacks nativos

private struct StaticBlend: View {
    let colors: [Color]

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blur(radius: 40)
    }
}

/// Réplica nativa razonable de FluidGradient: blobs con deriva desfasada.
/// Barata (solo transforms) y no requiere Metal ni dependencias.
private struct DriftingBlobs: View {
    let colors: [Color]
    let speed: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate * Double(speed)
                context.addFilter(.blur(radius: min(size.width, size.height) * 0.28))

                for (index, color) in colors.enumerated() {
                    let phase = Double(index) * 1.7
                    let radius = min(size.width, size.height) * (0.36 + 0.08 * sin(t * 0.4 + phase))
                    let cx = size.width * (0.5 + 0.34 * cos(t * 0.31 + phase))
                    let cy = size.height * (0.5 + 0.30 * sin(t * 0.27 + phase * 1.3))

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: cx - radius, y: cy - radius,
                            width: radius * 2, height: radius * 2
                        )),
                        with: .color(color)
                    )
                }
            }
        }
    }
}
