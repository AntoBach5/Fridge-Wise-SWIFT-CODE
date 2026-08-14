//
//  IngredientEditorSheet.swift
//  FridgeWise
//
//  Añadir o corregir un ingrediente a mano.
//
//  Por qué hace falta aunque haya escáner: el reconocimiento no ve la fecha de
//  caducidad ni sabe que quedan dos huevos y no ocho. Y toda la app —las recetas
//  sugeridas, los avisos de "usar pronto", la lista de la compra— se apoya en que
//  la despensa sea cierta. Sin una forma de corregirla, el primer error se
//  arrastra a todo lo demás.
//

import SwiftUI

struct IngredientEditorSheet: View {

    enum Target: Identifiable, Hashable {
        case new
        case existing(Ingredient)

        var id: String {
            switch self {
            case .new:                 "new"
            case .existing(let item):  item.id.uuidString
            }
        }
    }

    let target: Target

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var quantity = ""
    @State private var category: PantryCategory = .produce
    @State private var hasExpiry = true
    @State private var expiresAt = Calendar.current.date(byAdding: .day, value: 5, to: .now) ?? .now
    @State private var showsDeleteConfirmation = false

    @FocusState private var focus: Field?
    private enum Field: Hashable { case name, quantity }

    private var isEditing: Bool {
        if case .existing = target { return true }
        return false
    }

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    header
                    nameSection
                    categorySection
                    expirySection
                    if isEditing { deleteButton }
                }
                .screenPadding()
                .padding(.top, Space.lg)
                .padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)
            .dismissKeyboardOnDrag()
            .safeAreaInset(edge: .bottom) { footer }
        }
        .task { load() }
        .confirmationDialog(
            String(localized: "¿Quitar «\(name)» de la despensa?"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Quitar"), role: .destructive) {
                if case .existing(let item) = target {
                    app.removeIngredient(item)
                }
                dismiss()
            }
            Button(String(localized: "Cancelar"), role: .cancel) {}
        }
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isEditing
                     ? String(localized: "Corregir")
                     : String(localized: "Añadir"))
                    .displayStyle(30)
                Text(String(localized: "un producto"))
                    .font(Typeface.displayItalic(30))
                    .foregroundStyle(Palette.ink)
                    .squiggleUnderline(category.accent.color)
                    .padding(.bottom, Space.xxs)
            }

            Spacer()

            Button {
                Haptics.select()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 34, height: 34)
                    .background { Circle().fill(Palette.surface) }
                    .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "Cerrar"))
        }
    }

    // MARK: - Nombre y cantidad

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "Qué es"))

            TextField(String(localized: "Nombre del producto"), text: $name)
                .font(Typeface.body)
                .foregroundStyle(Palette.ink)
                .focused($focus, equals: .name)
                .padding(.horizontal, Space.md)
                .padding(.vertical, 12)
                .background { RoundedRectangle.soft(Radius.md).fill(Palette.surface) }
                .overlay {
                    RoundedRectangle.soft(Radius.md)
                        .strokeBorder(focus == .name ? category.accent.color.opacity(0.45) : Palette.hairline,
                                      lineWidth: Stroke.hairline)
                }

            TextField(String(localized: "Cantidad — «500 g», «2 unidades»"), text: $quantity)
                .font(Typeface.body)
                .foregroundStyle(Palette.ink)
                .focused($focus, equals: .quantity)
                .padding(.horizontal, Space.md)
                .padding(.vertical, 12)
                .background { RoundedRectangle.soft(Radius.md).fill(Palette.surface) }
                .overlay {
                    RoundedRectangle.soft(Radius.md)
                        .strokeBorder(focus == .quantity ? category.accent.color.opacity(0.45) : Palette.hairline,
                                      lineWidth: Stroke.hairline)
                }
        }
        .motion(Motion.standard, value: focus)
    }

    // MARK: - Categoría

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "Dónde va"))

            FlowLayout(spacing: Space.xs) {
                ForEach(PantryCategory.allCases) { option in
                    let isOn = category == option
                    Button {
                        Haptics.select()
                        withAnimation(Motion.morph) { category = option }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(option.title)
                                .font(Typeface.micro)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(isOn ? Palette.onInk : Palette.inkSoft)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8.5)
                        .background { Capsule().fill(isOn ? option.accent.color : Palette.surface) }
                        .overlay {
                            Capsule().strokeBorder(isOn ? .clear : Palette.hairline,
                                                   lineWidth: Stroke.hairline)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
    }

    // MARK: - Caducidad

    private var expirySection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: String(localized: "Caduca")) {
                Button {
                    Haptics.select()
                    withAnimation(Motion.standard) { hasExpiry.toggle() }
                } label: {
                    Text(hasExpiry
                         ? String(localized: "Sin fecha")
                         : String(localized: "Poner fecha"))
                        .font(Typeface.micro)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if hasExpiry {
                VStack(alignment: .leading, spacing: Space.sm) {
                    quickDates

                    SoftCard(padding: Space.md) {
                        MonthCalendar(
                            selection: $expiresAt,
                            accent: Palette.turmeric
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text(String(localized: "Sin fecha no aparecerá en «Usar pronto» ni en los avisos."))
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.inkFaint)
            }
        }
    }

    /// Atajos para lo que se usa el 90% de las veces. Abrir un calendario para
    /// decir "caduca en tres días" es trabajo de más.
    private var quickDates: some View {
        HStack(spacing: Space.xs) {
            ForEach([2, 5, 10, 30], id: \.self) { days in
                let date = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
                let isOn = Calendar.current.isDate(expiresAt, inSameDayAs: date)

                Button {
                    Haptics.select()
                    withAnimation(Motion.morph) { expiresAt = date }
                } label: {
                    Text(String(localized: "\(days) días"))
                        .font(Typeface.micro)
                        .fontWeight(.semibold)
                        .foregroundStyle(isOn ? Palette.onInk : Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background { Capsule().fill(isOn ? Palette.inkSolid : Palette.surface) }
                        .overlay {
                            Capsule().strokeBorder(isOn ? .clear : Palette.hairline,
                                                   lineWidth: Stroke.hairline)
                        }
                }
                .buttonStyle(.pressableCard)
                .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    // MARK: - Acciones

    private var deleteButton: some View {
        Button {
            Haptics.select()
            showsDeleteConfirmation = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                Text(String(localized: "Quitar de la despensa"))
                    .font(Typeface.action)
            }
            .foregroundStyle(Palette.tomato)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background { Capsule().fill(Palette.tomato.opacity(0.09)) }
        }
        .buttonStyle(.pressableCard)
    }

    private var footer: some View {
        VStack(spacing: Space.xs) {
            Button(isEditing
                   ? String(localized: "Guardar cambios")
                   : String(localized: "Añadir a la despensa")) {
                save()
            }
            .buttonStyle(InkButtonStyle(fullWidth: true))
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if hasExpiry {
                Text(previewLabel)
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        .padding(.horizontal, Space.screen)
        .padding(.vertical, Space.md)
        .background {
            Rectangle().fill(Palette.canvas)
                .mask { LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .bottom) }
                .ignoresSafeArea()
        }
    }

    private var previewLabel: String {
        let days = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: expiresAt)
        ).day ?? 0

        return switch days {
        case ..<0: String(localized: "Esa fecha ya pasó")
        case 0:    String(localized: "Caduca hoy")
        case 1:    String(localized: "Caduca mañana")
        default:   String(localized: "Caduca en \(days) días")
        }
    }

    // MARK: - Carga y guardado

    private func load() {
        guard case .existing(let item) = target else {
            focus = .name
            return
        }
        name = item.name
        quantity = item.quantity ?? ""
        category = item.category
        if let expiry = item.expiresAt {
            expiresAt = expiry
            hasExpiry = true
        } else {
            hasExpiry = false
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedQuantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)

        var ingredient: Ingredient
        if case .existing(let item) = target {
            ingredient = item
        } else {
            ingredient = Ingredient(name: trimmedName, category: category)
        }

        ingredient.name = trimmedName
        ingredient.category = category
        ingredient.quantity = trimmedQuantity.isEmpty ? nil : trimmedQuantity
        ingredient.expiresAt = hasExpiry ? Calendar.current.startOfDay(for: expiresAt) : nil
        // Cargado o corregido a mano: ya no es una detección con confianza.
        ingredient.confidence = nil
        ingredient.isConfirmed = true

        app.upsertIngredient(ingredient)
        dismiss()
    }
}
