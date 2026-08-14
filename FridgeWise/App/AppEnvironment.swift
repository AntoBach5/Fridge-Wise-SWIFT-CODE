//
//  AppEnvironment.swift
//  FridgeWise
//
//  Estado raíz de la app. Una sola fuente de verdad, inyectada por `@Environment`.
//
//  Todo lo que cambia el mundo pasa por aquí: sumar a una lista, guardar una
//  receta, publicar un comentario, consumir cuota. Las vistas no mutan colecciones
//  por su cuenta — así el metering, los puntos y la persistencia no se pueden
//  "olvidar" en una pantalla nueva.
//

import SwiftUI

@MainActor
@Observable
final class AppEnvironment {

    // MARK: - Servicios

    let ledger = PointsLedger()
    let store = StoreService()
    let moderation = ModerationService()
    let tracking = TrackingConsent()
    let ads = AdCoordinator()
    let persistence = PersistenceStore()

    let scanner: FridgeScanning
    let generator: RecipeGenerating

    // MARK: - Estado de dominio

    var profile = UserProfile()
    var pantry: [Ingredient] = []
    var feed: [Recipe] = []
    var savedRecipeIDs: Set<Recipe.ID> = []
    var listItems: [ListItem] = []
    var reviewsByRecipe: [Recipe.ID: [Review]] = [:]

    /// Última tanda generada. Se mantiene aparte del feed para poder mostrarla
    /// con su propia entrada animada tras el escaneo.
    var lastGeneration: [Recipe] = []

    /// Biblioteca durable: toda receta que el usuario abrió, guardó o publicó.
    ///
    /// Las recetas generadas no viven en ningún servidor — se inventan contra la
    /// despensa del momento. Si no las archivamos nosotros, guardar una y cerrar
    /// la app dejaba un marcador apuntando a nada.
    var library: [Recipe] = []

    /// Ids en orden de visita, del más reciente al más antiguo.
    var recentlyViewedIDs: [Recipe.ID] = []

    private let recentlyViewedLimit = 24

    /// Recetas agendadas a un día concreto, con recordatorio opcional.
    var plans: [CookPlan] = []

    // MARK: - Estado de UI

    var toast: ToastPayload?
    /// Cuando se llena, la app presenta el paywall con el contexto correcto.
    var limitPrompt: LimitPrompt?
    var isPresentingScanner = false
    var isPresentingPaywall = false

    struct LimitPrompt: Identifiable, Equatable {
        let id = UUID()
        var resource: MeteredResource
        var used: Int
        var limit: Int
    }

    // MARK: - Metering

    private struct UsageMeter: Codable, Sendable {
        var day: Date = Calendar.current.startOfDay(for: .now)
        var counts: [String: Int] = [:]
    }

    private var meter = UsageMeter()

    // MARK: - Init

    init(
        scanner: FridgeScanning = MockFridgeScanner(),
        generator: RecipeGenerating = MockRecipeGenerator(),
        preloadSampleData: Bool = true
    ) {
        self.scanner = scanner
        self.generator = generator

        if preloadSampleData {
            profile = SampleData.profile
            pantry = SampleData.pantry
            feed = SampleData.recipes
            listItems = SampleData.listItems
            ledger.restore(from: .init(
                entries: SampleData.pointsHistory,
                balance: SampleData.profile.pointsBalance,
                lifetimeEarned: SampleData.profile.lifetimePoints,
                activeBenefits: []
            ))
        }

        wireServices()
    }

    private func wireServices() {
        // Los anuncios preguntan por el estado, no lo guardan: así un canje de
        // "día sin anuncios" surte efecto al instante sin sincronizar nada.
        ads.adsDisabled = { [weak self] in
            guard let self else { return false }
            return self.profile.isPremium
                || self.store.isPremium
                || self.ledger.hasActiveBenefit(.adFreeDay)
                || self.ledger.hasActiveBenefit(.premiumTrial)
        }
        ads.personalizationAllowed = { [weak self] in
            self?.tracking.status.allowsPersonalization ?? false
        }

        // Los packs comprados acreditan por el mismo camino que los ganados.
        store.onPointsPurchased = { [weak self] points, packTitle in
            guard let self else { return }
            self.ledger.award(.purchased, amount: points, note: packTitle)
            self.showToast(
                ToastPayload(message: String(localized: "+\(points) puntos"),
                             detail: packTitle, systemImage: "sparkles", accent: .turmeric)
            )
            Haptics.celebrate()
        }
    }

