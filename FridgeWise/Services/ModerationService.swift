//
//  ModerationService.swift
//  FridgeWise
//
//  Las cuatro obligaciones de la Guideline 1.2 (UGC), implementadas:
//    1. Filtro previo a publicar        → `screen(_:)`
//    2. Reportar contenido              → `report(_:)`, respuesta < 24 h
//    3. Bloquear usuarios abusivos      → `block(_:)` / `isBlocked(_:)`
//    4. Contacto publicado              → `SupportContact`
//
//  El filtro local es la primera línea, no la única: en producción la decisión
//  final la toma el backend. Filtrar sólo en el cliente es trivial de eludir,
//  pero filtrar en el cliente igual sirve para dar feedback instantáneo al autor
//  antes de que apriete "publicar".
//

import Foundation

@MainActor
@Observable
final class ModerationService {

    // MARK: Estado local

    private(set) var blockedAuthorIDs: Set<CommunityAuthor.ID> = []
    private(set) var reportedReviewIDs: Set<Review.ID> = []
    private(set) var submittedReports: [ContentReport] = []

    // MARK: Filtro previo

    enum ScreenResult: Equatable {
        case clean
        /// Se publica pero queda marcado para revisión humana.
        case flagged(reason: String)
        /// Se rechaza en el cliente: el autor ve por qué y puede editar.
        case blocked(reason: String)

        /// `.flagged` SÍ publica: queda visible para su autor y va a la cola de
        /// revisión. Sólo `.blocked` corta la publicación.
        var canPublish: Bool {
            if case .blocked = self { return false }
            return true
        }

        var advisory: String? {
            switch self {
            case .clean:                 nil
            case .flagged(let reason):   reason
            case .blocked(let reason):   reason
            }
        }
    }

    /// Términos que rechazan la publicación de plano.
    /// En producción esto vive en el servidor y se actualiza sin release.
    private let hardBlockTerms: Set<String> = [
        // Placeholder: la lista real de insultos/odio se carga remota.
        "__slur_placeholder__"
    ]

    /// Patrones que marcan para revisión: enlaces, contacto, promoción.
    private let flagPatterns: [(pattern: String, reason: String)] = [
        ("https?://", String(localized: "Contiene un enlace externo")),
        ("@[A-Za-z0-9_]{3,}", String(localized: "Menciona una cuenta externa")),
        ("[0-9]{7,}", String(localized: "Parece incluir un teléfono"))
    ]

    /// Consejos de seguridad alimentaria peligrosos. Es el riesgo propio de
    /// nuestro dominio y merece su propia lista.
    private let unsafeAdvicePatterns: [String] = [
        "(?i)pollo\\s+(crudo|rosado|poco\\s+cocido)",
        "(?i)(descongelar|descongelá).{0,20}(sol|mostrador|ventana)",
        "(?i)re-?congelar.{0,15}(carne|pollo|pescado)",
        "(?i)conservas?\\s+caseras?.{0,25}sin\\s+esterilizar"
    ]

    func screen(_ text: String) -> ScreenResult {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                      locale: .current)

        for term in hardBlockTerms where normalized.contains(term) {
            return .blocked(reason: String(localized: "Este texto incluye lenguaje que no permitimos."))
        }

        for rule in unsafeAdvicePatterns {
            if text.range(of: rule, options: .regularExpression) != nil {
                return .flagged(reason: String(localized: "Puede describir una práctica insegura con alimentos. Un moderador lo revisa antes de que sea público."))
            }
        }

        for rule in flagPatterns {
            if text.range(of: rule.pattern, options: .regularExpression) != nil {
                return .flagged(reason: rule.reason)
            }
        }

        return .clean
    }

    // MARK: Reportar

    func report(_ review: Review, reason: ReportReason, note: String?) -> ContentReport {
        let report = ContentReport(
            reviewID: review.id,
            authorID: review.author.id,
            reason: reason,
            note: note
        )
        submittedReports.append(report)
        reportedReviewIDs.insert(review.id)
        // En producción: POST al backend de moderación. El compromiso publicado
        // es actuar dentro de las 24 h; el contenido reportado se oculta para
        // quien lo reportó de inmediato.
        return report
    }

    func hasReported(_ review: Review) -> Bool {
        reportedReviewIDs.contains(review.id)
    }

    // MARK: Bloquear

    func block(_ author: CommunityAuthor) {
        blockedAuthorIDs.insert(author.id)
    }

    func unblock(_ authorID: CommunityAuthor.ID) {
        blockedAuthorIDs.remove(authorID)
    }

    func isBlocked(_ author: CommunityAuthor) -> Bool {
        blockedAuthorIDs.contains(author.id)
    }

    /// Filtro que aplica todo lo anterior de una sola pasada.
    /// Toda lista de comentarios de la app pasa por acá.
    func visible(_ reviews: [Review]) -> [Review] {
        reviews.filter { review in
            guard review.moderation.isVisibleToOthers else { return false }
            guard !blockedAuthorIDs.contains(review.author.id) else { return false }
            guard !reportedReviewIDs.contains(review.id) else { return false }
            return true
        }
    }

    // MARK: Persistencia

    struct Snapshot: Codable, Sendable {
        var blockedAuthorIDs: [UUID]
        var reportedReviewIDs: [UUID]
    }

    func snapshot() -> Snapshot {
        Snapshot(blockedAuthorIDs: Array(blockedAuthorIDs),
                 reportedReviewIDs: Array(reportedReviewIDs))
    }

    func restore(from snapshot: Snapshot) {
        blockedAuthorIDs = Set(snapshot.blockedAuthorIDs)
        reportedReviewIDs = Set(snapshot.reportedReviewIDs)
    }
}

// MARK: - Contacto

/// Guideline 1.2 exige datos de contacto publicados y alcanzables.
/// Se muestran en Ajustes y en la hoja de reporte.
enum SupportContact {
    static let email = "hola@fridgewise.app"
    static let moderationEmail = "moderacion@fridgewise.app"
    static let privacyURL = URL(string: "https://fridgewise.app/privacidad")!
    static let termsURL = URL(string: "https://fridgewise.app/terminos")!
    static let guidelinesURL = URL(string: "https://fridgewise.app/normas-comunidad")!
    /// EULA estándar de Apple, requerido si no se usa uno propio.
    static let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static let moderationSLA = String(
        localized: "Revisamos todo reporte en menos de 24 horas y retiramos lo que incumpla nuestras normas."
    )
}
