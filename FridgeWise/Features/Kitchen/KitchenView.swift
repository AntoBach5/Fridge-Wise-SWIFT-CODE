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
                        .font(.system(size: 14.5, weight: .medium))
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
                .font(.system(size: 10, weight: .semibold))
            Text("\(app.profile.streak.currentDays)")
                .font(.system(size: 12, weight: .semibold))
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greeting)
                .displayStyle(33)

            HStack(spacing: 9) {
                Text(String(localized: "cocinamos"))
                    .font(Typeface.displayItalic(33))
                    .foregroundStyle(Palette.ink)
                    .squiggleUnderline(Palette.turmeric)
                Text(String(localized: "hoy?"))
                    .displayStyle(33)
            }
            .padding(.bottom, Space.xxs)
        }
        .screenPadding()
        .padding(.top, Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting) \(String(localized: "cocinamos hoy?"))")
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12:  String(localized: "Buenos días. ¿Qué")
        case 12..<19: String(localized: "Buenas tardes. ¿Qué")
        default:      String(localized: "Buenas noches. ¿Qué")
        }
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

    private func categoryOrb(_ category: PantryCategory, count: Int) -> some View {
        VStack(spacing: Space.xs) {
            ZStack {
                Circle()
                    .fill(category.accent.color.opacity(0.85))

                Text("\(count)")
                    .font(.system(size: 17, weight: .medium, design: .serif))
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
            SectionHeader(String(localized: "Esta semana"))
                .screenPadding()

            WeekStrip(days: weekMarkers, selection: $selectedDay)
                .screenPadding()
        }
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
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(insight.accent.color)
                    Text(String(localized: "Observación")).eyebrow(insight.accent.color)
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
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Palette.ink)
                        .padding(.bottom, Space.xxs)

                    Text(String(localized: "Escanea tu nevera"))
                        .font(Typeface.cardTitle)
                        .foregroundStyle(Palette.ink)

                    Text(String(localized: "Una foto y sabemos qué tienes. Tardas menos que en abrir el cajón de las verduras."))
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
                Text("\(app.expiringSoon.count)")
                    .font(Typeface.percentage)
                    .foregroundStyle(Palette.tomato)
            }
            .screenPadding()

            VStack(spacing: 0) {
                ForEach(Array(app.expiringSoon.prefix(4).enumerated()), id: \.element.id) { index, item in
                    expiringRow(item)
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
            .screenPadding()
        }
    }

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
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
                    Text(String(localized: "Plan gratuito")).eyebrow(Palette.turmeric)
                    Spacer()
                    Button(String(localized: "Ver Premium")) {
                        app.isPresentingPaywall = true
                    }
                    .font(Typeface.micro)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.turmeric)
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