    // MARK: - Ciclo de vida

    func onLaunch() async {
        await store.loadProducts()
        ledger.pruneExpiredBenefits()
        rolloverMeterIfNeeded()
        registerDailyVisit()
        await load()

        // Las notificaciones pendientes no sobreviven a reinstalar la app ni a
        // restaurar un backup: se vuelven a programar contra lo que hay guardado.
        await CookPlanScheduler.resync(plans)
    }

    func onForeground() {
        ledger.pruneExpiredBenefits()
        rolloverMeterIfNeeded()
        registerDailyVisit()
        tracking.refresh()
    }

    private func registerDailyVisit() {
        let earned = ledger.award(.dailyOpen)
        guard earned > 0 else { return }

        let calendar = Calendar.current
        if let last = profile.streak.lastActiveDay {
            if calendar.isDateInYesterday(last) {
                profile.streak.currentDays += 1
            } else if !calendar.isDateInToday(last) {
                profile.streak.currentDays = 1
            }
        } else {
            profile.streak.currentDays = 1
        }
        profile.streak.lastActiveDay = .now
        profile.streak.bestDays = max(profile.streak.bestDays, profile.streak.currentDays)

        if CookStreak.milestones.contains(profile.streak.currentDays) {
            ledger.award(.streakMilestone, note: String(localized: "\(profile.streak.currentDays) días seguidos"))
            showToast(ToastPayload(
                message: String(localized: "¡Racha de \(profile.streak.currentDays) días!"),
                detail: String(localized: "+\(PointsEvent.streakMilestone.amount) puntos"),
                systemImage: "flame.fill", accent: .turmeric
            ))
        }
        syncProfilePoints()
    }

    private func syncProfilePoints() {
        profile.pointsBalance = ledger.balance
        profile.lifetimePoints = ledger.lifetimeEarned
        if store.isPremium { profile.plan = .premium }
    }

    // MARK: - Cuotas

    var effectiveLimits: PlanLimits {
        (profile.isPremium || store.isPremium) ? .premium : .free
    }

    private func rolloverMeterIfNeeded() {
        let today = Calendar.current.startOfDay(for: .now)
        guard !Calendar.current.isDate(meter.day, inSameDayAs: today) else { return }
        meter.day = today
        for resource in MeteredResource.allCases where resource.isDaily {
            meter.counts[resource.rawValue] = 0
        }
    }

    func used(_ resource: MeteredResource) -> Int {
        switch resource {
        case .savedRecipe: savedRecipeIDs.count
        case .listItem:    listItems.filter { !$0.isDone }.count
        default:           meter.counts[resource.rawValue] ?? 0
        }
    }

    func remaining(_ resource: MeteredResource) -> Int {
        let limit = resource.limit(under: effectiveLimits)
        guard limit != .max else { return .max }
        return max(0, limit - used(resource))
    }

    /// Intenta consumir una unidad. Devuelve `false` y arma el prompt de límite
    /// si no hay cupo. Los beneficios canjeados con puntos se gastan primero.
    @discardableResult
    func consume(_ resource: MeteredResource) -> Bool {
        rolloverMeterIfNeeded()
        let limit = resource.limit(under: effectiveLimits)

        if limit == .max {
            meter.counts[resource.rawValue, default: 0] += 1
            return true
        }

        if used(resource) < limit {
            meter.counts[resource.rawValue, default: 0] += 1
            return true
        }

        // Sin cupo del plan: probamos con beneficios canjeados.
        let benefit: RewardKind? = switch resource {
        case .scan:         .extraScans
        case .aiGeneration: .extraGenerations
        default:            nil
        }
        if let benefit, ledger.consumeBenefit(benefit) {
            return true
        }

        Haptics.reject()
        limitPrompt = LimitPrompt(resource: resource, used: used(resource), limit: limit)
        return false
    }

