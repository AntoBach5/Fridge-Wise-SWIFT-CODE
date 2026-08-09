//
//  Ingredient.swift
//  FridgeWise
//

import SwiftUI

// MARK: - Categoría de despensa

enum PantryCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case produce, protein, dairy, grains, condiments, frozen, leftovers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .produce:    String(localized: "Frutas y verduras")
        case .protein:    String(localized: "Proteínas")
        case .dairy:      String(localized: "Lácteos")
        case .grains:     String(localized: "Granos y pastas")
        case .condiments: String(localized: "Condimentos")
        case .frozen:     String(localized: "Congelados")
        case .leftovers:  String(localized: "Sobras")
        }
    }

    var icon: String {
        switch self {
        case .produce:    "carrot"
        case .protein:    "fish"
        case .dairy:      "waterbottle"
        case .grains:     "takeoutbag.and.cup.and.straw"
        case .condiments: "drop"
        case .frozen:     "snowflake"
        case .leftovers:  "fork.knife"
        }
    }

    var accent: AccentFamily {
        switch self {
        case .produce:    .sage
        case .protein:    .clay
        case .dairy:      .mist
        case .grains:     .turmeric
        case .condiments: .plum
        case .frozen:     .mist
        case .leftovers:  .tomato
        }
    }
}

// MARK: - Frescura

enum Freshness: Int, Codable, Comparable, Sendable {
    case fresh, useSoon, expiring, expired

    static func < (lhs: Freshness, rhs: Freshness) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .fresh:    String(localized: "Fresco")
        case .useSoon:  String(localized: "Usar pronto")
        case .expiring: String(localized: "Vence hoy")
        case .expired:  String(localized: "Vencido")
        }
    }

    var accent: AccentFamily {
        switch self {
        case .fresh:    .basil
        case .useSoon:  .turmeric
        case .expiring: .tomato
        case .expired:  .tomato
        }
    }
}

// MARK: - Ingrediente

struct Ingredient: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var name: String
    var category: PantryCategory
    var quantity: String?
    var addedAt: Date = .now
    var expiresAt: Date?

    /// Confianza del reconocimiento (0...1). `nil` si el usuario lo cargó a mano.
    /// Se muestra al usuario cuando baja de 0.75 para que pueda corregir —
    /// nunca presentamos una detección dudosa como si fuera un hecho.
    var confidence: Double?

    /// Posición normalizada dentro de la foto escaneada (0...1 en ambos ejes).
    /// Sirve para anclar los pins de detección sobre la imagen.
    var detectionBox: CGRect?

    /// El usuario confirmó o corrigió esta detección.
    var isConfirmed: Bool = true

    var freshness: Freshness {
        guard let expiresAt else { return .fresh }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expiresAt).day ?? 99
        return switch days {
        case ..<0:   .expired
        case 0:      .expiring
        case 1...2:  .useSoon
        default:     .fresh
        }
    }

    var needsReview: Bool {
        guard let confidence else { return false }
        return confidence < 0.75
    }

    var expiryDescription: String? {
        guard let expiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expiresAt).day ?? 0
        return switch days {
        case ..<0:  String(localized: "Vencido")
        case 0:     String(localized: "Hoy")
        case 1:     String(localized: "Mañana")
        default:    String(localized: "En \(days) días")
        }
    }
}

// MARK: - Resultado de escaneo

/// Lo que devuelve un escaneo. Se mantiene separado de `Ingredient` porque
/// el usuario tiene que poder revisar y editar antes de que entre a la despensa.
struct ScanResult: Identifiable, Sendable, Equatable {
    var id: UUID = UUID()
    var capturedAt: Date = .now
    var detected: [Ingredient]
    /// Confianza global. Por debajo de 0.6 sugerimos volver a sacar la foto.
    var overallConfidence: Double

    var needsBetterPhoto: Bool { overallConfidence < 0.6 }

    var groupedByCategory: [(category: PantryCategory, items: [Ingredient])] {
        Dictionary(grouping: detected, by: \.category)
            .map { (category: $0.key, items: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.category.rawValue < $1.category.rawValue }
    }
}
