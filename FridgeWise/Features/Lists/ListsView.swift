//
//  ListsView.swift
//  FridgeWise
//
//  Sistema dual "To Buy" / "To Cook".
//
//  Lo que hace que sean un sistema y no dos blocs de notas:
//  · Cada fila que vino de una receta muestra su origen y vuelve a ella.
//  · Tildar algo en To Buy lo mete en la despensa automáticamente.
//  · Agendar una receta en To Cook empuja sus faltantes a To Buy.
//
//  Cero `List` nativo: filas propias con swipe custom, para poder controlar
//  el fondo, los separadores y la física del gesto.
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
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                header
                segments
                composer

                let groups = groupedItems
                if groups.isEmpty {
                    emptyState
                } else {
                    ForEach(groups, id: \.title) { group in
                        section(group)
                    }
                }

                completedSection
            }
            .padding(.top, Space.xs)
            .padding(.bottom, Space.tabBarInset)
            .readsScrollDirection(into: $isTabBarDimmed)
        }
        .coordinateSpace(name: "scroll")
        .scrollIndicators(.hidden)
        .editorialScrollFeel()
        .dismissKeyboardOnDrag()
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

            if !completedItems.isEmpty {
                Menu {
                    Button(role: .destructive) {
                        app.clearCompleted(in: kind)
                    } label: {
                        Label(String(localized: "Borrar completados"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 34, height: 34)
                        .background { Circle().fill(Palette.surface) }
                        .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(String(localized: "Más opciones"))
            }
        }
        .screenPadding()
    }

    private var segments: some View {
        MorphingSegments(
            items: ListKind.allCases,
            title: \.title,
            badge: { app.pendingCount(in: $0) },
            selection: $kind
        )
        .screenPadding()
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isComposing ? kind.accent.color : Palette.inkFaint)

            TextField(
                kind == .toBuy
                    ? String(localized: "Agregar a la compra")
                    : String(localized: "Agregar algo para cocinar"),
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
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.onInk)
                        .frame(width: 28, height: 28)
                        .background { Circle().fill(kind.accent.color) }
                }
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(String(localized: "Agregar"))
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 12)
        .background { Capsule().fill(Palette.surface) }
        .overlay {
            Capsule().strokeBorder(
                isComposing ? kind.accent.color.opacity(0.4) : Palette.hairline,
                lineWidth: Stroke.hairline
            )
        }
        .motion(Motion.standard, value: isComposing)
        .motion(Motion.tap, value: newItem.isEmpty)
        .screenPadding()
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
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: 7) {
                AccentDot(color: group.accent.color, size: 7)
                Text(group.title).eyebrow()
                Spacer()
                Text("\(group.items.count)")
                    .font(Typeface.micro)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkFaint)
            }
            .screenPadding()

            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    SwipeableRow(
                        onDelete: { app.deleteItem(item) }
                    ) {
                        itemRow(item)
                    }
                    if index < group.items.count - 1 {
                        Hairline(inset: 46)
                    }
                }
            }
            .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
            .clipShape(RoundedRectangle.soft(Radius.card))
            .screenPadding()
        }
    }

    private func itemRow(_ item: ListItem) -> some View {
        HStack(spacing: Space.sm) {
            Button {
                app.toggleItem(item)
            } label: {
                DrawnCheckbox(isOn: item.isDone, accent: item.accent.color)
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
                                .font(.system(size: 7.5, weight: .bold))
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.inkFaint)
                        .frame(width: 30, height: 30)
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
            VStack(alignment: .leading, spacing: Space.xs) {
                Button {
                    Haptics.select()
                    withAnimation(Motion.standard) { showsCompleted.toggle() }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(showsCompleted ? 90 : 0))
                        Text(String(localized: "Completados")).eyebrow()
                        Spacer()
                        Text("\(completedItems.count)")
                            .font(Typeface.micro)
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .foregroundStyle(Palette.inkFaint)
                }
                .buttonStyle(.plain)
                .screenPadding()

                if showsCompleted {
                    VStack(spacing: 0) {
                        ForEach(Array(completedItems.enumerated()), id: \.element.id) { index, item in
                            SwipeableRow(onDelete: { app.deleteItem(item) }) {
                                itemRow(item)
                            }
                            if index < completedItems.count - 1 {
                                Hairline(inset: 46)
                            }
                        }
                    }
                    .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface.opacity(0.6)) }
                    .clipShape(RoundedRectangle.soft(Radius.card))
                    .screenPadding()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
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

// MARK: - Fila con swipe

/// Swipe para borrar hecho a mano. Se resiste el arrastre pasado el umbral
/// (`rubber banding`) y se completa solo si el gesto pasa la mitad del ancho —
/// la misma física que usa Mail, sin el chrome de `List`.
struct SwipeableRow<Content: View>: View {

    var onDelete: () -> Void
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    @State private var isCommitting = false

    private let actionWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            // Acción revelada.
            HStack {
                Spacer()
                Button {
                    commit()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.onInk)
                        .frame(width: actionWidth)
                        .frame(maxHeight: .infinity)
                        .background(Palette.tomato)
                }
                .accessibilityLabel(String(localized: "Borrar"))
            }

            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            guard value.translation.width < 0 else {
                                offset = min(0, value.translation.width * 0.2)
                                return
                            }
                            let raw = value.translation.width
                            // Resistencia pasado el ancho de la acción.
                            offset = raw < -actionWidth
                                ? -actionWidth + (raw + actionWidth) * 0.28
                                : raw
                        }
                        .onEnded { value in
                            let shouldDelete = value.translation.width < -actionWidth * 2.2
                            if shouldDelete {
                                commit()
                            } else if value.translation.width < -actionWidth * 0.5 {
                                Haptics.select()
                                withAnimation(Motion.standard) { offset = -actionWidth }
                            } else {
                                withAnimation(Motion.standard) { offset = 0 }
                            }
                        }
                )
        }
        .clipped()
        .opacity(isCommitting ? 0 : 1)
    }

    private func commit() {
        guard !isCommitting else { return }
        isCommitting = true
        Haptics.commit()
        withAnimation(Motion.standard) { offset = -600 }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            onDelete()
        }
    }
}
