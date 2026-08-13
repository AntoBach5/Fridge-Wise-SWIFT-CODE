//
//  StoreService.swift
//  FridgeWise
//
//  StoreKit 2. Cubre las dos economías de la app:
//    · Suscripción auto-renovable  → Premium (menos límites, cero anuncios)
//    · Consumibles                 → packs de puntos
//
//  Reglas de App Store implementadas aquí (no son opcionales):
//  · 3.1.1  Todo se cobra por IAP. No hay ni un link a pagar por fuera.
//  · 3.1.2  Los precios SIEMPRE salen de `product.displayPrice` (localizado y
//           en la moneda del usuario). Nunca se hardcodea un número.
//  · 3.1.2  "Restaurar compras" tiene que existir y ser alcanzable sin cuenta.
//  · 2.1    Los consumibles se entregan ANTES de `finish()`. Si la app se cierra
//           entre el pago y la entrega, `Transaction.updates` la vuelve a entregar.
//

import Foundation
import StoreKit

@MainActor
@Observable
final class StoreService {

    // MARK: Estado

    private(set) var subscriptions: [Product] = []
    private(set) var pointPacks: [Product] = []
    private(set) var isLoadingProducts = false
    private(set) var loadFailed = false

    /// Suscripciones activas verificadas por StoreKit.
    private(set) var activeSubscriptionIDs: Set<String> = []

    var isPremium: Bool { !activeSubscriptionIDs.isEmpty }

    /// Se llama cuando se acredita un consumible. Lo engancha `AppEnvironment`
    /// para sumar puntos: el store no sabe nada de la economía interna.
    var onPointsPurchased: ((Int, String) -> Void)?

    /// `nonisolated(unsafe)` para poder cancelarla desde `deinit`, que no está
    /// aislado al actor. Solo se escribe en `init` y se lee en `deinit`.
    nonisolated(unsafe) private var updatesTask: Task<Void, Never>?

    // MARK: Ciclo de vida

    init() {
        // Escucha transacciones que llegan fuera del flujo de compra:
        // Ask to Buy aprobado, compra hecha en otro dispositivo, reintentos.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: Catálogo

    func loadProducts() async {
        isLoadingProducts = true
        loadFailed = false
        defer { isLoadingProducts = false }

        let subscriptionIDs = PremiumProduct.allCases.map(\.rawValue)
        let packIDs = PointPack.catalog.map(\.id)

        do {
            let products = try await Product.products(for: subscriptionIDs + packIDs)

            subscriptions = products
                .filter { $0.type == .autoRenewable }
                .sorted { $0.price < $1.price }

            pointPacks = products
                .filter { $0.type == .consumable }
                .sorted { $0.price < $1.price }

            await refreshEntitlements()
        } catch {
            loadFailed = true
        }
    }

    // MARK: Compra

    enum PurchaseOutcome {
        case success
        case pending        // Ask to Buy / SCA: la UI debe explicar que falta aprobación
        case cancelled
        case failedVerification
    }

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                return .failedVerification
            }
            await deliver(transaction)
            await transaction.finish()
            await refreshEntitlements()
            return .success

        case .pending:
            return .pending

        case .userCancelled:
            return .cancelled

        @unknown default:
            return .cancelled
        }
    }

    /// Guideline 3.1.2: obligatorio y visible. Sin esto hay rechazo automático.
    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: Entitlements

    func refreshEntitlements() async {
        var active: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < .now { continue }
            if transaction.productType == .autoRenewable {
                active.insert(transaction.productID)
            }
        }

        activeSubscriptionIDs = active
    }

    // MARK: Entrega

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await deliver(transaction)
        await transaction.finish()
        await refreshEntitlements()
    }

    /// Acredita el contenido. Los consumibles se entregan aquí y solo aquí,
    /// así una transacción recuperada al reabrir la app también acredita.
    private func deliver(_ transaction: Transaction) async {
        guard transaction.productType == .consumable else { return }
        guard let pack = PointPack.catalog.first(where: { $0.id == transaction.productID }) else { return }
        onPointsPurchased?(pack.points, pack.title)
    }

    // MARK: Presentación

    /// Texto de renovación exigido por 3.1.2, armado con datos reales del producto.
    func renewalDisclosure(for product: Product) -> String {
        guard let subscription = product.subscription else { return "" }
        let unit: String = switch subscription.subscriptionPeriod.unit {
        case .day:   String(localized: "día")
        case .week:  String(localized: "semana")
        case .month: String(localized: "mes")
        case .year:  String(localized: "año")
        @unknown default: String(localized: "período")
        }
        return String(
            localized: "\(product.displayPrice) por \(unit). Se renueva automáticamente hasta que la canceles desde los Ajustes de tu Apple Account."
        )
    }

    /// Precio por mes para poder mostrar el ahorro del plan anual de forma honesta.
    func monthlyEquivalent(for product: Product) -> String? {
        guard let subscription = product.subscription,
              subscription.subscriptionPeriod.unit == .year else { return nil }
        let monthly = product.price / 12
        return monthly.formatted(.currency(code: product.priceFormatStyle.currencyCode))
    }

    func introductoryOffer(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer else { return nil }
        let period = offer.period
        let count = period.value
        let unitName: String = switch period.unit {
        case .day:   count == 1 ? String(localized: "día") : String(localized: "días")
        case .week:  count == 1 ? String(localized: "semana") : String(localized: "semanas")
        case .month: count == 1 ? String(localized: "mes") : String(localized: "meses")
        case .year:  count == 1 ? String(localized: "año") : String(localized: "años")
        @unknown default: String(localized: "período")
        }

        return switch offer.paymentMode {
        case .freeTrial: String(localized: "\(count) \(unitName) gratis")
        case .payAsYouGo: String(localized: "\(offer.displayPrice) por \(count) \(unitName)")
        case .payUpFront: String(localized: "\(offer.displayPrice) los primeros \(count) \(unitName)")
        default: nil
        }
    }
}
