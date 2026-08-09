//
//  SettingsView.swift
//  FridgeWise
//
//  Ajustes.
//
//  Acá viven varias obligaciones de App Store que no se pueden esconder:
//  · Gestionar suscripción y restaurar compras (3.1.2)
//  · Usuarios bloqueados, alcanzables (1.2)
//  · Borrado de cuenta y datos desde adentro de la app (5.1.1 v)
//  · Contacto de soporte publicado (1.2)
//  · Enlaces a Términos y Privacidad (3.1.2 / 5.1.1)
//
//  Construida con filas propias — no `Form`, no `List` agrupada. El chrome de
//  sistema con fondo gris rompe el papel cálido de toda la app.
//

import SwiftUI
import StoreKit

struct SettingsView: View {

    @Environment(\.app) private var app
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var isManagingSubscription = false
    @State private var restoreMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                profileCard
                subscriptionSection
                privacySection
                communitySection
                supportSection
                versionFooter
            }
            .screenPadding()
            .padding(.top, Space.md)
            .padding(.bottom, Space.tabBarInset)
        }
        .scrollIndicators(.hidden)
        .editorialScrollFeel()
        .canvasBackground()
        .navigationTitle(String(localized: "Ajustes"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.canvas, for: .navigationBar)
        .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
        .alert(String(localized: "Restaurar compras"),
               isPresented: Binding(get: { restoreMessage != nil },
                                    set: { if !$0 { restoreMessage = nil } })) {
            Button(String(localized: "Entendido"), role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    // MARK: - Perfil

    private var profileCard: some View {
        SoftCard {
            HStack(spacing: Space.md) {
                AvatarBadge(initials: app.profile.initials,
                            accent: app.profile.accent, size: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.profile.displayName)
                        .font(Typeface.cardTitle)
                        .foregroundStyle(Palette.ink)

                    HStack(spacing: 6) {
                        Text(app.profile.level.title)
                            .font(Typeface.micro)
                            .fontWeight(.semibold)
                            .foregroundStyle(app.profile.level.accent.color)
                        Text("·").foregroundStyle(Palette.inkFaint)
                        Text(String(localized: "\(app.ledger.balance) puntos"))
                            .font(Typeface.micro)
                            .foregroundStyle(Palette.inkFaint)
                    }
                }

                Spacer(minLength: 0)

                if app.profile.isPremium || app.store.isPremium {
                    InfoChip(label: String(localized: "Premium"), systemImage: "crown.fill",
                             accent: Palette.turmeric, weight: .tinted)
                }
            }
        }
    }

    // MARK: - Suscripción

    private var subscriptionSection: some View {
        section(String(localized: "Suscripción")) {
            if app.store.isPremium || app.profile.isPremium {
                row("crown", String(localized: "Gestionar suscripción"),
                    detail: String(localized: "Cambiar plan o cancelar")) {
                    isManagingSubscription = true
                }
            } else {
                row("sparkles", String(localized: "Pasarme a Premium"),
                    detail: String(localized: "Sin límites ni anuncios"),
                    accent: Palette.turmeric) {
                    app.isPresentingPaywall = true
                }
            }

            Hairline(inset: 46)

            row("arrow.clockwise", String(localized: "Restaurar compras")) {
                Task {
                    do {
                        try await app.store.restorePurchases()
                        restoreMessage = app.store.isPremium
                            ? String(localized: "Tu suscripción quedó activa.")
                            : String(localized: "No encontramos compras activas en esta Apple Account.")
                    } catch {
                        restoreMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - Privacidad

    private var privacySection: some View {
        section(String(localized: "Privacidad")) {
            row("hand.raised", String(localized: "Publicidad y seguimiento"),
                detail: trackingDetail) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }

            Hairline(inset: 46)

            NavigationLink(value: Route.dataAndPrivacy) {
                rowLabel("externaldrive", String(localized: "Tus datos"),
                         detail: String(localized: "Exportar o borrar todo"))
            }
        }
    }

    private var trackingDetail: String {
        switch app.tracking.status {
        case .authorized:    String(localized: "Anuncios personalizados activos")
        case .denied:        String(localized: "Anuncios genéricos")
        case .restricted:    String(localized: "Restringido por el dispositivo")
        case .notDetermined: String(localized: "Sin configurar")
        }
    }

    // MARK: - Comunidad

    private var communitySection: some View {
        section(String(localized: "Comunidad")) {
            NavigationLink(value: Route.blockedUsers) {
                rowLabel("hand.raised.slash", String(localized: "Usuarios bloqueados"),
                         detail: app.moderation.blockedAuthorIDs.isEmpty
                            ? String(localized: "Ninguno")
                            : String(localized: "\(app.moderation.blockedAuthorIDs.count) bloqueados"))
            }

            Hairline(inset: 46)

            row("doc.text", String(localized: "Normas de la comunidad")) {
                openURL(SupportContact.guidelinesURL)
            }

            Hairline(inset: 46)

            row("flag", String(localized: "Reportes enviados"),
                detail: "\(app.moderation.submittedReports.count)") {}
        }
    }

    // MARK: - Soporte

    private var supportSection: some View {
        section(String(localized: "Ayuda")) {
            row("envelope", String(localized: "Escribinos"), detail: SupportContact.email) {
                guard let url = URL(string: "mailto:\(SupportContact.email)") else { return }
                openURL(url)
            }

            Hairline(inset: 46)

            // El prompt nativo lo limita el sistema a 3 veces al año; no lo
            // forzamos nunca desde código, sólo cuando el usuario lo pide acá.
            row("star", String(localized: "Valorar Fridge Wise")) {
                requestReview()
            }

            Hairline(inset: 46)

            row("doc.plaintext", String(localized: "Términos de uso")) {
                openURL(SupportContact.eulaURL)
            }

            Hairline(inset: 46)

            row("lock.shield", String(localized: "Política de privacidad")) {
                openURL(SupportContact.privacyURL)
            }
        }
    }

    private var versionFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fridge Wise \(appVersion)")
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
            Text(String(localized: "Hecho para que sobre menos comida."))
                .font(Typeface.micro)
                .italic()
                .foregroundStyle(Palette.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, Space.md)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Piezas

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title)

            VStack(spacing: 0) {
                content()
            }
            .padding(.vertical, Space.xxs)
            .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
        }
    }

    private func row(
        _ icon: String,
        _ title: String,
        detail: String? = nil,
        accent: Color = Palette.ink,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            rowLabel(icon, title, detail: detail, accent: accent)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(
        _ icon: String,
        _ title: String,
        detail: String? = nil,
        accent: Color = Palette.ink
    ) -> some View {
        HStack(spacing: Space.sm) {
            ZStack {
                Circle().fill(accent.opacity(0.10))
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(accent)
            }
            .frame(width: 32, height: 32)

            Text(title)
                .font(Typeface.body)
                .foregroundStyle(Palette.ink)

            Spacer(minLength: Space.xs)

            if let detail {
                Text(detail)
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.inkFaint)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Bloqueados

struct BlockedUsersView: View {

    @Environment(\.app) private var app

    private var blocked: [CommunityAuthor] {
        SampleData.authors.filter { app.moderation.blockedAuthorIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                if blocked.isEmpty {
                    EmptyStateView(
                        headline: String(localized: "No bloqueaste a"),
                        emphasis: String(localized: "nadie"),
                        message: String(localized: "Si alguien te molesta, podés bloquearlo desde su comentario. No va a enterarse."),
                        systemImage: "hand.raised",
                        accent: Palette.sage,
                        palette: .pantry
                    )
                } else {
                    Text(String(localized: "No ves su contenido y no saben que los bloqueaste."))
                        .bodyStyle()
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        ForEach(Array(blocked.enumerated()), id: \.element.id) { index, author in
                            HStack(spacing: Space.sm) {
                                AvatarBadge(initials: author.initials, accent: author.accent)

                                Text(author.displayName)
                                    .font(Typeface.body)
                                    .foregroundStyle(Palette.ink)

                                Spacer(minLength: 0)

                                Button(String(localized: "Desbloquear")) {
                                    Haptics.tick()
                                    withAnimation(Motion.standard) {
                                        app.moderation.unblock(author.id)
                                    }
                                }
                                .buttonStyle(QuietButtonStyle())
                            }
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, 10)

                            if index < blocked.count - 1 {
                                Hairline(inset: 46)
                            }
                        }
                    }
                    .padding(.vertical, Space.xxs)
                    .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
                    .overlay {
                        RoundedRectangle.soft(Radius.card)
                            .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
                    }
                }
            }
            .screenPadding()
            .padding(.top, Space.md)
        }
        .scrollIndicators(.hidden)
        .canvasBackground()
        .navigationTitle(String(localized: "Bloqueados"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.canvas, for: .navigationBar)
    }
}

// MARK: - Datos y privacidad

/// Guideline 5.1.1(v): borrado de cuenta iniciable desde la app.
/// Se suma exportación, que no es obligatoria en App Store pero sí bajo GDPR/CCPA
/// y es lo mínimo decente.
struct DataPrivacyView: View {

    @Environment(\.app) private var app
    @State private var exportURL: URL?
    @State private var showsDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                intro
                dataInventory
                actions
            }
            .screenPadding()
            .padding(.top, Space.md)
            .padding(.bottom, Space.tabBarInset)
        }
        .scrollIndicators(.hidden)
        .canvasBackground()
        .navigationTitle(String(localized: "Tus datos"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.canvas, for: .navigationBar)
        .confirmationDialog(
            String(localized: "¿Borrar todo?"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Borrar todo"), role: .destructive) {
                Task {
                    isDeleting = true
                    await app.deleteAllData()
                    isDeleting = false
                    Haptics.commit()
                }
            }
            Button(String(localized: "Cancelar"), role: .cancel) {}
        } message: {
            Text(String(localized: "Se borra tu despensa, listas, recetas guardadas, puntos y comentarios. No se puede deshacer.\n\nSi tenés una suscripción activa, cancelala aparte desde los Ajustes de tu Apple Account: borrar los datos no la cancela."))
        }
        .sheet(item: Binding(
            get: { exportURL.map { ExportFile(url: $0) } },
            set: { _ in exportURL = nil }
        )) { file in
            ShareSheet(url: file.url)
        }
    }

    private struct ExportFile: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(String(localized: "Todo tuyo")).displayStyle(26)
            Text(String(localized: "Tu despensa, tus listas y tus puntos viven en este dispositivo. Las fotos que sacás se analizan y se descartan: no las guardamos ni las subimos a ningún lado."))
                .bodyStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dataInventory: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "Qué guardamos"))

            VStack(spacing: 0) {
                inventoryRow("refrigerator", String(localized: "Despensa"), "\(app.pantry.count) ingredientes")
                Hairline(inset: 46)
                inventoryRow("checklist", String(localized: "Listas"), "\(app.listItems.count) ítems")
                Hairline(inset: 46)
                inventoryRow("bookmark", String(localized: "Recetas guardadas"), "\(app.savedRecipeIDs.count)")
                Hairline(inset: 46)
                inventoryRow("sparkles", String(localized: "Historial de puntos"), "\(app.ledger.entries.count) movimientos")
                Hairline(inset: 46)
                inventoryRow("camera", String(localized: "Fotos de escaneo"),
                             String(localized: "Ninguna guardada"))
            }
            .padding(.vertical, Space.xxs)
            .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
        }
    }

    private func inventoryRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: Space.sm) {
            ZStack {
                Circle().fill(Palette.sage.opacity(0.12))
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.sage)
            }
            .frame(width: 32, height: 32)

            Text(title)
                .font(Typeface.body)
                .foregroundStyle(Palette.ink)

            Spacer(minLength: Space.xs)

            Text(value)
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: Space.xs) {
            Button(String(localized: "Descargar mis datos")) {
                Task {
                    exportURL = await app.persistence.exportAll()
                    Haptics.tick()
                }
            }
            .buttonStyle(QuietButtonStyle(fullWidth: true))

            Button {
                showsDeleteConfirmation = true
            } label: {
                if isDeleting {
                    ProgressView().tint(Palette.tomato)
                } else {
                    Text(String(localized: "Borrar mi cuenta y mis datos"))
                }
            }
            .buttonStyle(AccentButtonStyle(accent: Palette.tomato, fullWidth: true))
            .disabled(isDeleting)

            Text(String(localized: "El borrado es inmediato y definitivo. Si preferís que lo hagamos nosotros, escribinos a \(SupportContact.email)."))
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.xxs)
        }
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
