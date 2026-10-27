//
//  CookPlanEditorSheet.swift
//  FridgeWise
//
//  Editar una receta ya agendada: mover el día, cambiar la hora del aviso,
//  quitarlo, o sacar el plan del calendario.
//
//  Por qué existe: agendar algo es fácil de hacer y muy fácil de equivocar —
//  un día de más, una hora que no sirve— y hasta ahora el único arreglo era
//  borrar el plan y volver a buscar la receta entre todas. Cuatro pasos para
//  mover una cena un día. Los planes son lo único de esta app que el usuario
//  compromete a futuro; si corregirlos cuesta, deja de agendar.
//
//  Decisiones de la hoja:
//  · El calendario es el mismo `MonthCalendar` que usa "Agendar": la misma
//    pieza para la misma decisión, con los días ya ocupados marcados.
//  · Las horas sugeridas van primero y el reloj exacto detrás. Nueve de cada
//    diez veces el usuario quiere una de cuatro horas; hacerle girar una rueda
//    para elegir "20:00" es trabajo que le estamos pasando.
//  · "Quitar del calendario" vive abajo y en rojo, separada por un hairline:
//    es destructiva y no se toca por error al ir a guardar.
//

import SwiftUI

struct CookPlanEditorSheet: View {

    let plan: CookPlan

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var day: Date
    @State private var remindsAt: Date
    @State private var wantsReminder: Bool

    init(plan: CookPlan) {
        self.plan = plan
        _day = State(initialValue: plan.day)
        _remindsAt = State(initialValue: plan.remindsAt ?? CookPlan.defaultReminder(for: plan.day))
        _wantsReminder = State(initialValue: plan.remindsAt != nil)
    }

