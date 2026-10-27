//
//  KitchenView.swift
//  FridgeWise
//
//  Pantalla principal. Estructura calcada del panel izquierdo de la referencia:
//    fecha discreta → titular serif con palabra en cursiva subrayada →
//    fila de círculos de color con etiquetas en versalita → "esta semana" →
//    tarjeta de observación con voz humana.
//
//  Lo que en la referencia son emociones, aquí son categorías de la despensa.
//  El mapeo es directo y por eso funciona: son 5-7 elementos, cada uno con
//  un color propio y un conteo, leídos de un vistazo.
//

import SwiftUI

struct KitchenView: View {

    @Environment(\.app) private var app
    @Binding var isTabBarDimmed: Bool

    @State private var selectedDay = Date()
    @State private var isCalendarExpanded = false
    @State private var isPickingRecipe = false
    @State private var editingIngredient: IngredientEditorSheet.Target?
    @State private var editingPlan: CookPlan?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                header
                hero
                pantryConstellation
                weekSection
                insightCard
                scanPrompt

                if !app.expiringSoon.isEmpty {
                    rescueSection
                }

                rhythmCard

                if !app.profile.isPremium {
                    planMeter
                }
            }
            .padding(.top, Space.xs)
            .padding(.bottom, Space.tabBarInset)
            .readsScrollDirection(into: $isTabBarDimmed)
        }
        .coordinateSpace(name: "scroll")
        .scrollIndicators(.hidden)
        .editorialScrollFeel()
        .canvasBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isPickingRecipe) {
            RecipePickerSheet(day: selectedDay) { recipe in
                app.schedulePlan(for: recipe, on: selectedDay)
            }
            .presentationDetents([.large])
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Palette.canvas)
        }
        .sheet(item: $editingIngredient) { target in
            IngredientEditorSheet(target: target)
                .presentationDetents([.large])
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Palette.canvas)
        }
        .sheet(item: $editingPlan) { plan in
            CookPlanEditorSheet(plan: plan)
                .presentationDetents([.large])
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Palette.canvas)
        }
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(alignment: .center) {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                .font(Typeface.caption)
                .foregroundStyle(Palette.inkSoft)

            Spacer()

            HStack(spacing: 2) {
                streakBadge

                NavigationLink(value: Route.settings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(Typeface.scaled(14.5, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 34, height: 34)
                        .background { Circle().fill(Palette.surface) }
                        .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(String(localized: "Ajustes"))
            }
        }
        .screenPadding()
    }

    private var streakBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(Typeface.scaled(10, weight: .semibold))
            Text("\(app.profile.streak.currentDays)")
                .font(Typeface.scaled(12, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(app.profile.streak.currentDays)))
        }
        .foregroundStyle(Palette.turmeric)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background { Capsule().fill(Palette.turmeric.opacity(0.13)) }
        .accessibilityLabel(String(localized: "Racha de \(app.profile.streak.currentDays) días"))
    }

    // MARK: - Titular

    /// Saludo por hora + nombre de quien abre la app, y la pregunta debajo.
    ///
    /// El nombre va en cursiva serif, no en el mismo peso que el saludo: es la
    /// única palabra de la pantalla que es suya, y ponerla en cursiva la hace
    /// personal sin gritar. Si el nombre falta, la coma desaparece con él —
    /// "Buenos días, " con un hueco detrás es peor que no saludar por nombre.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 2) {
            greetingLine
                .tracking(-0.6)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(String(localized: "¿Qué"))
                    .displayStyle(29)
                Text(String(localized: "cocinamos"))
                    .font(Typeface.displayItalic(29))
                    .foregroundStyle(Palette.ink)
                    .squiggleUnderline(Palette.turmeric)
                Text(String(localized: "hoy?"))
                    .displayStyle(29)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.bottom, Space.xxs)
        }
        .screenPadding()
        .padding(.top, Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(spokenGreeting). \(String(localized: "¿Qué cocinamos hoy?"))")
    }

    private var greetingLine: Text {
        let base = Text(timeGreeting).font(Typeface.display(31))
        guard !firstName.isEmpty else { return base }

        return base
            + Text(", ").font(Typeface.display(31))
            + Text(firstName).font(Typeface.displayItalic(31))
    }

    private var timeGreeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12:  String(localized: "Buenos días")
        case 12..<21: String(localized: "Buenas tardes")
        default:      String(localized: "Buenas noches")
        }
    }

    /// Solo el nombre de pila. "Buenos días, Alejandro Bachmann Ruiz" no es un
    /// saludo, es el encabezado de una factura.
    private var firstName: String {
        app.profile.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first
            .map(String.init) ?? ""
    }

    private var spokenGreeting: String {
        firstName.isEmpty ? timeGreeting : "\(timeGreeting), \(firstName)"
    }

    // MARK: - Constelación de despensa

    /// La fila de círculos de color de la referencia. Cada círculo es una
    /// categoría; el número adentro es cuánto hay. Tocar filtra el feed.
    private var pantryConstellation: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Space.md) {
                    ForEach(populatedCategories, id: \.category) { entry in
                        categoryOrb(entry.category, count: entry.count)
                    }
                    addIngredientOrb
                }
                .padding(.horizontal, Space.screen)
            }
            .scrollIndicators(.hidden)
            .tightHorizontalRail()
        }
    }

    private var populatedCategories: [(category: PantryCategory, count: Int)] {
        PantryCategory.allCases.compactMap { category in
            let count = app.pantry.filter { $0.category == category }.count
            return count > 0 ? (category, count) : nil
        }
    }

    /// Cierra la constelación. Un contorno en vez de un relleno: no es una
    /// categoría más, es la puerta para arreglar lo que el escáner no vio.
    private var addIngredientOrb: some View {
        Button {
            Haptics.select()
            editingIngredient = .new
        } label: {
            VStack(spacing: Space.xs) {
                ZStack {
                    Circle()
                        .strokeBorder(Palette.inkFaint.opacity(0.35),
                                      style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    Image(systemName: "plus")
                        .font(Typeface.scaled(15, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                }
                .frame(width: 52, height: 52)

                Text(String(localized: "Añadir"))
                    .eyebrow()
                    .frame(width: 66)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel(String(localized: "Añadir un producto a la despensa"))
    }

    private func categoryOrb(_ category: PantryCategory, count: Int) -> some View {
        VStack(spacing: Space.xs) {
            ZStack {
                Circle()
                    .fill(category.accent.color.opacity(0.85))

                Text("\(count)")
                    .font(Typeface.scaled(17, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.onInk)
                    .contentTransition(.numericText(value: Double(count)))
            }
            .frame(width: 52, height: 52)
            .shadow(color: category.accent.color.opacity(0.25), radius: 10, x: 0, y: 5)

            Text(category.title)
                .eyebrow()
                .frame(width: 66)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category.title): \(count)")
    }

    // MARK: - Semana

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(
                title: isCalendarExpanded
                    ? String(localized: "Este mes")
                    : String(localized: "Esta semana"),
                accent: Palette.basil
            ) {
                Button {
                    Haptics.select()
                    withAnimation(Motion.standard) { isCalendarExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(isCalendarExpanded
                             ? String(localized: "Ver semana")
                             : String(localized: "Ver mes"))
                        Image(systemName: "chevron.down")
                            .font(Typeface.scaled(8, weight: .bold))
                            .rotationEffect(.degrees(isCalendarExpanded ? 180 : 0))
                    }
                    .font(Typeface.micro)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.basil)
                    .padding(.vertical, 4)
                    .hitTarget(horizontal: 4, vertical: 10)
                }
                .buttonStyle(.plain)
            }
            .screenPadding()

            if isCalendarExpanded {
                SoftCard(padding: Space.md) {
                    MonthCalendar(
                        selection: $selectedDay,
                        markedDays: app.plannedDays,
                        accent: Palette.basil
                    )
                }
                .screenPadding()
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                WeekStrip(days: weekMarkers, selection: $selectedDay)
                    .screenPadding()
            }

            dayPlans
        }
    }

    // MARK: - Planes del día

    @ViewBuilder
    private var dayPlans: some View {
        let plans = app.cookPlans(on: selectedDay)

        VStack(alignment: .leading, spacing: Space.xs) {
            if plans.isEmpty {
                Text(Calendar.current.isDateInToday(selectedDay)
                     ? String(localized: "Hoy no tienes nada agendado.")
                     : String(localized: "Sin planes para ese día."))
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.inkFaint)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                        SwipeableRow(onDelete: { app.removePlan(plan) }) {
                            planRow(plan)
                        }
                        if index < plans.count - 1 {
                            Hairline(inset: 34)
                        }
                    }
                }
                .padding(.vertical, Space.xxs)
                .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
                .overlay {
                    RoundedRectangle.soft(Radius.card)
                        .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
                }
                .clipShape(RoundedRectangle.soft(Radius.card))
            }

            Button {
                Haptics.select()
                isPickingRecipe = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .font(Typeface.scaled(11, weight: .semibold))
                    Text(String(localized: "Agendar una receta"))
                        .font(Typeface.micro)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(Palette.basil)
                .padding(.vertical, 6)
                .hitTarget(vertical: 8)
            }
            .buttonStyle(.plain)
        }
        .screenPadding()
        .motion(Motion.standard, value: plans.count)
    }

    /// Tocar la fila abre el editor del plan. Es el sitio donde el usuario se
    /// da cuenta de que lo agendó para el día equivocado o de que el aviso le
    /// queda tarde — y por tanto es desde donde tiene que poder arreglarlo,
    /// sin borrar el plan y volver a buscar la receta entre cincuenta.
    ///
    /// El toque es un `onTapGesture` y no un `Button` por una razón concreta:
    /// la fila va dentro de un `SwipeableRow`, y un botón que ocupa la fila
    /// entera gana la prioridad del gesto y se come el arrastre. Con un tap
    /// (que exige cero movimiento) y el drag del contenedor conviven: tocar
    /// abre, deslizar borra, y el scroll vertical sigue siendo del scroll view.
    private func planRow(_ plan: CookPlan) -> some View {
        HStack(spacing: Space.sm) {
            AccentDot(color: Palette.basil, size: 8, filled: true)

            VStack(alignment: .leading, spacing: 1) {
                Text(plan.recipeTitle)
                    .font(Typeface.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let remindsAt = plan.remindsAt {
                        Image(systemName: "bell")
                            .font(Typeface.scaled(8, weight: .semibold))
                        Text(remindsAt.formatted(.dateTime.hour().minute()))
                            .font(Typeface.micro)
                    } else {
                        Image(systemName: "bell.slash")
                            .font(Typeface.scaled(8, weight: .semibold))
                        Text(String(localized: "Sin aviso"))
                            .font(Typeface.micro)
                    }
                }
                .foregroundStyle(Palette.inkFaint)
            }

            Spacer(minLength: Space.xs)

            Image(systemName: "slider.horizontal.3")
                .font(Typeface.scaled(11, weight: .semibold))
                .foregroundStyle(Palette.inkFaint)
                .frame(width: 30, height: 30)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 10)
        .background(Palette.surface)
        .contentShape(Rectangle())
        .onTapGesture { openEditor(for: plan) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(String(localized: "Toca para cambiar el día o el recordatorio"))
        .accessibilityAction { openEditor(for: plan) }
    }

    private func openEditor(for plan: CookPlan) {
        Haptics.select()
        editingPlan = plan
    }

    private var weekMarkers: [WeekStrip.DayMarker] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let rhythm = app.ledger.weeklyRhythm()

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - 3, to: today) ?? today
            let index = min(max(offset, 0), rhythm.count - 1)
            return WeekStrip.DayMarker(
                date: date,
                activity: date <= today ? Double(rhythm[index]) : 0,
                accent: .basil
            )
        }
    }

    // MARK: - Observación

    /// La tarjeta "Reflection" de la referencia. Aquí es una observación real
    /// sobre la despensa, con la palabra clave en cursiva serif.
    private var insightCard: some View {
        SoftCard(tint: insight.accent.color) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: 6) {
                    Image(systemName: insight.icon)
                        .font(Typeface.scaled(10, weight: .semibold))
                        .foregroundStyle(insight.accent.color)
                    Text(String(localized: "Observación")).eyebrow(insight.accent.color)

                    Spacer(minLength: Space.xs)

                    // La observación se calcula con lo que hay cargado. Si está
                    // mal, se corrige desde el mismo sitio donde se lee.
                    Button {
                        Haptics.select()
                        editingIngredient = .new
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(Typeface.scaled(9, weight: .bold))
                            Text(String(localized: "Producto"))
                                .font(Typeface.micro)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(insight.accent.color)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background { Capsule().fill(insight.accent.color.opacity(0.12)) }
                        .hitTarget(vertical: 10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Añadir un producto a la despensa"))
                }

                (Text(insight.lead)
                    + Text(insight.emphasis).italic()
                    + Text(insight.tail))
                    .font(Typeface.quote)
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .screenPadding()
    }

    private struct Insight {
        var lead: String
        var emphasis: String
        var tail: String
        var icon: String
        var accent: AccentFamily
    }

    private var insight: Insight {
        let expiring = app.expiringSoon
        if let first = expiring.first, expiring.count > 1 {
            return Insight(
                lead: String(localized: "Tienes \(expiring.count) cosas que vencen pronto, empezando por "),
                emphasis: first.name.lowercased(),
                tail: String(localized: ". Armemos algo que las rescate antes de que se pierdan."),
                icon: "clock.badge.exclamationmark",
                accent: .turmeric
            )
        }
        if let first = expiring.first {
            return Insight(
                lead: String(localized: "El "),
                emphasis: first.name.lowercased(),
                tail: String(localized: " vence \(first.expiryDescription?.lowercased() ?? ""). Hay recetas que lo usan bien."),
                icon: "leaf",
                accent: .sage
            )
        }
        return Insight(
            lead: String(localized: "Tu despensa está "),
            emphasis: String(localized: "en orden"),
            tail: String(localized: ". Buen momento para probar algo nuevo con lo que ya tienes."),
            icon: "checkmark.seal",
            accent: .basil
        )
    }

    // MARK: - Escanear

    private var scanPrompt: some View {
        Button {
            Haptics.commit()
            app.isPresentingScanner = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle.soft(Radius.lg)
                    .fill(Palette.surface)
                    .overlay {
                        FluidBackdrop(palette: .scanning, intensity: 0.42)
                            .clipShape(RoundedRectangle.soft(Radius.lg))
                    }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Image(systemName: "viewfinder")
                        .font(Typeface.scaled(22, weight: .light))
                        .foregroundStyle(Palette.ink)
                        .padding(.bottom, Space.xxs)

                    Text(String(localized: "Escanea tu nevera o el ticket"))
                        .font(Typeface.cardTitle)
                        .foregroundStyle(Palette.ink)

                    Text(String(localized: "Una foto a los estantes, o al ticket de la compra, y sabemos qué tienes."))
                        .font(Typeface.callout)
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.lg)
            }
            .frame(height: 172)
            .overlay {
                RoundedRectangle.soft(Radius.lg)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
            .shadow(color: Palette.cardShadow, radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.pressableCard)
        .screenPadding()
    }

    // MARK: - Rescate

    private var rescueSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: String(localized: "Usar pronto"), accent: Palette.tomato) {
                HStack(spacing: Space.xs) {
                    Text("\(app.expiringSoon.count)")
                        .font(Typeface.percentage)
                        .foregroundStyle(Palette.tomato)

                    Button {
                        Haptics.select()
                        editingIngredient = .new
                    } label: {
                        Image(systemName: "plus")
                            .font(Typeface.scaled(11, weight: .bold))
                            .foregroundStyle(Palette.tomato)
                            .frame(width: 26, height: 26)
                            .background { Circle().fill(Palette.tomato.opacity(0.12)) }
                            .frame(width: 44, height: 44, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Añadir un producto"))
                }
            }
            .screenPadding()

            VStack(spacing: 0) {
                ForEach(Array(app.expiringSoon.prefix(4).enumerated()), id: \.element.id) { index, item in
                    // Deslizar borra el producto de la despensa. Esta lista es
                    // justo donde el usuario descubre que ya se comió o tiró
                    // algo, y hasta ahora el único camino era entrar al editor
                    // y buscar el botón de borrar dentro.
                    SwipeableRow(onDelete: { app.removeIngredient(item) }) {
                        expiringRow(item)
                    }
                    if index < min(app.expiringSoon.count, 4) - 1 {
                        Hairline(inset: 34)
                    }
                }
            }
            .padding(.vertical, Space.xxs)
            .background {
                RoundedRectangle.soft(Radius.card).fill(Palette.surface)
            }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
            .clipShape(RoundedRectangle.soft(Radius.card))
            .screenPadding()
        }
    }

    /// Tocar la fila abre el editor. Es donde el usuario se da cuenta de que la
    /// fecha está mal — que es justo cuando tiene que poder arreglarla.
    /// Deslizar la borra. Igual que en `planRow`, el toque es un gesto y no un
    /// `Button`: un botón de fila completa le robaría el arrastre al swipe.
    private func expiringRow(_ item: Ingredient) -> some View {
        HStack(spacing: Space.sm) {
            AccentDot(color: item.freshness.accent.color, size: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(Typeface.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(Palette.ink)
                if let quantity = item.quantity {
                    Text(quantity)
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkFaint)
                }
            }

            Spacer(minLength: Space.xs)

            Text(item.expiryDescription ?? "")
                .font(Typeface.micro)
                .fontWeight(.semibold)
                .foregroundStyle(item.freshness.accent.color)

            Image(systemName: "chevron.right")
                .font(Typeface.scaled(10, weight: .semibold))
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 11)
        .background(Palette.surface)
        .contentShape(Rectangle())
        .onTapGesture { editingIngredient = .existing(item) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(String(localized: "Toca para corregir cantidad o fecha, o desliza para borrarlo"))
        .accessibilityAction { editingIngredient = .existing(item) }
    }

    // MARK: - Ritmo

    private var rhythmCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(localized: "Tu ritmo")).eyebrow()
                    Spacer()
                    Text(String(localized: "7 días")).eyebrow()
                }

                SparklineChart(
                    values: app.ledger.weeklyRhythm(),
                    accent: Palette.basil,
                    leadingLabel: sparklineStart,
                    trailingLabel: String(localized: "Hoy")
                )

                Hairline()

                HStack(spacing: Space.lg) {
                    MetricStat(value: "\(app.profile.streak.currentDays)",
                               label: String(localized: "Racha"),
                               systemImage: "flame", accent: Palette.turmeric)
                    MetricStat(value: "\(app.pantry.count)",
                               label: String(localized: "En despensa"),
                               systemImage: "refrigerator", accent: Palette.sage)
                    MetricStat(value: "\(app.savedRecipeIDs.count)",
                               label: String(localized: "Guardadas"),
                               systemImage: "bookmark", accent: Palette.clay)
                }
            }
        }
        .screenPadding()
    }

    private var sparklineStart: String {
        let date = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    // MARK: - Plan gratuito

    /// Se muestra el consumo ANTES de que el usuario choque contra el límite.
    /// Enterarse de la cuota recién cuando te frena es lo que genera reseñas de 1★.
    private var planMeter: some View {
        SoftCard(tint: Palette.turmeric) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    Text(String(localized: "Plan gratuito · esta semana")).eyebrow(Palette.turmeric)
                    Spacer()
                    Button {
                        app.isPresentingPaywall = true
                    } label: {
                        Text(String(localized: "Ver Premium"))
                            .font(Typeface.micro)
                            .fontWeight(.semibold)
                            .foregroundStyle(Palette.turmeric)
                            .hitTarget(horizontal: 4, vertical: 14)
                    }
                    .buttonStyle(.plain)
                }

                ForEach([MeteredResource.scan, .aiGeneration], id: \.self) { resource in
                    let limit = resource.limit(under: app.effectiveLimits)
                    DistributionRow(
                        label: resource.title,
                        value: limit == .max ? 0 : Double(app.used(resource)) / Double(limit),
                        accent: Palette.turmeric,
                        trailingText: limit == .max
                            ? String(localized: "Sin límite")
                            : "\(app.used(resource))/\(limit)"
                    )
                }
            }
        }
        .screenPadding()
    }
}
