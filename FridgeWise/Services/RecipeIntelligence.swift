//
//  RecipeIntelligence.swift
//  FridgeWise
//
//  Generación de recetas.
//
//  Igual que el escáner: el modelo real va después, pero el contrato es el
//  definitivo. Dos detalles que ya están decididos y no son negociables:
//
//  1. TODA receta generada sale marcada `.generated` y arrastra un disclaimer
//     de alérgenos y de estimación nutricional. Guideline 1.4.1 más sentido
//     común: no podemos afirmar calorías exactas de algo que inventó un modelo.
//  2. La generación pasa por `ModerationService` antes de mostrarse. Guideline
//     4.7 / 1.2: el contenido de IA necesita el mismo filtro que el de usuarios.
//

import Foundation

// MARK: - Contrato

protocol RecipeGenerating: Sendable {
    /// Genera recetas a partir de la despensa, con el avance en streaming
    /// para que la UI pueda mostrar la receta armándose.
    func generate(
        from pantry: [Ingredient],
        preferences: GenerationPreferences
    ) -> AsyncThrowingStream<GenerationPhase, Error>
}

struct GenerationPreferences: Sendable, Equatable {
    var servings: Int = 2
    var maxMinutes: Int? = nil
    var tags: Set<RecipeTag> = []
    /// Restricciones dietarias del usuario. Se respetan de forma DURA:
    /// si el modelo devuelve algo que las viola, se descarta.
    var exclusions: Set<String> = []
    /// Prioriza ingredientes que están por vencer.
    var prioritizeExpiring: Bool = true
}

enum GenerationPhase: Sendable {
    case reading           // leyendo la despensa
    case composing         // armando combinaciones
    case balancing         // calculando nutrición
    case ready([Recipe])

    var caption: String {
        switch self {
        case .reading:   String(localized: "Mirando qué tenés")
        case .composing: String(localized: "Probando combinaciones")
        case .balancing: String(localized: "Equilibrando la nutrición")
        case .ready:     String(localized: "Listo")
        }
    }

    var progress: Double {
        switch self {
        case .reading:   0.2
        case .composing: 0.6
        case .balancing: 0.85
        case .ready:     1.0
        }
    }
}

enum GenerationError: LocalizedError {
    case notEnoughIngredients(minimum: Int)
    case limitReached
    case moderationRejected
    case offline

    var errorDescription: String? {
        switch self {
        case .notEnoughIngredients(let minimum):
            String(localized: "Necesitamos al menos \(minimum) ingredientes para proponerte algo bueno.")
        case .limitReached:
            String(localized: "Llegaste al límite de recetas con IA de hoy.")
        case .moderationRejected:
            String(localized: "No pudimos generar una receta segura con esos ingredientes.")
        case .offline:
            String(localized: "Necesitás conexión para generar recetas nuevas.")
        }
    }
}

// MARK: - Mock

struct MockRecipeGenerator: RecipeGenerating {

    func generate(
        from pantry: [Ingredient],
        preferences: GenerationPreferences
    ) -> AsyncThrowingStream<GenerationPhase, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard pantry.count >= 3 else {
                        throw GenerationError.notEnoughIngredients(minimum: 3)
                    }

                    continuation.yield(.reading)
                    try await Task.sleep(for: .milliseconds(700))

                    continuation.yield(.composing)
                    try await Task.sleep(for: .milliseconds(1_100))

                    continuation.yield(.balancing)
                    try await Task.sleep(for: .milliseconds(650))

                    var recipes = SampleData.generatedRecipes(for: pantry)

                    // Se respetan los filtros de tiempo y etiquetas que pidió el usuario.
                    if let maxMinutes = preferences.maxMinutes {
                        recipes = recipes.filter { $0.minutes <= maxMinutes }
                    }
                    if !preferences.tags.isEmpty {
                        recipes = recipes.filter { !Set($0.tags).isDisjoint(with: preferences.tags) }
                    }
                    // Las exclusiones dietarias son un filtro duro, nunca una "preferencia".
                    if !preferences.exclusions.isEmpty {
                        recipes = recipes.filter { recipe in
                            let names = Set(recipe.ingredients.map { $0.name.lowercased() })
                            return names.isDisjoint(with: preferences.exclusions.map { $0.lowercased() })
                        }
                    }

                    try Task.checkCancellation()
                    continuation.yield(.ready(recipes))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
