//
//  ScanReviewSheet.swift
//  FridgeWise
//
//  Confirmación de lo detectado antes de que entre a la despensa.
//
//  Por qué existe este paso en vez de guardar directo: ningún reconocimiento
//  es perfecto, y una despensa con datos mal cargados envenena todas las recetas
//  que vengan después. El paso de revisión convierte el error del modelo en una
//  corrección de dos toques, y de paso le da al usuario la sensación de control
//  sobre lo que la app "cree" que tiene.
//
//  Lo dudoso (< 75% de confianza) sube arriba de todo y se marca en ámbar.
//

import SwiftUI

struct ScanReviewSheet: View {

    @Binding var detected: [Ingredient]
    var onConfirm: ([Ingredient]) -> Void
    var onRetake: () -> Void

    @Environment(\.app) private var app
    @State private var rejected: Set<Ingredient.ID> = []
    @State private var newItemName = ""
    @FocusState private var isAddingFocused: Bool

    private var kept: [Ingredient] {
        detected.filter { !rejected.contains($0.id) }
    }

    private var uncertain: [Ingredient] {
        kept.filter(\.needsReview)
    }

    private var confident: [Ingredient] {
        kept.filter { !$0.needsReview }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                header

                if !uncertain.isEmpty {
                    uncertainSection
                }

                confidentSection
                addManually
            }
            .padding(.top, Space.md)
            .padding(.bottom, 140)
        }
        .scrollIndicators(.hidden)
        .dismissKeyboardOnDrag()
        .canvasBackground()
        .safeAreaInset(edge: .bottom) { footer }
    }

    // MARK: - Encabezado

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(String(localized: "Encontramos esto")).eyebrow(Palette.sage)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(kept.count)")
                    .font(Typeface.display(38))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText(value: Double(kept.count)))
                Text(String(localized: "ingredientes"))
                    .font(Typeface.displayItalic(30))
                    .foregroundStyle(Palette.ink)
                    .squiggleUnderline(Palette.sage, delay: 0.15)
            }

            Text(String(localized: "Sacá lo que no corresponda. Lo que confirmes se suma a tu despensa."))
                .bodyStyle()
                .padding(.top, Space.xxs)
        }
        .screenPadding()
    }

    // MARK: - Dudosos

    private var uncertainSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: String(localized: "¿Está bien esto?"), accent: Palette.turmeric) {
                Text("\(uncertain.count)")
                    .font(Typeface.percentage)
                    .foregroundStyle(Palette.turmeric)
            }
            .screenPadding()

            VStack(spacing: Space.xs) {
                ForEach(uncertain) { item in
                    uncertainRow(item)
                }
            }
            .screenPadding()
        }
    }

    private func uncertainRow(_ item: Ingredient) -> some View {
        SoftCard(padding: Space.sm, radius: Radius.md, tint: Palette.turmeric) {
            HStack(spacing: Space.sm) {
                ZStack {
                    Circle().fill(Palette.turmeric.opacity(0.16))
                    Image(systemName: item.category.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.turmeric)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(Typeface.headline)
                        .foregroundStyle(Palette.ink)
                    Text(String(localized: "\(Int((item.confidence ?? 0) * 100))% de confianza"))
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.turmeric)
                }

                Spacer(minLength: Space.xs)

                HStack(spacing: 6) {
                    Button {
                        Haptics.tick()
                        withAnimation(Motion.standard) { rejected.insert(item.id) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(width: 32, height: 32)
                            .background { Circle().fill(Palette.canvasSunken) }
                    }
                    .accessibilityLabel(String(localized: "Quitar \(item.name)"))

                    Button {
                        Haptics.tick()
                        withAnimation(Motion.standard) { confirm(item) }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.onInk)
                            .frame(width: 32, height: 32)
                            .background { Circle().fill(Palette.basil) }
                    }
                    .accessibilityLabel(String(localized: "Confirmar \(item.name)"))
                }
            }
        }
    }

    private func confirm(_ item: Ingredient) {
        guard let index = detected.firstIndex(where: { $0.id == item.id }) else { return }
        detected[index].confidence = 1
        detected[index].isConfirmed = true
    }

    // MARK: - Confirmados

    private var confidentSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "En tu despensa"))
                .screenPadding()

            ForEach(groupedConfident, id: \.category) { group in
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: 6) {
                        AccentDot(color: group.category.accent.color, size: 7)
                        Text(group.category.title)
                            .font(Typeface.caption)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .screenPadding()

                    FlowChips(items: group.items) { item in
                        ingredientChip(item)
                    }
                    .screenPadding()
                }
            }
        }
    }

    private var groupedConfident: [(category: PantryCategory, items: [Ingredient])] {
        Dictionary(grouping: confident, by: \.category)
            .map { (category: $0.key, items: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.category.rawValue < $1.category.rawValue }
    }

    private func ingredientChip(_ item: Ingredient) -> some View {
        HStack(spacing: 6) {
            Text(item.name)
                .font(Typeface.action)
                .foregroundStyle(Palette.ink)

            Button {
                Haptics.tick()
                withAnimation(Motion.standard) { rejected.insert(item.id) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.inkFaint)
            }
            .accessibilityLabel(String(localized: "Quitar \(item.name)"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background { Capsule().fill(Palette.surface) }
        .overlay {
            Capsule().strokeBorder(item.category.accent.color.opacity(0.3), lineWidth: Stroke.hairline)
        }
    }

    // MARK: - Agregar a mano

    private var addManually: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "¿Falta algo?"))
                .screenPadding()

            HStack(spacing: Space.xs) {
                TextField(String(localized: "Agregar ingrediente"), text: $newItemName)
                    .font(Typeface.body)
                    .foregroundStyle(Palette.ink)
                    .focused($isAddingFocused)
                    .submitLabel(.done)
                    .onSubmit(addManualIngredient)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, 12)
                    .background { Capsule().fill(Palette.surface) }
                    .overlay { Capsule().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }

                Button {
                    addManualIngredient()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.onInk)
                        .frame(width: 44, height: 44)
                        .background { Circle().fill(Palette.inkSolid) }
                }
                .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(newItemName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                .accessibilityLabel(String(localized: "Agregar"))
            }
            .screenPadding()
        }
    }

    private func addManualIngredient() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(Motion.entrance) {
            detected.append(Ingredient(name: trimmed, category: .condiments, confidence: 1))
        }
        newItemName = ""
        Haptics.tick()
    }

    // MARK: - Pie

    private var footer: some View {
        VStack(spacing: Space.xs) {
            Button {
                Haptics.commit()
                onConfirm(kept)
            } label: {
                Text(String(localized: "Guardar \(kept.count) ingredientes"))
            }
            .buttonStyle(InkButtonStyle(fullWidth: true))
            .disabled(kept.isEmpty)
            .opacity(kept.isEmpty ? 0.5 : 1)

            Button(String(localized: "Sacar otra foto")) {
                Haptics.select()
                onRetake()
            }
            .font(Typeface.action)
            .foregroundStyle(Palette.inkSoft)
        }
        .padding(.horizontal, Space.screen)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.md)
        .background {
            Rectangle()
                .fill(Palette.canvas)
                .mask {
                    LinearGradient(colors: [.clear, .black, .black],
                                   startPoint: .top, endPoint: .bottom)
                }
                .ignoresSafeArea()
        }
    }
}

// MARK: - Layout fluido de chips

/// Envuelve chips en varias líneas. `Layout` nativo en lugar de la vieja
/// receta de GeometryReader anidados, que rompe el sizing del ScrollView.
struct FlowChips<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        FlowLayout(spacing: Space.xs) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [CGFloat] = [0]
        var rowHeights: [CGFloat] = [0]

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let currentWidth = rows[rows.count - 1]
            let needed = currentWidth == 0 ? size.width : currentWidth + spacing + size.width

            if needed > maxWidth, currentWidth > 0 {
                rows.append(size.width)
                rowHeights.append(size.height)
            } else {
                rows[rows.count - 1] = needed
                rowHeights[rowHeights.count - 1] = max(rowHeights[rowHeights.count - 1], size.height)
            }
        }

        let height = rowHeights.reduce(0, +) + spacing * CGFloat(max(rowHeights.count - 1, 0))
        return CGSize(width: maxWidth == .infinity ? rows.max() ?? 0 : maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
