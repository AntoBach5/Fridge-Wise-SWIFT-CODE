//
//  Shapes.swift
//  FridgeWise
//
//  Formas dibujadas a mano que dan el carácter "editorial hecho a mano" del sistema:
//  el squiggle bajo la palabra enfatizada, el trazo de tilde que se dibuja solo,
//  y el marco de esquinas del visor del escáner.
//

import SwiftUI

// MARK: - Squiggle

/// Subrayado ondulado dibujado a mano bajo la palabra enfatizada del titular.
/// Es la firma gráfica de la marca: aparece una sola vez por pantalla.
struct Squiggle: Shape {
    /// Cantidad de ondas completas a lo largo del ancho.
    var waves: CGFloat = 3.2
    /// Amplitud vertical como fracción de la altura disponible.
    var amplitude: CGFloat = 0.34

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let amp = rect.height * amplitude
        let step = rect.width / (waves * 2)

        path.move(to: CGPoint(x: rect.minX, y: midY))

        var x = rect.minX
        var up = true
        while x < rect.maxX {
            let nextX = min(x + step, rect.maxX)
            // Se estrecha hacia los extremos: imita la presión de un fibrón real.
            let taper = 1 - pow(abs((x + step / 2 - rect.midX) / (rect.width / 2)), 2) * 0.45
            path.addQuadCurve(
                to: CGPoint(x: nextX, y: midY),
                control: CGPoint(x: x + step / 2, y: midY + (up ? -amp : amp) * taper)
            )
            x = nextX
            up.toggle()
        }
        return path
    }
}

/// Overlay del squiggle con animación de dibujado (`trim`).
private struct SquiggleUnderline: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let color: Color
    let delay: Double

    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                Squiggle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(height: 9)
                    .offset(y: 8)
                    .allowsHitTesting(false)
            }
            .task {
                guard progress == 0 else { return }
                if reduceMotion {
                    progress = 1
                } else {
                    try? await Task.sleep(for: .seconds(delay))
                    withAnimation(.easeOut(duration: 0.65)) { progress = 1 }
                }
            }
    }
}

extension View {
    /// Subraya con el squiggle dibujado a mano. Aplicar a un `Text` corto, nunca a un párrafo.
    func squiggleUnderline(_ color: Color = Palette.turmeric, delay: Double = 0.35) -> some View {
        modifier(SquiggleUnderline(color: color, delay: delay))
    }
}

// MARK: - Tilde dibujado

/// Check dibujado con proporciones manuales (no el SF Symbol) para poder animar el trazo.
struct CheckStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.53))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.74))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.80, y: rect.minY + rect.height * 0.28))
        return path
    }
}

// MARK: - Marco del escáner

/// Cuatro esquinas de encuadre estilo visor. Se dibujan como un solo `Shape`
/// para que animen como una unidad al detectar.
struct ViewfinderCorners: Shape {
    var cornerLength: CGFloat = 28
    var radius: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l = min(cornerLength, min(rect.width, rect.height) / 2 - radius)

        // Superior izquierda
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + radius + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                 radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + radius + l, y: rect.minY))

        // Superior derecha
        p.move(to: CGPoint(x: rect.maxX - radius - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                 radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + radius + l))

        // Inferior derecha
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - radius - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        p.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                 radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX - radius - l, y: rect.maxY))

        // Inferior izquierda
        p.move(to: CGPoint(x: rect.minX + radius + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                 radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius - l))

        return p
    }
}

// MARK: - Sparkline

/// Curva suavizada para el gráfico de ritmo semanal. Usa Catmull-Rom simplificado
/// para que no tenga los picos angulosos de un `Path` con `addLine`.
struct SmoothLine: Shape {
    var points: [CGFloat]      // valores normalizados 0...1
    var closed: Bool = false   // true = área rellenable

    var animatableData: AnimatableVector {
        get { AnimatableVector(values: points.map(Double.init)) }
        set { points = newValue.values.map { CGFloat($0) } }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }

        let stepX = rect.width / CGFloat(points.count - 1)
        let coords = points.enumerated().map { index, value in
            CGPoint(x: rect.minX + CGFloat(index) * stepX,
                    y: rect.maxY - value.clamped(to: 0...1) * rect.height)
        }

        path.move(to: coords[0])
        for i in 1..<coords.count {
            let prev = coords[i - 1]
            let curr = coords[i]
            let controlX = (prev.x + curr.x) / 2
            path.addCurve(to: curr,
                          control1: CGPoint(x: controlX, y: prev.y),
                          control2: CGPoint(x: controlX, y: curr.y))
        }

        if closed {
            path.addLine(to: CGPoint(x: coords.last!.x, y: rect.maxY))
            path.addLine(to: CGPoint(x: coords.first!.x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// Permite interpolar un array de valores para animar el sparkline entre semanas.
struct AnimatableVector: VectorArithmetic {
    var values: [Double]

    static var zero: AnimatableVector { AnimatableVector(values: []) }

    static func + (lhs: Self, rhs: Self) -> Self { zip3(lhs, rhs, +) }
    static func - (lhs: Self, rhs: Self) -> Self { zip3(lhs, rhs, -) }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * rhs }
    }

    var magnitudeSquared: Double {
        values.reduce(0) { $0 + $1 * $1 }
    }

    private static func zip3(_ lhs: Self, _ rhs: Self, _ op: (Double, Double) -> Double) -> Self {
        let count = max(lhs.values.count, rhs.values.count)
        return AnimatableVector(values: (0..<count).map {
            op($0 < lhs.values.count ? lhs.values[$0] : 0,
               $0 < rhs.values.count ? rhs.values[$0] : 0)
        })
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
