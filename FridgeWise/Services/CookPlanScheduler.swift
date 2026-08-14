//
//  CookPlanScheduler.swift
//  FridgeWise
//
//  Recordatorios locales para las recetas agendadas.
//
//  Reglas que se respetan aquí y no son negociables:
//
//  1. El permiso se pide en el momento en que el usuario agenda algo, nunca al
//     abrir la app. Pedirlo en frío es la forma más rápida de que te lo nieguen
//     para siempre, y iOS solo deja preguntar una vez.
//  2. Si el usuario dice que no, el plan se guarda igual. La app funciona sin
//     notificaciones; simplemente no avisa.
//  3. Nada de notificaciones de marketing por este canal. Solo lo que el usuario
//     agendó explícitamente. Guideline 4.5.4: las push promocionales requieren
//     consentimiento propio y pueden costar el rechazo.
//

import Foundation
import UserNotifications

enum CookPlanScheduler {

    // MARK: - Permiso

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Pide permiso solo si nunca se preguntó. Devuelve si podemos avisar.
    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus

        switch status {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Programar

    /// Programa el aviso del plan. Silencioso si no hay permiso o si la fecha
    /// ya pasó: un recordatorio para ayer no le sirve a nadie.
    static func schedule(_ plan: CookPlan) async {
        guard let remindsAt = plan.remindsAt, remindsAt > .now else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Hoy toca cocinar")
        content.body = plan.recipeTitle
        content.sound = .default
        content.userInfo = ["recipeID": plan.recipeID.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: remindsAt
        )

        let request = UNNotificationRequest(
            identifier: plan.id.uuidString,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel(_ plan: CookPlan) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [plan.id.uuidString])
    }

    static func cancelAll(_ plans: [CookPlan]) async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: plans.map(\.id.uuidString))
    }

    /// Vuelve a programar todo lo pendiente. Se llama al arrancar porque las
    /// notificaciones no sobreviven a reinstalar la app ni a restaurar backup.
    static func resync(_ plans: [CookPlan]) async {
        guard await authorizationStatus() == .authorized else { return }

        let center = UNUserNotificationCenter.current()
        let pending = Set(await center.pendingNotificationRequests().map(\.identifier))

        for plan in plans where !pending.contains(plan.id.uuidString) {
            await schedule(plan)
        }
    }
}
