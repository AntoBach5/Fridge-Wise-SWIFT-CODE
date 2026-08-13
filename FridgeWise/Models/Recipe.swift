//
//  Recipe.swift
//  FridgeWise
//

import SwiftUI

// MARK: - Salud nutricional

/// Escala A–E al estilo Nutri-Score. Deliberadamente NO es "8.4/10":
/// una letra se lee de un vistazo y no sugiere una precisión que no tenemos.
enum NutritionGrade: String, Codable, CaseIterable, Comparable, Sendable {
    case a, b, c, d, e

    static func < (lhs: Self, rhs: Self) -> Bool {
        Self.allCases.firstIndex(of: lhs)! < Self.allCases.firstIndex(of: rhs)!
    }

    var letter: String { rawValue.uppercased() }

    /// Cuánto del anillo se llena.
    var fill: CGFloat {
        switch self {
        case .a: 1.0
        case .b: 0.8
        case .c: 0.6
        case .d: 0.4
        case .e: 0.22
        }
    }

    var color: Color {
        switch self {
        case .a: Palette.basil
        case .b: Palette.sage
        case .c: Palette.turmeric
        case .d: Palette.clay
        case .e: Palette.tomato
        }
    }

    var caption: String {
        switch self {
        case .a: String(localized: "Excelente")
        case .b: String(localized: "Muy buena")
        case .c: String(localized: "Equilibrada")
        case .d: String(localized: "Indulgente")
        case .e: String(localized: "Un capricho")
        }
    }
}

// MARK: - Macros

struct Macros: Hashable, Codable, Sendable {
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double
    var fiberGrams: Double

    /// Distribución por calorías (4/4/9 kcal por gramo), no por peso.
    /// Por peso da porcentajes que engañan y ya nos costaría una review.
    var caloricDistribution: [(label: String, value: Double, accent: Color)] {
        let p = proteinGrams * 4
        let c = carbGrams * 4
        let f = fatGrams * 9
        let total = max(p + c + f, 1)
        return [
            (String(localized: "Proteínas"), p / total, Palette.clay),
            (String(localized: "Carbohidratos"), c / total, Palette.turmeric),
            (String(localized: "Grasas"), f / total, Palette.tomato)
        ]
    }
}

// MARK: - Etiquetas

enum RecipeTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case quick, veggie, highProtein, useSoon, comfort, lowCal, budget, onePan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick:       String(localized: "Rápida")
        case .veggie:      String(localized: "Veggie")
        case .highProtein: String(localized: "Alta en proteína")
        case .useSoon:     String(localized: "Usa lo que vence")
        case .comfort:     String(localized: "Reconfortante")
        case .lowCal:      String(localized: "Ligera")
        case .budget:      String(localized: "Económica")
        case .onePan:      String(localized: "Una sola olla")
        }
    }

    var accent: AccentFamily {
        switch self {
        case .quick:       .mist
        case .veggie:      .sage
        case .highProtein: .clay
        case .useSoon:     .tomato
        case .comfort:     .turmeric
        case .lowCal:      .basil
        case .budget:      .plum
        case .onePan:      .clay
        }
    }
}

// MARK: - Origen

enum RecipeSource: String, Codable, Sendable {
    case generated      // creada por IA a partir de la despensa del usuario
    case community      // publicada por otro usuario
    case editorial      // curada por el equipo

    var label: String {
        switch self {
        case .generated: String(localized: "Generada para ti")
        case .community: String(localized: "De la comunidad")
        case .editorial: String(localized: "Selección Fridge Wise")
        }
    }

    var icon: String {
        switch self {
        case .generated: "sparkles"
        case .community: "person.2"
        case .editorial: "leaf"
        }
    }

    var accent: AccentFamily {
        switch self {
        case .generated: .plum
        case .community: .mist
        case .editorial: .basil
        }
    }
}

// MARK: - Piezas

struct RecipeIngredient: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var name: String
    var amount: String
    var category: PantryCategory
    /// Calculado contra la despensa: `false` ⇒ candidato para "To Buy".
    var isInPantry: Bool
    var isOptional: Bool = false
}

struct RecipeStep: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var order: Int
    var instruction: String
    /// Minutos activos de este paso. Alimenta el temporizador del modo cocina.
    var minutes: Int?
    /// Consejo opcional del chef — se muestra en cursiva serif.
    var tip: String?
}

// MARK: - Receta

struct Recipe: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String
    var source: RecipeSource

    // Métricas del encabezado
    var minutes: Int
    var difficulty: Int          // 1...3
    var calories: Int            // por porción
    var servings: Int
    var grade: NutritionGrade
    var macros: Macros

    // Contenido
    var ingredients: [RecipeIngredient]
    var steps: [RecipeStep]
    var tags: [RecipeTag]

    /// Alérgenos declarados. Obligatorio mostrarlos: es una app de comida y
    /// omitirlos es un riesgo real, no un detalle de UI.
    var allergens: [String]

    // Presentación
    var accent: AccentFamily
    /// Nombre de asset local; si es `nil` se usa un gradiente procedural derivado del título.
    var imageName: String?

    // Comunidad
    var rating: Double
    var ratingCount: Int
    var savedCount: Int
    var authorName: String?
    var authorInitials: String?

    var createdAt: Date = .now

    // MARK: Derivados

    var missingIngredients: [RecipeIngredient] {
        ingredients.filter { !$0.isInPantry && !$0.isOptional }
    }

    var pantryMatch: Double {
        let required = ingredients.filter { !$0.isOptional }
        guard !required.isEmpty else { return 1 }
        return Double(required.filter(\.isInPantry).count) / Double(required.count)
    }

    var matchDescription: String {
        switch pantryMatch {
        case 1:     String(localized: "Tienes todo")
        case 0.8...: String(localized: "Falta 1 ingrediente")
        default:    String(localized: "Faltan \(missingIngredients.count) ingredientes")
        }
    }

    var totalActiveMinutes: Int {
        steps.compactMap(\.minutes).reduce(0, +)
    }

    /// Semilla estable para el gradiente procedural del hero cuando no hay foto.
    var heroSeed: Int { abs(title.hashValue % 360) }
}
