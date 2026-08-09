//
//  DataViz.swift
//  FridgeWise
//
//  Visualizaciones. Todas comparten reglas:
//  · Sin ejes, sin grillas, sin leyendas flotantes. El label vive pegado al dato.
//  · Los números usan `.contentTransition(.numericText())` — nunca parpadean, ruedan.
//  · Todo anima desde 0 al aparecer, una sola vez, con `Motion.meter`.
//  · Cada gráfico tiene `accessibilityValue` en prosa; VoiceOver no lee píxeles.
//

import SwiftUI

// MARK: - Barra de distribución

/// La fila `● PROTEÍNAS ──────────── 40%` de la referencia, reasignada a macros.
/// Es el caballito de batalla del panel nutricional.
struct DistributionRow: View {
    let label: String
    let value: Double          // 0...1
    let accent: Color
    var trailingText: String? = nil

    @State private var animated: Double = 0

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: Space.xs) {
                AccentDot(color: accent, size: 7)
                Text(label)
                    .font(Typeface.caption)
                    .foregroundStyle(Palette.inkSoft)
                Spacer(minLength: Space.sm)
                Text(trailingText ?? "\(Int((value * 100).rounded()))%")
                    .font(Typeface.percentage)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText(value: value))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Palette.hairline.opacity(0.7))
                    Capsule(style: .continuous)
                        .fill(accent)
                        .frame(width: max(4, proxy.size.width * animated))
                }
            }
            .frame(height: 5)
        }
        .task {
            withAnimation(Motion.meter) { animated = value.clamped(to: 0...1) }
        }
        .onChange(of: value) { _, new in
            withAnimation(Motion.meter) { animated = new.clamped(to: 0...1) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(trailingText ?? "\(Int((value * 100).rounded())) por ciento")
    }
}

// MARK: - Número que rueda

/// Contador con dígitos monoespaciados que interpola en vez de saltar.
/// Se usa en puntos, calorías, racha y precio.
struct RollingNumber: View {
    let value: Int
    var font: Font = Typeface.stat()
    var color: Color = Palette.ink
    var prefix: String = ""
    var suffix: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if !prefix.isEmpty {
                Text(prefix).font(Typeface.statSmall).foregroundStyle(color.opacity(0.6))
            }
            Text("\(value)")
                .font(font)
                .foregroundStyle(color)
                .contentTransition(.numericText(value: Double(value)))
            if !suffix.isEmpty {
                Text(suffix).font(Typeface.statSmall).foregroundStyle(color.opacity(0.6))
            }
        }
        .motion(Motion.meter, value: value)
    }
}

// MARK: - Métrica

/// Bloque `valor / label` para las tiras de estadísticas del detalle de receta.
struct MetricStat: View {
    let value: String
    let label: String
    var systemImage: String? = nil
    var accent: Color = Palette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                }
                Text(value)
                    .font(Typeface.statSmall)
                    .foregroundStyle(Palette.ink)
            }
            Text(label).eyebrow()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Dificultad

/// Tres trazos verticales que se llenan. Más legible de un vistazo que la
/// palabra "Intermedio", y ocupa un cuarto del espacio.
struct DifficultyMeter: View {
    let level: Int          // 1...3
    var accent: Color = Palette.clay
    var showsLabel: Bool = true

    private var name: String {
        switch level {
        case 1: String(localized: "Fácil")
        case 2: String(localized: "Intermedio")
        default: String(localized: "Avanzado")
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2.5) {
                ForEach(1...3, id: \.self) { step in
                    Capsule(style: .continuous)
                        .fill(step <= level ? accent : Palette.hairline)
                        .frame(width: 3, height: 6 + CGFloat(step) * 3)
                }
            }
            .frame(height: 15, alignment: .bottom)

            if showsLabel {
                Text(name)
                    .font(Typeface.micro)
                    .fontWeight(.medium)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Dificultad"))
        .accessibilityValue(name)
    }
}

// MARK: - Salud nutricional

/// Anillo con la letra de score (A–E). Reemplaza al típico "8.4/10" que no
/// significa nada, y anima el trazo al aparecer.
struct NutritionScoreRing: View {
    let score: NutritionGrade
    var diameter: CGFloat = 54
    var showsCaption: Bool = true

    @State private var trim: CGFloat = 0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Palette.hairline, lineWidth: 3)

                Circle()
                    .trim(from: 0, to: trim * score.fill)
                    .stroke(score.color,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(score.letter)
                    .font(.system(size: diameter * 0.40, weight: .medium, design: .serif))
                    .foregroundStyle(score.color)
            }
            .frame(width: diameter, height: diameter)

            if showsCaption {
                Text(score.caption)
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        .task {
            withAnimation(Motion.meter.delay(0.1)) { trim = 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Salud nutricional"))
        .accessibilityValue("\(score.letter). \(score.caption)")
    }
}

// MARK: - Sparkline

/// Curva de ritmo semanal con relleno degradado, calcada del gráfico "Mood trend"
/// de la referencia. Sin ejes: sólo la forma y dos etiquetas en los extremos.
struct SparklineChart: View {
    let values: [CGFloat]       // normalizados 0...1
    var accent: Color = Palette.basil
    var leadingLabel: String = ""
    var trailingLabel: String = ""

    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(spacing: Space.xs) {
            ZStack {
                SmoothLine(points: values, closed: true)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.22), accent.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .opacity(progress)

                SmoothLine(points: values)
                    .trim(from: 0, to: progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Punto en el último valor, como ancla de lectura.
                GeometryReader { proxy in
                    let last = values.last ?? 0
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                        .overlay { Circle().strokeBorder(Palette.surface, lineWidth: 2) }
                        .position(x: proxy.size.width,
                                  y: proxy.size.height - last.clamped(to: 0...1) * proxy.size.height)
                        .opacity(progress > 0.9 ? 1 : 0)
                }
            }
            .frame(height: 64)

            HStack {
                Text(leadingLabel).eyebrow()
                Spacer()
                Text(trailingLabel).eyebrow()
            }
        }
        .task {
            withAnimation(.easeOut(duration: 0.9)) { progress = 1 }
        }
    }
}

// MARK: - Track de progreso

/// Barra de progreso genérica con cap redondeado. Usada en racha, nivel y
/// límites del plan gratuito.
struct ProgressTrack: View {
    let value: Double        // 0...1
    var accent: Color = Palette.turmeric
    var height: CGFloat = 6

    @State private var animated: Double = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(Palette.hairline.opacity(0.8))
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(colors: [accent.opacity(0.75), accent],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(height, proxy.size.width * animated))
            }
        }
        .frame(height: height)
        .task { withAnimation(Motion.meter) { animated = value.clamped(to: 0...1) } }
        .onChange(of: value) { _, new in
            withAnimation(Motion.meter) { animated = new.clamped(to: 0...1) }
        }
        .accessibilityValue("\(Int(value * 100)) por ciento")
    }
}
