//
//  Controls.swift
//  FridgeWise
//
//  Controles custom. Ninguno es un `Picker`, `Toggle` o `Stepper` de sistema:
//  todos traen el tinte azul y la geometría de iOS estándar, que es exactamente
//  lo que hace que una app se vea "hecha con la plantilla".
//

import SwiftUI

// MARK: - Segmentado con indicador que se transforma

/// Selector de dos o tres opciones. El indicador viaja con `matchedGeometryEffect`,
/// así que al cambiar de segmento se desliza y se estira en lugar de aparecer.
struct MorphingSegments<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    var badge: (Item) -> Int? = { _ in nil }
    @Binding var selection: Item

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                let isSelected = item == selection

                Button {
                    guard !isSelected else { return }
                    Haptics.select()
                    withAnimation(Motion.morph) { selection = item }
                } label: {
                    HStack(spacing: 6) {
                        Text(title(item))
                            .font(Typeface.action)
                            .foregroundStyle(isSelected ? Palette.onInk : Palette.inkSoft)

                        if let count = badge(item), count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10.5, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(isSelected ? Palette.inkSolid : Palette.onInk)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background {
                                    Capsule().fill(isSelected ? Palette.onInk : Palette.inkSoft)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if isSelected {
                            Capsule(style: .continuous)
                                .fill(Palette.inkSolid)
                                .matchedGeometryEffect(id: "segment", in: namespace)
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(4)
        .background {
            Capsule(style: .continuous).fill(Palette.canvasSunken)
        }
        .overlay {
            Capsule(style: .continuous).strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
        }
    }
}

// MARK: - Tira de semana

/// La fila de días de la referencia: iniciales en versalita, número debajo,
/// pill oscura en el día activo y un punto de acento si hubo actividad.
struct WeekStrip: View {
    let days: [DayMarker]
    @Binding var selection: Date

    @Namespace private var namespace
    private let calendar = Calendar.current

    struct DayMarker: Identifiable, Hashable {
        let date: Date
        /// 0 = sin actividad. Colorea el punto según intensidad.
        var activity: Double = 0
        var accent: AccentFamily = .sage
        var id: Date { date }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(days) { day in
                let isSelected = calendar.isDate(day.date, inSameDayAs: selection)
                let isFuture = day.date > Date()

                Button {
                    Haptics.select()
                    withAnimation(Motion.morph) { selection = day.date }
                } label: {
                    VStack(spacing: 7) {
                        Text(day.date.formatted(.dateTime.weekday(.narrow)).uppercased())
                            .font(.system(size: 9.5, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(isSelected ? Palette.onInk.opacity(0.65) : Palette.inkFaint)

                        Text(day.date.formatted(.dateTime.day()))
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(
                                isSelected ? Palette.onInk
                                : (isFuture ? Palette.inkFaint : Palette.ink)
                            )

                        Circle()
                            .fill(day.activity > 0
                                  ? (isSelected ? Palette.onInk : day.accent.color)
                                  : .clear)
                            .frame(width: 4, height: 4)
                            .opacity(day.activity > 0 ? max(0.4, day.activity) : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isSelected {
                            RoundedRectangle.soft(16)
                                .fill(Palette.inkSolid)
                                .matchedGeometryEffect(id: "day", in: namespace)
                        }
                    }
                    .contentShape(RoundedRectangle.soft(16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}

// MARK: - Riel de filtros

/// Chips horizontales seleccionables. Se usa para filtrar recetas
/// (Rápidas · Veggie · Alto en proteína · Usa lo que vence).
struct FilterRail<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    var accent: (Item) -> Color = { _ in Palette.ink }
    @Binding var selection: Set<Item>

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.xs) {
                ForEach(items, id: \.self) { item in
                    let isOn = selection.contains(item)
                    Button {
                        Haptics.select()
                        withAnimation(Motion.morph) {
                            if isOn { selection.remove(item) } else { selection.insert(item) }
                        }
                    } label: {
                        Text(title(item))
                            .font(Typeface.action)
                            .foregroundStyle(isOn ? Palette.onInk : Palette.inkSoft)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8.5)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(isOn ? accent(item) : Palette.surface)
                            }
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(isOn ? .clear : Palette.hairline,
                                                  lineWidth: Stroke.hairline)
                            }
                    }
                    .buttonStyle(.pressableCard)
                    .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
                }
            }
            .padding(.horizontal, Space.screen)
        }
        .scrollIndicators(.hidden)
        .tightHorizontalRail()
    }
}

// MARK: - Check dibujado

/// Casilla de las listas. El tilde se DIBUJA (trim del trazo) en vez de aparecer:
/// es medio segundo de detalle que cambia por completo la percepción de calidad.
struct DrawnCheckbox: View {
    let isOn: Bool
    var accent: Color = Palette.basil
    var size: CGFloat = 24

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? accent : Palette.hairline, lineWidth: Stroke.regular)
                .background { Circle().fill(isOn ? accent.opacity(0.14) : .clear) }

            CheckStroke()
                .trim(from: 0, to: isOn ? 1 : 0)
                .stroke(accent, style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.72, height: size * 0.72)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: isOn)
        }
        .frame(width: size, height: size)
        .scaleEffect(isOn ? 1 : 0.94)
        .motion(Motion.tap, value: isOn)
    }
}

// MARK: - Valoración

/// Estrellas para la comunidad. Soporta medias estrellas y modo interactivo.
struct StarRating: View {
    var rating: Double
    var size: CGFloat = 12
    var accent: Color = Palette.turmeric
    /// Si se pasa, las estrellas se vuelven tocables.
    var onRate: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(1...5, id: \.self) { index in
                let filled = Double(index) <= rating.rounded(.down)
                let half = !filled && Double(index) - 0.5 <= rating

                Image(systemName: filled ? "star.fill" : (half ? "star.leadinghalf.filled" : "star"))
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(filled || half ? accent : Palette.hairline)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard let onRate else { return }
                        Haptics.tick()
                        onRate(index)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Valoración"))
        .accessibilityValue(String(format: "%.1f de 5", rating))
    }
}