    /// Horas con nombre. El usuario piensa "en la cena", no "20:00".
    private static let suggestions: [(label: String, hour: Int, minute: Int)] = [
        (String(localized: "Mañana"), 9, 0),
        (String(localized: "Mediodía"), 13, 0),
        (String(localized: "Tarde"), 17, 30),
        (String(localized: "Cena"), 20, 0)
    ]

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    header
                    daySection
                    reminderSection
                }
                .padding(.top, Space.lg)
                .padding(.bottom, Space.xxl)
            }
            .scrollIndicators(.hidden)
            .lockedVerticalScroll()
            .safeAreaInset(edge: .bottom) { footer }
        }
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "Receta agendada")).eyebrow(Palette.basil)
                Text(plan.recipeTitle)
                    .font(Typeface.display(26))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Space.sm)

            Button {
                Haptics.select()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(Typeface.scaled(13, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 34, height: 34)
                    .liquidGlass(in: Circle(), role: .control, interactive: true, shadow: false)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Cerrar"))
        }
        .screenPadding()
    }

    // MARK: - Día

    private var daySection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: String(localized: "Día"), accent: Palette.basil) {
                Text(day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(Typeface.micro)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.basil)
                    .contentTransition(.opacity)
            }
            .screenPadding()

            SoftCard(padding: Space.md) {
                MonthCalendar(
                    selection: $day,
                    markedDays: app.plannedDays,
                    accent: Palette.basil,
                    allowsPast: false
                )
            }
            .screenPadding()
        }
        .motion(Motion.standard, value: day)
    }

    // MARK: - Recordatorio

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "Recordatorio"), accent: Palette.turmeric)
                .screenPadding()

            VStack(spacing: 0) {
                reminderToggle

                if wantsReminder {
                    Hairline(inset: Space.md)
                    timePicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, Space.xxs)
            .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
            .screenPadding()
        }
        .motion(Motion.standard, value: wantsReminder)
    }

    private var reminderToggle: some View {
        Button {
            Haptics.select()
            withAnimation(Motion.standard) { wantsReminder.toggle() }
        } label: {
            HStack(spacing: Space.sm) {
                DrawnCheckbox(isOn: wantsReminder, accent: Palette.turmeric)

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "Avísame ese día"))
                        .font(Typeface.body)
                        .foregroundStyle(Palette.ink)
                    Text(wantsReminder
                         ? remindsAt.formatted(.dateTime.hour().minute())
                         : String(localized: "Sin notificación"))
                        .font(Typeface.micro)
                        .foregroundStyle(wantsReminder ? Palette.turmeric : Palette.inkFaint)
                        .contentTransition(.opacity)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(wantsReminder ? [.isSelected, .isButton, .isToggle] : [.isButton, .isToggle])
    }

    private var timePicker: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            // Atajos en cristal: la hora que el usuario casi siempre quiere,
            // a un toque, antes de ofrecerle una rueda.
            GlassRail(spacing: Space.sm) {
                HStack(spacing: Space.xs) {
                    ForEach(Self.suggestions, id: \.label) { suggestion in
                        suggestionChip(suggestion)
                    }
                }
            }

            HStack {
                Text(String(localized: "Hora exacta")).eyebrow()
                Spacer()
                DatePicker("", selection: $remindsAt, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(Palette.turmeric)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 12)
    }

    private func suggestionChip(_ suggestion: (label: String, hour: Int, minute: Int)) -> some View {
        let isOn = isSelected(suggestion)

        return Button {
            Haptics.tick()
            withAnimation(Motion.morph) { apply(suggestion) }
        } label: {
            VStack(spacing: 1) {
                Text(suggestion.label)
                    .font(Typeface.micro)
                    .fontWeight(.semibold)
                Text(String(format: "%02d:%02d", suggestion.hour, suggestion.minute))
                    .font(Typeface.scaled(10.5, weight: .medium))
                    .monospacedDigit()
                    .opacity(0.75)
            }
            .foregroundStyle(isOn ? Palette.onAccent : Palette.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .modifier(SuggestionGlass(isOn: isOn))
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel("\(suggestion.label), \(String(format: "%02d:%02d", suggestion.hour, suggestion.minute))")
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }

    private func isSelected(_ suggestion: (label: String, hour: Int, minute: Int)) -> Bool {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: remindsAt)
        return parts.hour == suggestion.hour && parts.minute == suggestion.minute
    }

    private func apply(_ suggestion: (label: String, hour: Int, minute: Int)) {
        let calendar = Calendar.current
        guard let updated = calendar.date(bySettingHour: suggestion.hour,
                                          minute: suggestion.minute,
                                          second: 0,
                                          of: calendar.startOfDay(for: day))
        else { return }
        remindsAt = updated
    }

    // MARK: - Pie

    private var footer: some View {
        VStack(spacing: Space.sm) {
            Button(String(localized: "Guardar cambios")) {
                app.reschedulePlan(plan, to: day, remindAt: wantsReminder ? remindsAt : nil)
                dismiss()
            }
            .buttonStyle(InkButtonStyle(fill: Palette.basil, foreground: Palette.onAccent, fullWidth: true))
            .disabled(!hasChanges)
            .opacity(hasChanges ? 1 : 0.45)

            Hairline()

            Button(role: .destructive) {
                app.removePlan(plan)
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.minus")
                        .font(Typeface.scaled(11, weight: .semibold))
                    Text(String(localized: "Quitar del calendario"))
                }
                .font(Typeface.action)
                .foregroundStyle(Palette.tomato)
                .hitTarget(horizontal: 8, vertical: 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Space.screen)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.md)
        .background {
            Rectangle()
                .fill(Palette.canvas.opacity(0.94))
                .ignoresSafeArea()
        }
    }

    /// Guardar algo idéntico a lo que ya estaba reprogramaría la notificación
    /// por nada. El botón apagado también le dice al usuario que no cambió nada.
    private var hasChanges: Bool {
        let sameDay = Calendar.current.isDate(day, inSameDayAs: plan.day)
        let hadReminder = plan.remindsAt != nil
        guard sameDay, hadReminder == wantsReminder else { return true }
        guard wantsReminder, let original = plan.remindsAt else { return false }

        let parts = Calendar.current.dateComponents([.hour, .minute], from: remindsAt)
        let originalParts = Calendar.current.dateComponents([.hour, .minute], from: original)
        return parts != originalParts
    }
}

/// El atajo activo es cristal teñido; el resto, cristal neutro.
private struct SuggestionGlass: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content.liquidGlass(in: Capsule(style: .continuous),
                                tint: Palette.turmeric, interactive: true)
        } else {
            content.glassCapsule(role: .control, interactive: true, shadow: false)
        }
    }
}
