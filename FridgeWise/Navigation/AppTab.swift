//
//  AppTab.swift
//  FridgeWise
//

import SwiftUI

enum AppTab: String, Identifiable, CaseIterable, Hashable {
    case kitchen
    case recipes
    case lists
    case rewards

    var id: String { rawValue }

    /// Los destinos que viven dentro de la pill. "Escanear" queda afuera a propósito:
    /// es una acción, no un lugar.
    static var barItems: [AppTab] { allCases }

    var title: String {
        switch self {
        case .kitchen: String(localized: "Cocina")
        case .recipes: String(localized: "Recetas")
        case .lists:   String(localized: "Listas")
        case .rewards: String(localized: "Puntos")
        }
    }

    var icon: String {
        switch self {
        case .kitchen: "refrigerator"
        case .recipes: "book.closed"
        case .lists:   "checklist"
        case .rewards: "sparkles"
        }
    }

    var filledIcon: String {
        switch self {
        case .kitchen: "refrigerator.fill"
        case .recipes: "book.closed.fill"
        case .lists:   "checklist.checked"
        case .rewards: "sparkles"
        }
    }
}

// MARK: - Rutas

/// Destinos empujables. Cada tab tiene su propio `NavigationPath`, así el
/// back stack de Recetas no se pisa con el de Listas.
enum Route: Hashable {
    case recipeDetail(Recipe.ID)
    case communityThread(Recipe.ID)
    case ingredientDetail(Ingredient.ID)
    case pointsShop
    case rewardCatalog
    case settings
    case blockedUsers
    case dataAndPrivacy
}
