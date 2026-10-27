//
//  ListsView.swift
//  FridgeWise
//
//  Sistema dual "To Buy" / "To Cook".
//
//  Lo que hace que sean un sistema y no dos blocs de notas:
//  · Cada fila que vino de una receta muestra su origen y vuelve a ella.
//  · Marcar algo en To Buy lo mete en la despensa automáticamente.
//  · Planificar una receta en To Cook empuja sus faltantes a To Buy.
//
//  Es una `List` del sistema (insetGrouped) con el fondo y las filas
//  teñidos con la paleta: el deslizar-para-borrar es `swipeActions`, con la
//  física, la accesibilidad y el borrado completo que ya conoce la persona.
//

import SwiftUI

struct ListsView: View {

    @Environment(\.app) private var app
    @Binding var isTabBarDimmed: Bool

    @State private var kind: ListKind = .toBuy
    @State private var newItem = ""
    @State private var showsCompleted = false
    @FocusState private var isComposing: Bool

    var body: some View {
        List {
            header
                .freeFormListRow(horizontal: 2, top: Space.xs, bottom: Space.md)
            segments
                .freeFormListRow(horizontal: 2, bottom: Space.md)
            composer
                .freeFormListRow(horizontal: 2, bottom: Space.xs)

            let groups = groupedItems
            if groups.isEmpty {
                emptyState
                    .freeFormListRow(horizontal: 2)
            } else {
                ForEach(groups, id: \.title) { group in
                    section(group)
                }
            }

            completedSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listSectionSpacing(Space.md)
        .contentMargins(.bottom, Space.tabBarInset, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDismissesKeyboard(.interactively)
        .readsListScrollDirection(into: $isTabBarDimmed)
        .canvasBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Tus")).displayStyle(31)
                Text(String(localized: "listas"))
                    .font(Typeface.displayItalic(31))
                    .foregroundStyle(Palette.ink)
                    .squiggleUnderline(kind.accent.color)
                    .padding(.bottom, Space.xxs)
            }

            Spacer()

            // El botón está siempre: aparecía y desaparecía según hubiera o no
            // completados, y eso hacía que se esfumara justo al usarlo. Un
            // control que se mueve bajo el dedo se siente roto aunque no lo esté.
            Menu {
                Button(role: .destructive) {
                    app.clearCompleted(in: kind)
                } label: {
                    Label(String(localized: "Borrar completados"), systemImage: "trash")
                }
                .disabled(completedItems.isEmpty)

                Button {
                    Haptics.select()
                    withAnimation(Motion.standard) { showsCompleted.toggle() }
                } label: {
                    Label(showsCompleted
                          ? String(localized: "Ocultar completados")
                          : String(localized: "Ver completados"),
                          systemImage: showsCompleted ? "eye.slash" : "eye")
                }
                .disabled(completedItems.isEmpty)
            } label: {
                Image(systemName: "ellipsis")
                    .font(Typeface.scaled(14, weight: .semibold))
                    .foregroundStyle(completedItems.isEmpty ? Palette.inkFaint : Palette.ink)
                    .frame(width: 34, height: 34)
                    .background { Circle().fill(Palette.surface) }
                    .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "Más opciones"))
        }
    }

    private var segments: some View {
        MorphingSegments(
            items: ListKind.allCases,
            title: \.title,
            badge: { app.pendingCount(in: $0) },
            selection: $kind
        )
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "plus")
                .font(Typeface.scaled(13, weight: .semibold))
                .foregroundStyle(isComposing ? kind.accent.color : Palette.inkFaint)

            TextField(
                kind == .toBuy
                    ? String(localized: "Añadir a la compra")
                    : String(localized: "Añadir algo para cocinar"),
                text: $newItem
            )
            .font(Typeface.body)
            .foregroundStyle(Palette.ink)
            .focused($isComposing)
            .submitLabel(.done)
            .onSubmit(addItem)

            if !newItem.isEmpty {
                Button {
                    addItem()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(Typeface.scaled(12, weight: .bold))
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 28, height: 28)
                        .background { Circle().fill(kind.accent.color) }
                        .hitTarget(size: 28)
                }
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(String(localized: "Añadir"))
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 12)
        .glassCapsule(role: .control, interactive: true, shadow: false)
        .overlay {
            // El foco se marca con el acento de la lista activa, encima del
            // cristal: el cristal da la superficie, el borde da el estado.
            Capsule().strokeBorder(
                isComposing ? kind.accent.color.opacity(0.55) : .clear,
                lineWidth: Stroke.regular
            )
        }
        .motion(Motion.standard, value: isComposing)
        .motion(Motion.tap, value: newItem.isEmpty)
    }

    private func addItem() {
        app.addManualItem(newItem, to: kind)
        newItem = ""
    }

    // MARK: - Secciones

    private var pendingItems: [ListItem] {
        app.items(in: kind).filter { !$0.isDone }
    }

    private var completedItems: [ListItem] {
        app.items(in: kind).filter(\.isDone)
    }

    private var groupedItems: [(title: String, accent: AccentFamily, items: [ListItem])] {
        kind == .toBuy
            ? ListGrouping.groupToBuy(app.items(in: kind))
            : ListGrouping.groupToCook(app.items(in: kind))
    }

    private func section(_ group: (title: String, accent: AccentFamily, items: [ListItem])) -> some View {
        Section {
            ForEach(group.items, id: \.id) { item in
                itemListRow(item)
            }
        } header: {
            HStack(spacing: 7) {
                AccentDot(color: group.accent.color, size: 7)
                Text(group.title).eyebrow()
                Spacer()
                Text("\(group.items.count)")
                    .font(Typeface.micro)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkFaint)
            }
            .textCase(nil)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }

    /// Fila de la lista con las acciones de deslizar del sistema.
    private func itemListRow(_ item: ListItem) -> some View {
        itemRow(item)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Palette.surface)
            .listRowSeparatorTint(Palette.hairline)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 46 }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    app.deleteItem(item)
                } label: {
                    Label(String(localized: "Borrar"), systemImage: "trash")
                }
                .tint(Palette.tomato)
            }
    }

    private func itemRow(_ item: ListItem) -> some View {
        HStack(spacing: Space.sm) {
            Button {
                app.toggleItem(item)
            } label: {
                DrawnCheckbox(isOn: item.isDone, accent: item.accent.color)
                    .hitTarget(size: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone
                ? String(localized: "Desmarcar \(item.title)")
                : String(localized: "Marcar \(item.title)"))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(Typeface.body)
                    .foregroundStyle(item.isDone ? Palette.inkFaint : Palette.ink)
                    .strikethrough(item.isDone, color: Palette.inkFaint)

                HStack(spacing: 6) {
                    if let detail = item.detail {
                        Text(detail)
                            .font(Typeface.micro)
                            .foregroundStyle(Palette.inkFaint)
                    }

                    // Backlink a la receta de origen: es lo que integra las listas
                    // con el resto de la app en vez de dejarlas como un anexo.
                    if let recipeTitle = item.recipeTitle {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.turn.up.right")
                                .font(Typeface.scaled(7.5, weight: .bold))
                            Text(recipeTitle)
                                .lineLimit(1)
                        }
                        .font(Typeface.micro)
                        .foregroundStyle(item.accent.color)
                    }
                }
            }

            Spacer(minLength: 0)

            if item.kind == .toCook, let recipeID = item.recipeID {
                NavigationLink(value: Route.recipeDetail(recipeID)) {
                    Image(systemName: "chevron.right")
                        .font(Typeface.scaled(11, weight: .semibold))
                        .foregroundStyle(Palette.inkFaint)
                        .frame(width: 30, height: 30)
                        .hitTarget(size: 30)
                }
                .accessibilityLabel(String(localized: "Abrir receta"))
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 12)
        .background(Palette.surface)
        .contentShape(Rectangle())
    }

    // MARK: - Completados

    @ViewBuilder
    private var completedSection: some View {
        if !completedItems.isEmpty {
            Section {
                if showsCompleted {
                    ForEach(completedItems, id: \.id) { item in
                        itemListRow(item)
                    }
                }
            } header: {
                Button {
                    Haptics.select()
                    withAnimation(Motion.standard) { showsCompleted.toggle() }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "chevron.right")
                            .font(Typeface.scaled(9, weight: .bold))
                            .rotationEffect(.degrees(showsCompleted ? 90 : 0))
                        Text(String(localized: "Completados")).eyebrow()
                        Spacer()
                        Text("\(completedItems.count)")
                            .font(Typeface.micro)
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .foregroundStyle(Palette.inkFaint)
                    .hitTarget(vertical: 12)
                }
                .buttonStyle(.plain)
                .textCase(nil)
                .accessibilityValue(showsCompleted
                    ? String(localized: "Desplegado")
                    : String(localized: "Plegado"))
            }
        }
    }

    // MARK: - Vacío

    private var emptyState: some View {
        EmptyStateView(
            headline: kind.emptyHeadline,
            emphasis: kind.emptyEmphasis,
            message: kind.emptyMessage,
            systemImage: kind.icon,
            accent: kind.accent.color,
            palette: .pantry,
            actionTitle: kind == .toCook ? String(localized: "Buscar recetas") : nil,
            action: kind == .toCook ? { isComposing = true } : nil
        )
    }
}