    // MARK: - Despensa

    func commitScan(_ result: ScanResult) {
        let existing = Set(pantry.map { $0.name.lowercased() })
        let fresh = result.detected.filter { !existing.contains($0.name.lowercased()) }

        withAnimation(Motion.entrance) {
            pantry.append(contentsOf: fresh)
        }

        ledger.award(.scanCompleted)
        syncProfilePoints()

        showToast(ToastPayload(
            message: String(localized: "\(fresh.count) ingredientes nuevos"),
            detail: String(localized: "+\(PointsEvent.scanCompleted.amount) puntos"),
            systemImage: "refrigerator.fill", accent: .sage
        ))
        Haptics.celebrate()
        Task { await save() }
    }

    func removeIngredient(_ ingredient: Ingredient) {
        withAnimation(Motion.standard) {
            pantry.removeAll { $0.id == ingredient.id }
        }
        Task { await save() }
    }

    func confirmIngredient(_ ingredient: Ingredient) {
        guard let index = pantry.firstIndex(where: { $0.id == ingredient.id }) else { return }
        pantry[index].isConfirmed = true
        pantry[index].confidence = 1
        ledger.award(.pantryTidied)
        syncProfilePoints()
    }

    var expiringSoon: [Ingredient] {
        pantry.filter { $0.freshness >= .useSoon }
            .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    }

    // MARK: - Despensa a mano

    /// Añade o corrige un ingrediente cargado por el usuario.
    ///
    /// Toda la app se apoya en que la despensa sea cierta: las recetas que
    /// sugerimos, los avisos de caducidad y lo que va a la lista de la compra.
    /// El escáner no ve la fecha impresa en el envase, así que esta es la única
    /// vía para que ese dato sea real.
    func upsertIngredient(_ ingredient: Ingredient) {
        let isNew = !pantry.contains { $0.id == ingredient.id }

        withAnimation(Motion.standard) {
            if let index = pantry.firstIndex(where: { $0.id == ingredient.id }) {
                pantry[index] = ingredient
            } else {
                pantry.append(ingredient)
            }
        }

        Haptics.commit()
        showToast(ToastPayload(
            message: isNew
                ? String(localized: "Añadido a la despensa")
                : String(localized: "Actualizado"),
            detail: ingredient.name,
            systemImage: isNew ? "plus.circle.fill" : "checkmark",
            accent: ingredient.category.accent
        ))
        Task { await save() }
    }

    func removeIngredient(_ ingredient: Ingredient) {
        withAnimation(Motion.standard) {
            pantry.removeAll { $0.id == ingredient.id }
        }
        Haptics.tick()
        Task { await save() }
    }

    // MARK: - Recetas

    /// Resuelve una receta por id contra el estado vivo. Las vistas de detalle
    /// navegan con una copia, y esa copia se queda vieja en cuanto la receta
    /// cambia debajo (por ejemplo al publicarla).
    func recipe(for id: Recipe.ID) -> Recipe? {
        feed.first { $0.id == id }
            ?? lastGeneration.first { $0.id == id }
            ?? library.first { $0.id == id }
    }

    /// Mete la receta en la biblioteca durable sin duplicarla.
    private func archive(_ recipe: Recipe) {
        if let index = library.firstIndex(where: { $0.id == recipe.id }) {
            library[index] = recipe
        } else {
            library.append(recipe)
        }
    }

    /// Registra que el usuario abrió una receta. Alimenta "Vistas hace poco" y,
    /// de paso, la archiva: una generada que miraste una vez ya merece sobrevivir.
    func noteViewed(_ recipe: Recipe) {
        archive(recipe)
        guard recentlyViewedIDs.first != recipe.id else { return }

        recentlyViewedIDs.removeAll { $0 == recipe.id }
        recentlyViewedIDs.insert(recipe.id, at: 0)
        if recentlyViewedIDs.count > recentlyViewedLimit {
            recentlyViewedIDs.removeLast(recentlyViewedIDs.count - recentlyViewedLimit)
        }
        Task { await save() }
    }

