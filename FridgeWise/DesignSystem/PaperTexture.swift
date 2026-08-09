//
//  PaperTexture.swift
//  FridgeWise
//
//  Grano de papel procedural sobre el lienzo. Es sutil hasta el punto de ser
//  casi imperceptible (3-4% de opacidad) y sin embargo es lo que impide que
//  los fondos planos se lean como "pantalla" en vez de "papel".
//
//  Se genera UNA vez y se cachea: dibujar ruido por frame quemaría batería.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct PaperGrain: View {
    var opacity: Double = 0.035

    var body: some View {
        Image(decorative: PaperGrain.noiseImage, scale: 1)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .blendMode(.multiply)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }

    /// Tile de ruido monocromo de 180×180, generado una sola vez por proceso.
    nonisolated(unsafe) private static let noiseImage: CGImage = {
        let size = CGSize(width: 180, height: 180)
        let context = CIContext(options: [.useSoftwareRenderer: false])

        let noise = CIFilter.randomGenerator()
        // Desatura y comprime el rango: queremos grano, no estática de TV.
        let mono = CIFilter.colorControls()
        mono.inputImage = noise.outputImage
        mono.saturation = 0
        mono.contrast = 0.42
        mono.brightness = 0.06

        let cropped = (mono.outputImage ?? CIImage.empty())
            .cropped(to: CGRect(origin: .zero, size: size))

        if let cg = context.createCGImage(cropped, from: CGRect(origin: .zero, size: size)) {
            return cg
        }

        // Fallback opaco: 1×1 transparente. Nunca debería alcanzarse.
        let fallbackContext = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        return fallbackContext!.makeImage()!
    }()
}

// MARK: - Fondo de pantalla

/// Fondo canónico de toda pantalla: lienzo + grano.
/// Nunca se usa `Color.canvas` suelto como fondo — siempre este.
struct CanvasBackground: View {
    var sunken: Bool = false

    var body: some View {
        ZStack {
            (sunken ? Palette.canvasSunken : Palette.canvas)
                .ignoresSafeArea()
            PaperGrain()
        }
    }
}

extension View {
    func canvasBackground(sunken: Bool = false) -> some View {
        self.background(CanvasBackground(sunken: sunken))
    }
}
