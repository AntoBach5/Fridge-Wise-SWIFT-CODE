//
//  CommunityModels.swift
//  FridgeWise
//
//  Contenido generado por usuarios.
//
//  IMPORTANTE — App Store Review Guideline 1.2 (User-Generated Content):
//  una app con UGC DEBE tener las cuatro cosas, o la rechazan:
//    1. Filtro de contenido objetable antes de publicar.
//    2. Mecanismo para REPORTAR contenido, con respuesta oportuna.
//    3. Mecanismo para BLOQUEAR usuarios abusivos.
//    4. Datos de contacto publicados para que los usuarios lleguen al equipo.
//  Los modelos de este archivo existen para hacer que esas cuatro sean
//  imposibles de "olvidar" al construir la UI.
//

import SwiftUI

// MARK: - Autor

struct CommunityAuthor: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var displayName: String
    var initials: String
    var accent: AccentFamily
    /// Cocinó y publicó lo suficiente para tener insignia.
    var isVerifiedCook: Bool = false
    var recipesPublished: Int = 0
}

// MARK: - Estado de moderación

enum ModerationState: String, Codable, Sendable {
    /// Visible normalmente.
    case published
    /// El filtro automático lo marcó; visible solo para su autor mientras se revisa.
    case underReview
    /// Retirado por moderación.
    case removed
    /// El usuario local bloqueó al autor: se oculta en este dispositivo.
    case hiddenByUser

    var isVisibleToOthers: Bool { self == .published }
}

// MARK: - Comentario / valoración

struct Review: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var recipeID: Recipe.ID
    var author: CommunityAuthor
    var rating: Int              // 1...5
    var body: String
    var createdAt: Date
    var helpfulCount: Int = 0
    var didMarkHelpful: Bool = false
    var moderation: ModerationState = .published

    /// El autor adjuntó una foto de su plato.
    var hasPhoto: Bool = false

    /// Nota puesta por el propio autor: "lo hice sin lácteos", etc.
    var variationNote: String?

    var relativeDate: String {
        createdAt.formatted(.relative(presentation: .named))
    }
}

// MARK: - Reporte

/// Motivos de reporte. La lista está pensada para una app de comida:
/// además de los clásicos, incluye "consejo peligroso", que es el riesgo
/// específico de nuestro dominio (seguridad alimentaria, alérgenos).
enum ReportReason: String, CaseIterable, Identifiable, Codable, Sendable {
    case spam
    case offensive
    case harassment
    case unsafeAdvice
    case misinformation
    case intellectualProperty
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam:                 String(localized: "Spam o publicidad")
        case .offensive:            String(localized: "Contenido ofensivo")
        case .harassment:           String(localized: "Acoso o ataque personal")
        case .unsafeAdvice:         String(localized: "Consejo peligroso o insalubre")
        case .misinformation:       String(localized: "Información nutricional falsa")
        case .intellectualProperty: String(localized: "Copia sin permiso")
        case .other:                String(localized: "Otro motivo")
        }
    }

    var detail: String {
        switch self {
        case .spam:                 String(localized: "Promociona un producto o enlaza fuera de la app.")
        case .offensive:            String(localized: "Lenguaje de odio, violento o sexual.")
        case .harassment:           String(localized: "Se dirige a una persona para hostigarla.")
        case .unsafeAdvice:         String(localized: "Puede provocar intoxicación o una reacción alérgica.")
        case .misinformation:       String(localized: "Declara datos nutricionales o médicos falsos.")
        case .intellectualProperty: String(localized: "Reproduce una receta o foto ajena sin crédito.")
        case .other:                String(localized: "Cuéntanos qué pasa y lo revisamos.")
        }
    }

    var icon: String {
        switch self {
        case .spam:                 "megaphone"
        case .offensive:            "exclamationmark.bubble"
        case .harassment:           "person.crop.circle.badge.exclamationmark"
        case .unsafeAdvice:         "cross.case"
        case .misinformation:       "info.circle"
        case .intellectualProperty: "doc.on.doc"
        case .other:                "ellipsis.circle"
        }
    }
}

struct ContentReport: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var reviewID: Review.ID
    var authorID: CommunityAuthor.ID
    var reason: ReportReason
    var note: String?
    var submittedAt: Date = .now
    /// Compromiso público: revisamos en menos de 24 h y actuamos.
    var acknowledgementDeadline: Date {
        submittedAt.addingTimeInterval(24 * 3600)
    }
}

// MARK: - Términos

/// Guideline 1.2 pide un EULA que el usuario acepte antes de participar,
/// con tolerancia cero al contenido abusivo. Guardamos versión + fecha
/// para poder volver a pedir aceptación cuando cambien los términos.
struct CommunityAgreement: Codable, Sendable, Equatable {
    var acceptedVersion: Int?
    var acceptedAt: Date?

    static let currentVersion = 1

    var needsAcceptance: Bool {
        acceptedVersion != Self.currentVersion
    }
}
