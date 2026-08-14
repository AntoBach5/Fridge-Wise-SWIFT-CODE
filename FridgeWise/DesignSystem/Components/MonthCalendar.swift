//
//  MonthCalendar.swift
//  FridgeWise
//
//  Calendario mensual propio.
//
//  Se escribe a mano en vez de usar `DatePicker(.graphical)` por lo de siempre:
//  el nativo trae su tipografía, su azul y sus esquinas, y aquí hace falta poder
//  marcar días con puntos de color (lo agendado, lo que caduca) manteniendo la
//  retícula editorial del resto de la app.
//
//  Se usa en dos sitios con la misma pieza: elegir día para agendar una receta,
//  y elegir fecha de caducidad de un ingrediente.
//

import SwiftUI

struct MonthCalendar: View {

    @Binding var selection: Date

    /// Días que llevan un punto debajo del número.
    var markedDays: Set<Date> = []
    var accent: Color = Palette.sage
    /// `false` apaga los días anteriores a hoy: agendar para ayer no existe.
    var allowsPast: Bool = true

    @State private var anchor: Date = Calendar.current.startOfDay(for: .now)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: Space.sm) {
            monthHeader
            weekdayRow
            grid
        }
        .onAppear { anchor = startOfMonth(for: selection) }
    }

    // MARK: - Cabecera

    private var monthHeader: some View {
        HStack {
            arrow("chevron.left", label: String(localized: "Mes anterior")) {
                shiftMonth(by: -1)
            }
            .disabled(!allowsPast && isCurrentMonth)

            Spacer()

            Text(anchor.formatted(.dateTime.month(.wide).year()))
                .font(Typeface.cardTitle)
                .foregroundStyle(Palette.ink)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: anchor)

            Spacer()

            arrow("chevron.right", label: String(localized: "Mes siguiente")) {
                shiftMonth(by: 1)
            }
        }
    }

    private func arrow(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tick()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .frame(width: 34, height: 34)
                .background { Circle().fill(Palette.surface) }
                .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var weekdayRow: some View {
        HStack(spacing: 2) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .eyebrow()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Retícula

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 42)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(day)
        let isDisabled = !allowsPast && day < calendar.startOfDay(for: .now)
        let isMarked = markedDays.contains(calendar.startOfDay(for: day))

        return Button {
            Haptics.select()
            withAnimation(reduceMotion ? nil : Motion.morph) { selection = day }
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(dayColor(isSelected: isSelected, isDisabled: isDisabled))

                Circle()
                    .fill(isMarked ? (isSelected ? Palette.onInk : accent) : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background {
                if isSelected {
                    Circle()
                        .fill(Palette.inkSolid)
                        .frame(width: 38, height: 38)
                } else if isToday {
                    Circle()
                        .strokeBorder(Palette.inkFaint.opacity(0.45), lineWidth: Stroke.hairline)
                        .frame(width: 38, height: 38)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(isMarked ? String(localized: "Con planes") : "")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private func dayColor(isSelected: Bool, isDisabled: Bool) -> Color {
        if isSelected { return Palette.onInk }
        if isDisabled { return Palette.inkFaint.opacity(0.4) }
        return Palette.ink
    }

    // MARK: - Cálculo

    private var isCurrentMonth: Bool {
        calendar.isDate(anchor, equalTo: .now, toGranularity: .month)
    }

    /// Símbolos de día empezando por el primer día de la semana según la región
    /// del usuario: en España empieza el lunes, en EE. UU. el domingo.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func startOfMonth(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? calendar.startOfDay(for: date)
    }

    /// Los `nil` iniciales son los huecos hasta que arranca el mes.
    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: anchor) else { return [] }

        let weekdayOfFirst = calendar.component(.weekday, from: anchor)
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        let days: [Date?] = range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: anchor)
        }
        return Array(repeating: nil, count: leading) + days
    }

    private func shiftMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: anchor) else { return }
        withAnimation(reduceMotion ? nil : Motion.standard) { anchor = next }
    }
}
