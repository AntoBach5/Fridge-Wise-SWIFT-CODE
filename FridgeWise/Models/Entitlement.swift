//
//  Entitlement.swift
//  FridgeWise
//
//  Modelo freemium.
//
//  Filosofía del límite: el plan gratuito tiene que ser USABLE, no mutilado.
//  Apple rechaza apps donde la versión gratis es una demo disfrazada, y los
//  usuarios desinstalan apps que se sienten un rehén. Los límites de aquí son
//  generosos y se comunican ANTES de que el usuario invierta esfuerzo, nunca
//  después de que sacó la foto.
//

import Foundation

// MARK: - Plan

enum Plan: String, Codable, Sendable {
    case free
    case premium

    var title: String {
        switch self {
        case .free:    String(localized: "Fridge Wise")
        case .premium: String(localized: "Fridge Wise Premium")
        }
    }
}

// MARK: - Límites

/// Cuotas del plan gratuito. En un único lugar para que producto pueda
/// ajustarlas sin tocar la UI, y para que la pantalla de límites siempre
/// muestre exactamente el mismo número que aplica el motor.
struct PlanLimits: Sendable, Equatable {
    var scansPerDay: Int
    var aiGenerationsPerDay: Int
    var savedRecipes: Int
    var listItems: Int
    var showsAds: Bool

    static let free = PlanLimits(
        scansPerDay: 3,
        aiGenerationsPerDay: 5,
        savedRecipes: 30,
        listItems: 50,
        showsAds: true
    )

    static let premium = PlanLimits(
        scansPerDay: .max,
        aiGenerationsPerDay: .max,
        savedRecipes: .max,
        listItems: .max,
        showsAds: false
    )

    static func limits(for plan: Plan) -> PlanLimits {
        plan == .premium ? .premium : .free
    }
}

/// Recurso limitado. Nombrarlos como enum evita que la UI y el motor
/// se desincronicen sobre qué se está contando.
enum MeteredResource: String, CaseIterable, Sendable {
    case scan, aiGeneration, savedRecipe, listItem

    var title: String {
        switch self {
        case .scan:         String(localized: "Escaneos")
        case .aiGeneration: String(localized: "Recetas con IA")
        case .savedRecipe:  String(localized: "Recetas guardadas")
        case .listItem:     String(localized: "Ítems en listas")
        }
    }

    var icon: String {
        switch self {
        case .scan:         "viewfinder"
        case .aiGeneration: "sparkles"
        case .savedRecipe:  "bookmark"
        case .listItem:     "checklist"
        }
    }

    /// Se reinicia todos los días a medianoche (vs. tope acumulado).
    var isDaily: Bool {
        switch self {
        case .scan, .aiGeneration: true
        case .savedRecipe, .listItem: false
        }
    }

    func limit(under limits: PlanLimits) -> Int {
        switch self {
        case .scan:         limits.scansPerDay
        case .aiGeneration: limits.aiGenerationsPerDay
        case .savedRecipe:  limits.savedRecipes
        case .listItem:     limits.listItems
        }
    }
}

// MARK: - Suscripción premium

/// Identificadores de producto. Deben coincidir exactamente con App Store Connect.
enum PremiumProduct: String, CaseIterable, Identifiable, Sendable {
    case monthly = "com.fridgewise.premium.monthly"
    case yearly  = "com.fridgewise.premium.yearly"

    var id: String { rawValue }

    var periodLabel: String {
        switch self {
        case .monthly: String(localized: "Mensual")
        case .yearly:  String(localized: "Anual")
        }
    }

    /// Texto de renovación obligatorio (Guideline 3.1.2). El precio real
    /// lo pone StoreKit; aquí solo describimos la cadencia.
    var renewalDisclosure: String {
        switch self {
        case .monthly:
            String(localized: "Se renueva automáticamente cada mes hasta que la canceles.")
        case .yearly:
            String(localized: "Se renueva automáticamente cada año hasta que la canceles.")
        }
    }
}

// MARK: - Perfil

struct UserProfile: Codable, Sendable, Equatable {
    var displayName: String = String(localized: "Cocinero")
    var initials: String = "FW"
    var accent: AccentFamily = .sage

    var plan: Plan = .free
    var lifetimePoints: Int = 0
    var pointsBalance: Int = 0
    var streak: CookStreak = CookStreak()
    var agreement: CommunityAgreement = CommunityAgreement()

    /// El usuario respondió el prompt de ATT. `nil` = todavía no se le preguntó.
    var trackingAuthorized: Bool?

    var level: CookLevel { CookLevel.level(forLifetimePoints: lifetimePoints) }

    var progressToNextLevel: Double {
        guard let next = level.next else { return 1 }
        let span = Double(next.threshold - level.threshold)
        guard span > 0 else { return 1 }
        return Double(lifetimePoints - level.threshold) / span
    }

    var pointsToNextLevel: Int {
        guard let next = level.next else { return 0 }
        return max(0, next.threshold - lifetimePoints)
    }

    var isPremium: Bool { plan == .premium }
    var limits: PlanLimits { PlanLimits.limits(for: plan) }
}