    var recentlyViewed: [Recipe] {
        recentlyViewedIDs.compactMap { recipe(for: $0) }
    }

    var savedRecipes: [Recipe] {
        savedRecipeIDs
            .compactMap { recipe(for: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func isSaved(_ recipe: Recipe) -> Bool {
        savedRecipeIDs.contains(recipe.id)
    }

    func toggleSave(_ recipe: Recipe) {
        if savedRecipeIDs.contains(recipe.id) {
            savedRecipeIDs.remove(recipe.id)
            Haptics.tick()
        } else {
            guard consume(.savedRecipe) else { return }
            savedRecipeIDs.insert(recipe.id)
            archive(recipe)
            Haptics.tick()
            showToast(ToastPayload(message: String(localized: "Guardada"),
                                   detail: recipe.title,
                                   systemImage: "bookmark.fill", accent: .basil))
        }
        Task { await save() }
    }

    func markCooked(_ recipe: Recipe) {
        ledger.award(.recipeCooked, note: recipe.title)
        syncProfilePoints()

        // Se consume lo que usó la receta y estaba en la despensa.
        let used = Set(recipe.ingredients.filter(\.isInPantry).map { $0.name.lowercased() })
        withAnimation(Motion.standard) {
            pantry.removeAll { used.contains($0.name.lowercased()) && $0.category == .leftovers }
            if let index = listItems.firstIndex(where: { $0.kind == .toCook && $0.recipeID == recipe.id }) {
                listItems[index].isDone = true
                listItems[index].completedAt = .now
            }
        }

        showToast(ToastPayload(
            message: String(localized: "¡Cocinado!"),
            detail: String(localized: "+\(PointsEvent.recipeCooked.amount) puntos · \(recipe.title)"),
            systemImage: "checkmark", accent: .basil
        ))
        Haptics.celebrate()
        Task { await save() }
    }

    // MARK: - Publicar una receta propia

    enum PublishResult: Equatable {
        case published
        case rejected(String)
    }

    /// Convierte una receta generada por IA en una receta de la comunidad.
    ///
    /// Hasta que esto pasa, la receta es privada: se generó contra la despensa
    /// de una persona concreta y no tiene sentido que otros la comenten. Al
    /// publicarla se resetean los contadores sociales — heredar valoraciones
    /// que nadie dio sería inventar prueba social.
    @discardableResult
    func publishToCommunity(_ recipe: Recipe) -> PublishResult {
        // Guideline 4.7 + 1.2: lo que escribe el modelo pasa por el mismo
        // filtro que lo que escribe una persona antes de hacerse público.
        let screening = moderation.screen("\(recipe.title). \(recipe.subtitle)")
        guard screening.canPublish else {
            Haptics.reject()
            return .rejected(screening.advisory
                ?? String(localized: "No hemos podido publicar esta receta."))
        }

        var published = recipe
        published.source = .community
        published.authorName = profile.displayName
        published.authorInitials = profile.initials
        published.rating = 0
        published.ratingCount = 0
        published.savedCount = 0
        published.createdAt = .now

        withAnimation(Motion.standard) {
            if let index = feed.firstIndex(where: { $0.id == recipe.id }) {
                feed[index] = published
            } else {
                feed.insert(published, at: 0)
            }
            if let index = lastGeneration.firstIndex(where: { $0.id == recipe.id }) {
                lastGeneration[index] = published
            }
            archive(published)
        }

        ledger.award(.recipePublished, note: recipe.title)
        syncProfilePoints()
        Haptics.celebrate()

        showToast(ToastPayload(
            message: String(localized: "Receta publicada"),
            detail: String(localized: "+\(PointsEvent.recipePublished.amount) puntos · \(recipe.title)"),
            systemImage: "paperplane.fill", accent: .plum
        ))
        Task { await save() }
        return .published
    }

    // MARK: - Listas

    func addMissingIngredients(from recipe: Recipe) {
        let missing = recipe.missingIngredients
        guard !missing.isEmpty else { return }

        var added = 0
        for ingredient in missing {
            let alreadyThere = listItems.contains {
                $0.kind == .toBuy && !$0.isDone
                    && $0.title.lowercased() == ingredient.name.lowercased()
            }
            guard !alreadyThere, consume(.listItem) else { continue }

            listItems.append(ListItem(
                kind: .toBuy,
                title: ingredient.name,
                detail: ingredient.amount,
                category: ingredient.category,
                recipeID: recipe.id,
                recipeTitle: recipe.title
            ))
            added += 1
        }

        guard added > 0 else { return }
        Haptics.commit()
        showToast(ToastPayload(
            message: String(localized: "\(added) en To Buy"),
            detail: recipe.title,
            systemImage: "basket.fill", accent: .turmeric
        ))
        Task { await save() }
    }

    func planToCook(_ recipe: Recipe, on date: Date? = nil) {
        guard !listItems.contains(where: { $0.kind == .toCook && $0.recipeID == recipe.id && !$0.isDone }) else {
            showToast(ToastPayload(message: String(localized: "Ya está en To Cook"),
                                   systemImage: "frying.pan.fill", accent: .basil))
            return
        }
        guard consume(.listItem) else { return }

        listItems.append(ListItem(
            kind: .toCook,
            title: recipe.title,
            detail: String(localized: "\(recipe.minutes) min · \(recipe.servings) porciones"),
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            plannedFor: date
        ))

        // Lo que le falta va derecho a la lista de compras: es la integración
        // que hace que el sistema dual valga la pena.
        addMissingIngredients(from: recipe)

        Haptics.commit()
        showToast(ToastPayload(message: String(localized: "Planificada para cocinar"),
                               detail: recipe.title,
                               systemImage: "frying.pan.fill", accent: .basil))
        Task { await save() }
    }

    // MARK: - Calendario

    func cookPlans(on day: Date) -> [CookPlan] {
        let target = Calendar.current.startOfDay(for: day)
        return plans
            .filter { $0.day == target }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Días con algo agendado, para pintar los puntos del calendario.
    var plannedDays: Set<Date> {
        Set(plans.map(\.day))
    }

    /// Agenda una receta para un día y programa el aviso de ese día.
    func schedulePlan(for recipe: Recipe, on day: Date, remind: Bool = true) {
        let target = Calendar.current.startOfDay(for: day)

        guard !plans.contains(where: { $0.recipeID == recipe.id && $0.day == target }) else {
            showToast(ToastPayload(
                message: String(localized: "Ya estaba agendada"),
                detail: recipe.title,
                systemImage: "calendar", accent: .basil
            ))
            return
        }

        let plan = CookPlan(
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            day: target,
            remindsAt: remind ? CookPlan.defaultReminder(for: target) : nil
        )

        withAnimation(Motion.standard) { plans.append(plan) }
        // Si se agenda, se archiva: en dos semanas esa receta generada tiene que
        // seguir existiendo cuando llegue el recordatorio.
        archive(recipe)

        Haptics.commit()
        showToast(ToastPayload(
            message: String(localized: "Agendada"),
            detail: target.formatted(.dateTime.weekday(.wide).day().month()),
            systemImage: "calendar.badge.plus", accent: .basil
        ))

        Task {
            await CookPlanScheduler.schedule(plan)
            await save()
        }
    }

    func removePlan(_ plan: CookPlan) {
        CookPlanScheduler.cancel(plan)
        withAnimation(Motion.standard) { plans.removeAll { $0.id == plan.id } }
        Haptics.tick()
        Task { await save() }
    }

    func addManualItem(_ title: String, to kind: ListKind, category: PantryCategory? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, consume(.listItem) else { return }

        withAnimation(Motion.entrance) {
            listItems.append(ListItem(kind: kind, title: trimmed, category: category))
        }
        Haptics.tick()
        Task { await save() }
    }

    func toggleItem(_ item: ListItem) {
        guard let index = listItems.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(Motion.standard) {
            listItems[index].isDone.toggle()
            listItems[index].completedAt = listItems[index].isDone ? .now : nil
        }
        Haptics.tick()

        // Comprar algo lo mete en la despensa: cerrar ese lazo es lo que
        // convierte dos listas sueltas en un sistema.
        if listItems[index].isDone, listItems[index].kind == .toBuy {
            let item = listItems[index]
            if !pantry.contains(where: { $0.name.lowercased() == item.title.lowercased() }) {
                pantry.append(Ingredient(
                    name: item.title,
                    category: item.category ?? .condiments,
                    quantity: item.detail
                ))
            }
        }
        Task { await save() }
    }

    func deleteItem(_ item: ListItem) {
        withAnimation(Motion.standard) {
            listItems.removeAll { $0.id == item.id }
        }
        Task { await save() }
    }

    func clearCompleted(in kind: ListKind) {
        withAnimation(Motion.standard) {
            listItems.removeAll { $0.kind == kind && $0.isDone }
        }
        Haptics.tick()
        Task { await save() }
    }

    func items(in kind: ListKind) -> [ListItem] {
        listItems.filter { $0.kind == kind }
    }

    func pendingCount(in kind: ListKind) -> Int {
        listItems.filter { $0.kind == kind && !$0.isDone }.count
    }

    // MARK: - Comunidad

    func reviews(for recipe: Recipe) -> [Review] {
        let all = reviewsByRecipe[recipe.id] ?? SampleData.reviews(for: recipe.id)
        return moderation.visible(all)
    }

    enum PostReviewResult: Equatable {
        case published
        case flagged(String)
        case rejected(String)
    }

    func postReview(on recipe: Recipe, rating: Int, body: String) -> PostReviewResult {
        let screening = moderation.screen(body)

        guard screening.canPublish else {
            Haptics.reject()
            return .rejected(screening.advisory ?? String(localized: "No pudimos publicar este comentario."))
        }

        let isFlagged = screening.advisory != nil
        let review = Review(
            recipeID: recipe.id,
            author: CommunityAuthor(displayName: profile.displayName,
                                    initials: profile.initials,
                                    accent: profile.accent),
            rating: rating,
            body: body,
            createdAt: .now,
            moderation: isFlagged ? .underReview : .published
        )

        reviewsByRecipe[recipe.id, default: SampleData.reviews(for: recipe.id)].insert(review, at: 0)

        // Los puntos se acreditan igual; si moderación lo retira, se revierten.
        ledger.award(.reviewPosted, note: recipe.title)
        syncProfilePoints()
        Haptics.celebrate()

        if let advisory = screening.advisory {
            return .flagged(advisory)
        }

        showToast(ToastPayload(
            message: String(localized: "Comentario publicado"),
            detail: String(localized: "+\(PointsEvent.reviewPosted.amount) puntos"),
            systemImage: "bubble.left.fill", accent: .plum
        ))
        return .published
    }

    func markHelpful(_ review: Review, on recipe: Recipe) {
        var list = reviewsByRecipe[recipe.id] ?? SampleData.reviews(for: recipe.id)
        guard let index = list.firstIndex(where: { $0.id == review.id }),
              !list[index].didMarkHelpful else { return }

        list[index].didMarkHelpful = true
        list[index].helpfulCount += 1
        reviewsByRecipe[recipe.id] = list
        Haptics.tick()
    }

    func report(_ review: Review, reason: ReportReason, note: String?) {
        _ = moderation.report(review, reason: reason, note: note)
        showToast(ToastPayload(
            message: String(localized: "Reporte enviado"),
            detail: SupportContact.moderationSLA,
            systemImage: "flag.fill", accent: .tomato
        ))
        Haptics.commit()
        Task { await save() }
    }

    func block(_ author: CommunityAuthor) {
        moderation.block(author)
        showToast(ToastPayload(
            message: String(localized: "Bloqueaste a \(author.displayName)"),
            detail: String(localized: "No vas a volver a ver su contenido."),
            systemImage: "hand.raised.fill", accent: .tomato
        ))
        Task { await save() }
    }

    // MARK: - Canjes

    func redeem(_ reward: Reward) {
        do {
            try ledger.redeem(reward)
            syncProfilePoints()
            Haptics.celebrate()
            showToast(ToastPayload(
                message: String(localized: "Canjeado"),
                detail: reward.title,
                systemImage: reward.icon, accent: reward.accent
            ))
        } catch {
            Haptics.reject()
            showToast(ToastPayload(
                message: String(localized: "No se pudo canjear"),
                detail: error.localizedDescription,
                systemImage: "exclamationmark", accent: .tomato
            ))
        }
        Task { await save() }
    }

    // MARK: - Cuenta

    /// Guideline 5.1.1(v): borrado de cuenta y datos desde adentro de la app.
    func deleteAllData() async {
        try? await persistence.deleteEverything()
        pantry = []
        listItems = []
        savedRecipeIDs = []
        reviewsByRecipe = [:]
        lastGeneration = []
        library = []
        recentlyViewedIDs = []
        await CookPlanScheduler.cancelAll(plans)
        plans = []
        profile = UserProfile()
        ledger.restore(from: .init(entries: [], balance: 0, lifetimeEarned: 0, activeBenefits: []))
        moderation.restore(from: .init(blockedAuthorIDs: [], reportedReviewIDs: []))
        meter = UsageMeter()
    }

    // MARK: - Toast

    func showToast(_ payload: ToastPayload) {
        withAnimation(Motion.entrance) { toast = payload }
        Task {
            try? await Task.sleep(for: .seconds(2.8))
            withAnimation(Motion.standard) {
                if toast?.id == payload.id { toast = nil }
            }
        }
    }

    // MARK: - Persistencia

    private struct Snapshot: Codable, Sendable {
        var profile: UserProfile
        var pantry: [Ingredient]
        var listItems: [ListItem]
        var savedRecipeIDs: [UUID]
    }

    /// Las recetas van a su propio archivo: son el bloque más grande y el que
    /// más crece, y no tiene sentido reescribir el perfil entero al abrir una.
    private struct RecipeArchive: Codable, Sendable {
        var library: [Recipe]
        var recentlyViewedIDs: [UUID]
    }

    func save() async {
        let snapshot = Snapshot(profile: profile, pantry: pantry,
                                listItems: listItems,
                                savedRecipeIDs: Array(savedRecipeIDs))
        try? await persistence.save(snapshot, to: .profile)
        try? await persistence.save(
            RecipeArchive(library: library, recentlyViewedIDs: recentlyViewedIDs),
            to: .recipes
        )
        try? await persistence.save(ledger.snapshot(), to: .points)
        try? await persistence.save(moderation.snapshot(), to: .moderation)
        try? await persistence.save(plans, to: .plans)
    }

    func load() async {
        if let snapshot = await persistence.load(Snapshot.self, from: .profile) {
            profile = snapshot.profile
            pantry = snapshot.pantry
            listItems = snapshot.listItems
            savedRecipeIDs = Set(snapshot.savedRecipeIDs)
        }
        if let archive = await persistence.load(RecipeArchive.self, from: .recipes) {
            library = archive.library
            recentlyViewedIDs = archive.recentlyViewedIDs

            // Lo archivado vuelve al feed para que las guardadas y publicadas
            // sigan siendo navegables desde cualquier pantalla.
            let known = Set(feed.map(\.id))
            feed.append(contentsOf: archive.library.filter { !known.contains($0.id) })
        }
        if let points = await persistence.load(PointsLedger.Snapshot.self, from: .points) {
            ledger.restore(from: points)
        }
        if let mod = await persistence.load(ModerationService.Snapshot.self, from: .moderation) {
            moderation.restore(from: mod)
        }
        if let saved = await persistence.load([CookPlan].self, from: .plans) {
            plans = saved
        }
        syncProfilePoints()
    }
}

// MARK: - Inyección

/// `EnvironmentKey` explícita en lugar del macro `@Entry`: funciona con
/// cualquier versión de Xcode y no ata el proyecto a un SDK mínimo.
private struct AppEnvironmentKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = AppEnvironment(preloadSampleData: true)
}

extension EnvironmentValues {
    var app: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
