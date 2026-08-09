//
//  ListModels.swift
//  FridgeWise
//
//  Sistema dual de listas: "To Buy" (compras) y "To Cook" (cocinar).
//  La clave del diseño es que ambas comparten el mismo tipo de fila pero
//  llevan cargas distintas, y las dos se alimentan desde el detalle de receta:
//  · Falta un ingrediente → va a To Buy, con backlink a la receta.
//  · Quiero cocinar esto  → va a To Cook, arrastrando sus faltantes a To Buy.
//

import SwiftUI

enum ListKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case toBuy, toCook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toBuy:  String(localized: "To Buy")
        case .toCook: String(localized: "To Cook")
        }
    }

    var emptyHeadline: String {
        switch self {
        case .toBuy:  String(localized: "Nada en la lista")
        case .toCook: String(localized: "Sin planes de")
        }
    }

    var emptyEmphasis: String {
        switch self {
        case .toBuy:  String(localized: "todavía")
        case .toCook: String(localized: "cocina")
        }
    }

    var emptyMessage: String {
        switch self {
        case .toBuy:
            String(localized: "Cuando una receta necesite algo que no tenés, aparece acá con un toque.")
        case .toCook:
            String(localized: "Guardá una receta para cocinar y armamos el plan con sus pasos y tiempos.")
        }
    }

    var icon: String {
        switch self {
        case .toBuy:  "basket"
        case .toCook: "frying.pan"
        }
    }

    var accent: AccentFamily {
        switch self {
        case .toBuy:  .turmeric
        case .toCook: .basil
        }
    }
}

// MARK: - Ítem

struct ListItem: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var kind: ListKind
    var title: String
    /// "500 g", "2 unidades", o el subtítulo de la receta en To Cook.
    var detail: String?
    var category: PantryCategory?
    var isDone: Bool = false
    var createdAt: Date = .now
    var completedAt: Date?

    /// Receta de origen. Es lo que hace que las listas se sientan integradas
    /// y no un bloc de notas aparte: cada fila puede volver a su receta.
    var recipeID: Recipe.ID?
    var recipeTitle: String?

    /// Para To Cook: fecha en la que el usuario planeó cocinarlo.
    var plannedFor: Date?

    var accent: AccentFamily {
        category?.accent ?? kind.accent
    }
}

// MARK: - Agrupación

/// Agrupa To Buy por categoría (así el usuario recorre el súper por pasillo)
/// y To Cook por día planificado.
enum ListGrouping {
    static func groupToBuy(_ items: [ListItem]) -> [(title: String, accent: AccentFamily, items: [ListItem])] {
        let pending = items.filter { !$0.isDone }
        return Dictionary(grouping: pending) { $0.category ?? .condiments }
            .map { (title: $0.key.title, accent: $0.key.accent, items: $0.value.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.title < $1.title }
    }

    static func groupToCook(_ items: [ListItem]) -> [(title: String, accent: AccentFamily, items: [ListItem])] {
        let pending = items.filter { !$0.isDone }
        let calendar = Calendar.current

        let planned = pending.filter { $0.plannedFor != nil }
        let unplanned = pending.filter { $0.plannedFor == nil }

        var groups = Dictionary(grouping: planned) { item in
            calendar.startOfDay(for: item.plannedFor!)
        }
        .map { (date, items) -> (title: String, accent: AccentFamily, items: [ListItem]) in
            let title = calendar.isDateInToday(date)
                ? String(localized: "Hoy")
                : (calendar.isDateInTomorrow(date)
                   ? String(localized: "Mañana")
                   : date.formatted(.dateTime.weekday(.wide).day()))
            return (title: title, accent: .basil, items: items)
        }
        .sorted { $0.title < $1.title }

        if !unplanned.isEmpty {
            groups.append((title: String(localized: "Sin fecha"), accent: .sage, items: unplanned))
        }
        return groups
    }
}
