//
//  RecipePickerSheet.swift
//  FridgeWise
//
//  Elegir una receta para agendarla en un día concreto.
//
//  El orden no es alfabético ni cronológico: primero lo guardado, luego lo visto
//  hace poco, y al final el resto. Quien agenda algo casi siempre agenda algo que
//  ya había marcado; hacerle buscar entre cincuenta recetas para encontrarlo sería
//  ordenar por comodidad nuestra.
//

import SwiftUI

struct RecipePickerSheet: View {

    let day: Date
    var onPick: (Recipe) -> Void

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @FocusState private var isSearching: Bool

    var body: some View {
        ZStack {
            CanvasBackground()

            VStack(alignment: .leading, spacing: Space.md) {
                header
                searchField

                if groups.allSatisfy(\.recipes.isEmpty) {
                    EmptyStateView(
                        headline: String(localized: "Nada que agendar"),
                        emphasis: String(localized: "todavía"),
                        message: String(localized: "Genera o guarda alguna receta y podrás planificarla desde aquí."),
                        systemImage: "calendar",
                        accent: Palette.basil,
                        palette: .pantry
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.lg) {
                            ForEach(groups, id: \.title) { group in
                                if !group.recipes.isEmpty {
                                    section(group)
                                }
                            }
                        }
                        .padding(.bottom, Space.xxl)
                    }
                    .scrollIndicators(.hidden)
                    .dismissKeyboardOnDrag()
                }
            }
            .screenPadding()
            .padding(.top, Space.lg)
        }
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Agendar para")).eyebrow(Palette.basil)
                Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(Typeface.display(24))
                    .foregroundStyle(Palette.ink)
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

    private var searchField: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSearching ? Palette.basil : Palette.inkFaint)

            TextField(String(localized: "Buscar entre tus recetas"), text: $query)
                .font(Typeface.body)
                .foregroundStyle(Palette.ink)
                .focused($isSearching)
                .submitLabel(.done)

            if !query.isEmpty {
                Button {
                    Haptics.tick()
                    withAnimation(Motion.tap) { query = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.inkFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Borrar búsqueda"))
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 12)
        .background { Capsule().fill(Palette.surface) }
        .overlay {
            Capsule().strokeBorder(isSearching ? Palette.basil.opacity(0.4) : Palette.hairline,
                                   lineWidth: Stroke.hairline)
        }
        .motion(Motion.standard, value: isSearching)
    }

    // MARK: - Secciones

    /// No se llama `Group` a propósito: chocaría con el contenedor de SwiftUI.
    private struct PickerGroup {
        var title: String
        var accent: Color
        var recipes: [Recipe]
    }

    private var groups: [PickerGroup] {
        let saved = app.savedRecipes
        let savedIDs = Set(saved.map(\.id))

        let recent = app.recentlyViewed.filter { !savedIDs.contains($0.id) }
        let recentIDs = Set(recent.map(\.id))

        let rest = (app.lastGeneration + app.feed)
            .filter { !savedIDs.contains($0.id) && !recentIDs.contains($0.id) }
            .reduce(into: [Recipe]()) { unique, recipe in
                if !unique.contains(where: { $0.id == recipe.id }) { unique.append(recipe) }
            }

        return [
            PickerGroup(title: String(localized: "Guardadas"), accent: Palette.clay, recipes: filter(saved)),
            PickerGroup(title: String(localized: "Vistas hace poco"), accent: Palette.mist, recipes: filter(recent)),
            PickerGroup(title: String(localized: "Todas"), accent: Palette.sage, recipes: filter(rest))
        ]
    }

    private func filter(_ recipes: [Recipe]) -> [Recipe] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return recipes }

        let needle = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                     locale: .current)
        return recipes.filter { recipe in
            let haystack = "\(recipe.title) \(recipe.subtitle)"
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return haystack.contains(needle)
        }
    }

    private func section(_ group: PickerGroup) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: 7) {
                AccentDot(color: group.accent, size: 7)
                Text(group.title).eyebrow()
                Spacer()
                Text("\(group.recipes.count)")
                    .font(Typeface.micro)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkFaint)
            }

            VStack(spacing: 0) {
                ForEach(Array(group.recipes.enumerated()), id: \.element.id) { index, recipe in
                    Button {
                        Haptics.commit()
                        onPick(recipe)
                        dismiss()
                    } label: {
                        HStack(spacing: 0) {
                            RecipeRow(recipe: recipe)
                            Image(systemName: "plus.circle")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Palette.basil)
                                .padding(.trailing, Space.md)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressableCard)

                    if index < group.recipes.count - 1 {
                        Hairline(inset: Space.md + 56 + Space.sm)
                    }
                }
            }
            .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
            .clipShape(RoundedRectangle.soft(Radius.card))
        }
    }
}
