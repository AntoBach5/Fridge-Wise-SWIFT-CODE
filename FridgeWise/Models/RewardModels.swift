//
//  RewardModels.swift
//  FridgeWise
//
//  Gamificación y economía de puntos.
//
//  IMPORTANTE — Reglas de App Store que condicionan este diseño:
//  · Guideline 3.1.1: los puntos son moneda virtual CONSUMIBLE. Se compran solo
//    con In-App Purchase, nunca con un cobro externo. No se pueden transferir
//    entre usuarios ni canjear por dinero o bienes físicos.
//  · Guideline 3.1.1: hay que informar si expiran. Aquí NO expiran, y se dice.
//  · Guideline 3.1.2: la suscripción premium debe declarar duración, precio y
//    renovación automática ANTES de comprar, con enlaces a Términos y Privacidad.
//  · Guideline 3.2.2: nada de loot boxes ni ruleta de recompensas.
//    Todo canje muestra el costo exacto por adelantado.
//

import SwiftUI

// MARK: - Cómo se ganan puntos

enum PointsEvent: String, Codable, CaseIterable, Identifiable, Sendable {
    case dailyOpen          // abrir la app en un día nuevo
    case streakMilestone    // 7, 30, 100 días seguidos
    case scanCompleted
    case recipeCooked       // marcó una receta como cocinada
    case reviewPosted       // dejó un comentario con valoración
    case reviewFoundHelpful // su comentario recibió "útil"
    case recipeShared
    case recipePublished    // publicó una receta suya en la comunidad
    case pantryTidied       // confirmó/corrigió detecciones
    case purchased          // pack comprado con IAP

    var id: String { rawValue }

    var amount: Int {
        switch self {
        case .dailyOpen:          5
        case .streakMilestone:    75
        case .scanCompleted:      10
        case .recipeCooked:       25
        case .reviewPosted:       20
        case .reviewFoundHelpful: 8
        case .recipeShared:       12
        case .recipePublished:    40
        case .pantryTidied:       6
        case .purchased:          0     // el monto lo define el pack
        }
    }

    var title: String {
        switch self {
        case .dailyOpen:          String(localized: "Visita diaria")
        case .streakMilestone:    String(localized: "Racha alcanzada")
        case .scanCompleted:      String(localized: "Nevera escaneada")
        case .recipeCooked:       String(localized: "Receta cocinada")
        case .reviewPosted:       String(localized: "Comentario publicado")
        case .reviewFoundHelpful: String(localized: "Tu comentario fue útil")
        case .recipeShared:       String(localized: "Receta compartida")
        case .recipePublished:    String(localized: "Receta publicada")
        case .pantryTidied:       String(localized: "Despensa ordenada")
        case .purchased:          String(localized: "Pack de puntos")
        }
    }

    var icon: String {
        switch self {
        case .dailyOpen:          "sun.max"
        case .streakMilestone:    "flame"
        case .scanCompleted:      "viewfinder"
        case .recipeCooked:       "frying.pan"
        case .reviewPosted:       "bubble.left"
        case .reviewFoundHelpful: "hand.thumbsup"
        case .recipeShared:       "square.and.arrow.up"
        case .recipePublished:    "paperplane"
        case .pantryTidied:       "sparkles"
        case .purchased:          "creditcard"
        }
    }

    var accent: AccentFamily {
        switch self {
        case .dailyOpen, .streakMilestone: .turmeric
        case .scanCompleted, .pantryTidied: .mist
        case .recipeCooked:                 .basil
        case .reviewPosted, .reviewFoundHelpful, .recipeShared, .recipePublished: .plum
        case .purchased:                    .clay
        }
    }
}

struct PointsEntry: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var event: PointsEvent
    var amount: Int
    var date: Date = .now
    var note: String?
}

// MARK: - Canjes

/// Catálogo de canje. Todo lo que hay aquí es contenido o funcionalidad DIGITAL
/// dentro de la app: no hay bienes físicos, sorteos ni dinero.
enum RewardKind: String, Codable, Sendable {
    case adFreeDay
    case extraScans
    case extraGenerations
    case chefMode
    case collection
    case premiumTrial
}

struct Reward: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var kind: RewardKind
    var title: String
    var detail: String
    var cost: Int
    var icon: String
    var accent: AccentFamily
    /// Cuánto dura el beneficio, en horas. `nil` = permanente.
    var durationHours: Int?
    var isFeatured: Bool = false
}

// MARK: - Packs de puntos (IAP consumible)

/// Un pack por producto de App Store Connect. El precio NUNCA se hardcodea:
/// se lee de `Product.displayPrice` de StoreKit, que ya viene localizado
/// y en la moneda correcta del usuario. Hardcodear precios es rechazo seguro.
struct PointPack: Identifiable, Hashable, Sendable {
    var id: String                  // product identifier
    var points: Int
    var title: String
    var bonusLabel: String?         // "+15% extra"
    var accent: AccentFamily
    var isBestValue: Bool = false

    static let catalog: [PointPack] = [
        PointPack(id: "com.fridgewise.points.small",
                  points: 500, title: String(localized: "Puñado"),
                  bonusLabel: nil, accent: .sage),
        PointPack(id: "com.fridgewise.points.medium",
                  points: 1_500, title: String(localized: "Bolsa"),
                  bonusLabel: String(localized: "+10% extra"), accent: .turmeric),
        PointPack(id: "com.fridgewise.points.large",
                  points: 4_000, title: String(localized: "Despensa"),
                  bonusLabel: String(localized: "+25% extra"), accent: .clay,
                  isBestValue: true),
        PointPack(id: "com.fridgewise.points.huge",
                  points: 10_000, title: String(localized: "Cosecha"),
                  bonusLabel: String(localized: "+40% extra"), accent: .tomato)
    ]
}

// MARK: - Racha y nivel

struct CookStreak: Codable, Sendable, Equatable {
    var currentDays: Int = 0
    var bestDays: Int = 0
    var lastActiveDay: Date?

    /// Milestones que otorgan puntos. Deliberadamente espaciados: nada de
    /// recompensar cada día para no empujar uso compulsivo.
    static let milestones = [7, 30, 100, 365]

    var nextMilestone: Int? {
        Self.milestones.first { $0 > currentDays }
    }

    var progressToNextMilestone: Double {
        guard let next = nextMilestone else { return 1 }
        let previous = Self.milestones.last { $0 <= currentDays } ?? 0
        let span = Double(next - previous)
        guard span > 0 else { return 1 }
        return Double(currentDays - previous) / span
    }
}

/// Nivel de cocina. Nombres con voz propia, no "Nivel 4".
enum CookLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case aprendiz = 0, curioso, cocinero, artesano, maestro

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .aprendiz: String(localized: "Aprendiz")
        case .curioso:  String(localized: "Curioso")
        case .cocinero: String(localized: "Cocinero")
        case .artesano: String(localized: "Artesano")
        case .maestro:  String(localized: "Maestro")
        }
    }

    var threshold: Int {
        switch self {
        case .aprendiz: 0
        case .curioso:  250
        case .cocinero: 1_000
        case .artesano: 3_000
        case .maestro:  8_000
        }
    }

    var accent: AccentFamily {
        switch self {
        case .aprendiz: .sage
        case .curioso:  .mist
        case .cocinero: .basil
        case .artesano: .turmeric
        case .maestro:  .clay
        }
    }

    static func level(forLifetimePoints points: Int) -> CookLevel {
        allCases.last { points >= $0.threshold } ?? .aprendiz
    }

    var next: CookLevel? {
        CookLevel(rawValue: rawValue + 1)
    }
}
