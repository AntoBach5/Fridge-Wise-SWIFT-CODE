//
//  CookPlan.swift
//  FridgeWise
//
//  Una receta agendada para un día concreto.
//
//  Se guarda aparte de `ListItem` a propósito. La lista "To Cook" es una cola
//  sin fecha — cosas que quiero cocinar en algún momento. Un plan es un
//  compromiso con un día, y eso es lo que justifica mandar una notificación.
//  Mezclarlos haría que cualquier cosa añadida a la lista pidiera permiso de
//  notificaciones, que es exactamente cómo se pierde ese permiso.
//

import Foundation

struct CookPlan: Identifiable, Codable, Hashable, Sendable {

    var id: UUID = UUID()
    var recipeID: Recipe.ID
    var recipeTitle: String

    /// Día para el que se planificó, normalizado al inicio del día.
    var day: Date

    /// Hora exacta del recordatorio. `nil` = el usuario no quiso aviso.
    var remindsAt: Date?

    var createdAt: Date = .now

    init(
        id: UUID = UUID(),
        recipeID: Recipe.ID,
        recipeTitle: String,
        day: Date,
        remindsAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.day = Calendar.current.startOfDay(for: day)
        self.remindsAt = remindsAt
        self.createdAt = createdAt
    }

    var isPast: Bool {
        day < Calendar.current.startOfDay(for: .now)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(day)
    }

    /// Hora por defecto del aviso: 11:00 del día planificado. Suficientemente
    /// temprano para pasar por el súper, suficientemente tarde para no despertar.
    static func defaultReminder(for day: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: 11, minute: 0, second: 0,
            of: calendar.startOfDay(for: day)
        ) ?? day
    }
}
