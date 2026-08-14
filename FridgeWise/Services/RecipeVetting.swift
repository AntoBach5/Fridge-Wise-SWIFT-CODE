//
//  RecipeVetting.swift
//  FridgeWise
//
//  Revisión automática de las recetas que escribe un usuario antes de publicarlas.
//
//  Qué NO es esto: un filtro de groserías. De eso se encarga `ModerationService`,
//  que corre igual y en paralelo. Esto comprueba que lo que se va a publicar sea
//  una receta de verdad — que tenga ingredientes, que los pasos los usen, que los
//  tiempos sean plausibles y que no explique cómo intoxicar a alguien.
//
//  Por qué importa: una comunidad se muere el día que se llena de "receta: poner
//  cosas en la olla". Y en una app de comida, un paso mal escrito sobre pollo
//  crudo no es contenido de baja calidad, es un riesgo real (Guideline 1.4.1).
//
//  El modelo real va después. El contrato — qué se comprueba y qué se devuelve —
//  es el definitivo, y está pensado para que un LLM pueda rellenarlo tal cual.
//

import Foundation

// MARK: - Borrador

/// Lo que el usuario escribió, antes de convertirse en `Recipe`.
struct RecipeDraft: Sendable, Equatable {
    var title: String = ""
    var subtitle: String = ""
    var minutes: Int = 30
    var servings: Int = 2
    var difficulty: Int = 1
    var ingredients: [DraftIngredient] = []
    var steps: [DraftStep] = []
    var tags: Set<RecipeTag> = []
    var allergens: String = ""

    struct DraftIngredient: Identifiable, Sendable, Equatable {
        var id: UUID = UUID()
        var name: String = ""
        var amount: String = ""
    }

    /// Los pasos llevan id propio en vez de indexarse por posición: al borrar
    /// una fila del medio, un binding por índice apunta un instante a la fila
    /// equivocada y SwiftUI puede caerse.
    struct DraftStep: Identifiable, Sendable, Equatable {
        var id: UUID = UUID()
        var text: String = ""
    }

    var cleanIngredients: [DraftIngredient] {
        ingredients.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var cleanSteps: [String] {
        steps.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Veredicto

enum RecipeVerdict: Sendable, Equatable {
    /// Se puede publicar tal cual.
    case looksGood
    /// Se puede publicar, pero hay cosas que conviene arreglar antes.
    case needsWork([String])
    /// No se publica. La razón se le enseña al usuario tal cual.
    case rejected(String)

    var canPublish: Bool {
        if case .rejected = self { return false }
        return true
    }
}

protocol RecipeVetting: Sendable {
    func vet(_ draft: RecipeDraft) async -> RecipeVerdict
}

// MARK: - Implementación local

struct HeuristicRecipeVetter: RecipeVetting {

    /// Prácticas que pueden acabar en una intoxicación. Se bloquean, no se avisan:
    /// que alguien las lea en una receta publicada es exactamente el escenario malo.
    private static let unsafePatterns: [(pattern: String, reason: String)] = [
        ("pollo.{0,25}(crudo|rosado|poco hecho|sangrando)",
         String(localized: "Describe pollo sin cocinar del todo.")),
        ("(descongel|descongelar).{0,25}(al sol|encimera|temperatura ambiente|ventana)",
         String(localized: "Descongelar fuera de la nevera favorece la salmonela.")),
        ("(recongelar|volver a congelar).{0,20}(carne|pescado|pollo)",
         String(localized: "Recongelar carne descongelada no es seguro.")),
        ("conserva.{0,30}(sin esterilizar|sin hervir)",
         String(localized: "Una conserva sin esterilizar puede provocar botulismo.")),
        ("(huevo|huevos).{0,25}(caducad|pasado|roto hace)",
         String(localized: "Usar huevos caducados es un riesgo innecesario.")),
        ("moho.{0,25}(quitar|raspar|igual)",
         String(localized: "Raspar el moho no lo elimina del alimento."))
    ]

    private static let spamPatterns = [
        "https?://", "www\\.", "@[a-z0-9_]{3,}", "\\b\\d{9,}\\b"
    ]

    func vet(_ draft: RecipeDraft) async -> RecipeVerdict {
        // El modelo real tardará algo; la UI ya está preparada para esperar.
        try? await Task.sleep(for: .milliseconds(900))

        let ingredients = draft.cleanIngredients
        let steps = draft.cleanSteps
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)

        // --- Rechazos duros ---

        guard title.count >= 4 else {
            return .rejected(String(localized: "El título es demasiado corto para saber qué es."))
        }
        guard ingredients.count >= 2 else {
            return .rejected(String(localized: "Una receta necesita al menos dos ingredientes."))
        }
        guard steps.count >= 2 else {
            return .rejected(String(localized: "Hacen falta al menos dos pasos para que alguien pueda seguirla."))
        }

        let haystack = normalize(
            ([title, draft.subtitle] + steps + ingredients.map(\.name)).joined(separator: " ")
        )

        for rule in Self.unsafePatterns where matches(rule.pattern, in: haystack) {
            return .rejected(String(localized: "Seguridad alimentaria: \(rule.reason) Corrige ese paso antes de publicar."))
        }

        for pattern in Self.spamPatterns where matches(pattern, in: haystack) {
            return .rejected(String(localized: "No se pueden publicar enlaces, menciones ni teléfonos dentro de una receta."))
        }

        // --- Avisos ---

        var warnings: [String] = []

        // El corazón de la comprobación: ¿los pasos usan lo que se listó?
        let stepText = normalize(steps.joined(separator: " "))
        let unused = ingredients.filter { ingredient in
            let name = normalize(ingredient.name)
            guard name.count > 2 else { return false }
            return !stepText.contains(name)
        }
        if unused.count > ingredients.count / 2 {
            warnings.append(String(localized: "Los pasos apenas mencionan los ingredientes que listaste."))
        } else if let first = unused.first, unused.count == 1 {
            warnings.append(String(localized: "«\(first.name)» está en la lista pero no aparece en ningún paso."))
        } else if unused.count > 1 {
            warnings.append(String(localized: "\(unused.count) ingredientes no aparecen en ningún paso."))
        }

        if ingredients.contains(where: { $0.amount.trimmingCharacters(in: .whitespaces).isEmpty }) {
            warnings.append(String(localized: "Falta la cantidad en algún ingrediente. Sin medidas cuesta seguir la receta."))
        }

        if draft.minutes < 3 {
            warnings.append(String(localized: "Menos de tres minutos suena optimista para \(steps.count) pasos."))
        } else if draft.minutes > 480 {
            warnings.append(String(localized: "Más de ocho horas: si es una fermentación, dilo en los pasos."))
        }

        if steps.contains(where: { $0.count < 12 }) {
            warnings.append(String(localized: "Hay pasos de una o dos palabras. Cuenta un poco más qué hacer."))
        }

        if draft.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append(String(localized: "Sin una frase de presentación la receta se ve vacía en el feed."))
        }

        return warnings.isEmpty ? .looksGood : .needsWork(warnings)
    }

    // MARK: - Utilidades

    private func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func matches(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression]) != nil
    }
}
