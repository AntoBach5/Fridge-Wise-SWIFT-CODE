//
//  PointsLedger.swift
//  FridgeWise
//
//  Motor de puntos. Un libro mayor append-only: el saldo siempre es la suma
//  de los asientos, nunca un número suelto que se puede desincronizar.
//
//  Decisiones de producto que están codificadas acá:
//  · La visita diaria acredita UNA vez por día natural, no por sesión.
//    Premiar cada apertura entrena a abrir la app compulsivamente.
//  · Comentar acredita al publicar, pero si el comentario se retira por
//    moderación se revierte. Sin esto, spamear comentarios es farmear puntos.
//  · Los puntos NO expiran, y así se declara en la UI (Guideline 3.1.1).
//

import Foundation

@MainActor
@Observable
final class PointsLedger {

    private(set) var entries: [PointsEntry] = []

    /// Saldo gastable.
    private(set) var balance: Int = 0
    /// Total histórico ganado — define el nivel y nunca baja por canjes.
    private(set) var lifetimeEarned: Int = 0

    /// Beneficios activos comprados con puntos (ej. día sin anuncios).
    private(set) var activeBenefits: [ActiveBenefit] = []

    struct ActiveBenefit: Identifiable, Codable, Sendable, Equatable {
        var id: UUID = UUID()
        var kind: RewardKind
        var title: String
        var expiresAt: Date?
        /// Para beneficios contables (escaneos extra) en lugar de temporales.
        var remainingUses: Int?

        var isActive: Bool {
            if let expiresAt, expiresAt < .now { return false }
            if let remainingUses, remainingUses <= 0 { return false }
            return true
        }
    }

    // MARK: Ganar

    @discardableResult
    func award(_ event: PointsEvent, amount: Int? = nil, note: String? = nil) -> Int {
        let value = amount ?? event.amount
        guard value > 0 else { return 0 }

        // Anti-farmeo: la visita diaria es idempotente por día.
        if event == .dailyOpen, hasEntry(for: .dailyOpen, on: .now) { return 0 }

        let entry = PointsEntry(event: event, amount: value, note: note)
        entries.insert(entry, at: 0)
        balance += value
        lifetimeEarned += value
        return value
    }

    /// Revierte una acreditación (comentario retirado por moderación).
    func revoke(event: PointsEvent, note: String? = nil) {
        guard let index = entries.firstIndex(where: { $0.event == event && $0.note == note }) else { return }
        let removed = entries.remove(at: index)
        balance = max(0, balance - removed.amount)
        lifetimeEarned = max(0, lifetimeEarned - removed.amount)
    }

    // MARK: Gastar

    enum RedeemError: LocalizedError {
        case insufficientPoints(needed: Int)
        case alreadyActive

        var errorDescription: String? {
            switch self {
            case .insufficientPoints(let needed):
                String(localized: "Te faltan \(needed) puntos para este canje.")
            case .alreadyActive:
                String(localized: "Ya tenés este beneficio activo.")
            }
        }
    }

    func redeem(_ reward: Reward) throws {
        guard balance >= reward.cost else {
            throw RedeemError.insufficientPoints(needed: reward.cost - balance)
        }
        if activeBenefits.contains(where: { $0.kind == reward.kind && $0.isActive }),
           reward.kind == .adFreeDay || reward.kind == .premiumTrial {
            throw RedeemError.alreadyActive
        }

        balance -= reward.cost

        let benefit = ActiveBenefit(
            kind: reward.kind,
            title: reward.title,
            expiresAt: reward.durationHours.map { Date().addingTimeInterval(Double($0) * 3600) },
            remainingUses: reward.kind == .extraScans ? 5
                          : (reward.kind == .extraGenerations ? 10 : nil)
        )
        activeBenefits.append(benefit)

        entries.insert(
            PointsEntry(event: .purchased, amount: -reward.cost, note: reward.title),
            at: 0
        )
    }

    /// Consume un uso de un beneficio contable. Devuelve `true` si había cupo.
    @discardableResult
    func consumeBenefit(_ kind: RewardKind) -> Bool {
        guard let index = activeBenefits.firstIndex(where: { $0.kind == kind && $0.isActive }),
              let remaining = activeBenefits[index].remainingUses else { return false }
        activeBenefits[index].remainingUses = remaining - 1
        return true
    }

    func hasActiveBenefit(_ kind: RewardKind) -> Bool {
        activeBenefits.contains { $0.kind == kind && $0.isActive }
    }

    /// Purga beneficios vencidos. Se llama al volver a foreground.
    func pruneExpiredBenefits() {
        activeBenefits.removeAll { !$0.isActive }
    }

    // MARK: Consultas

    func hasEntry(for event: PointsEvent, on date: Date) -> Bool {
        let calendar = Calendar.current
        return entries.contains {
            $0.event == event && calendar.isDate($0.date, inSameDayAs: date)
        }
    }

    /// Puntos ganados por día en los últimos 7 días, normalizados 0...1
    /// para alimentar el sparkline de "ritmo".
    func weeklyRhythm() -> [CGFloat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let dailyTotals: [Int] = (0..<7).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            return entries
                .filter { calendar.isDate($0.date, inSameDayAs: day) && $0.amount > 0 }
                .reduce(0) { $0 + $1.amount }
        }

        let peak = max(dailyTotals.max() ?? 1, 1)
        return dailyTotals.map { CGFloat($0) / CGFloat(peak) }
    }

    // MARK: Persistencia

    struct Snapshot: Codable, Sendable {
        var entries: [PointsEntry]
        var balance: Int
        var lifetimeEarned: Int
        var activeBenefits: [ActiveBenefit]
    }

    func snapshot() -> Snapshot {
        Snapshot(entries: entries, balance: balance,
                 lifetimeEarned: lifetimeEarned, activeBenefits: activeBenefits)
    }

    func restore(from snapshot: Snapshot) {
        entries = snapshot.entries
        balance = snapshot.balance
        lifetimeEarned = snapshot.lifetimeEarned
        activeBenefits = snapshot.activeBenefits
        pruneExpiredBenefits()
    }
}
