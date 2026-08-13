//
//  PointsShopView.swift
//  FridgeWise
//
//  Compra de packs de puntos (IAP consumible).
//
//  Reglas que se ven en la pantalla:
//  · Los precios vienen de `Product.displayPrice` — localizados, en la moneda
//    del usuario. Hardcodear "$4,99" es rechazo seguro y además miente en
//    la mitad de los mercados.
//  · "Restaurar compras" está presente aunque los consumibles no se restauren:
//    el usuario no distingue tipos de producto, y Apple pide el botón.
//  · Se declara qué pasa si falla la entrega y a dónde escribir.
//

import SwiftUI
import StoreKit

struct PointsShopView: View {

    @Environment(\.app) private var app
    @State private var purchasing: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                header

                if app.store.isLoadingProducts {
                    loadingState
                } else if app.store.pointPacks.isEmpty {
                    unavailableState
                } else {
                    packGrid
                }

                premiumNudge
                legalFooter
            }
            .screenPadding()
            .padding(.bottom, Space.xxl)
        }
        .scrollIndicators(.hidden)
        .editorialScrollFeel()
        .canvasBackground()
        .navigationTitle(String(localized: "Comprar puntos"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.canvas, for: .navigationBar)
        .task {
            if app.store.pointPacks.isEmpty {
                await app.store.loadProducts()
            }
        }
        .alert(String(localized: "No se pudo completar"),
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button(String(localized: "Entendido"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Secciones

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Palette.turmeric)
                RollingNumber(value: app.ledger.balance, font: Typeface.stat(26))
                Text(String(localized: "puntos ahora"))
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.inkSoft)
            }

            Text(String(localized: "Los puntos se ganan cocinando y comentando. Si quieres ir más rápido, también puedes comprarlos."))
                .bodyStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Space.xs)
    }

    private var loadingState: some View {
        VStack(spacing: Space.sm) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonBlock(height: 76, radius: Radius.card)
            }
        }
    }

    private var unavailableState: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(String(localized: "Tienda no disponible")).eyebrow(Palette.tomato)
                Text(String(localized: "No pudimos cargar los productos. Revisa tu conexión o intenta más tarde."))
                    .bodyStyle()
                    .fixedSize(horizontal: false, vertical: true)
                Button(String(localized: "Reintentar")) {
                    Task { await app.store.loadProducts() }
                }
                .buttonStyle(QuietButtonStyle())
                .padding(.top, Space.xxs)
            }
        }
    }

    private var packGrid: some View {
        VStack(spacing: Space.sm) {
            ForEach(app.store.pointPacks, id: \.id) { product in
                if let pack = PointPack.catalog.first(where: { $0.id == product.id }) {
                    packRow(pack: pack, product: product)
                }
            }
        }
    }

    private func packRow(pack: PointPack, product: Product) -> some View {
        Button {
            Task { await purchase(product) }
        } label: {
            HStack(spacing: Space.md) {
                ZStack {
                    Circle().fill(pack.accent.color.opacity(0.15))
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(pack.accent.color)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(pack.title)
                            .font(Typeface.cardTitle)
                            .foregroundStyle(Palette.ink)

                        if pack.isBestValue {
                            InfoChip(label: String(localized: "Mejor valor"),
                                     accent: Palette.basil, weight: .tinted)
                        }
                    }

                    HStack(spacing: 6) {
                        Text("\(pack.points) " + String(localized: "puntos"))
                            .font(Typeface.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkSoft)

                        if let bonus = pack.bonusLabel {
                            Text(bonus)
                                .font(Typeface.micro)
                                .fontWeight(.bold)
                                .foregroundStyle(Palette.basil)
                        }
                    }
                }

                Spacer(minLength: 0)

                if purchasing == product.id {
                    ProgressView().tint(Palette.ink)
                        .frame(width: 76)
                } else {
                    // Precio localizado de StoreKit, nunca hardcodeado.
                    Text(product.displayPrice)
                        .font(Typeface.action)
                        .foregroundStyle(Palette.onInk)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, 10)
                        .background { Capsule().fill(Palette.inkSolid) }
                }
            }
            .padding(Space.md)
            .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(pack.isBestValue ? Palette.basil.opacity(0.35) : Palette.hairline,
                                  lineWidth: Stroke.hairline)
            }
        }
        .buttonStyle(.pressableCard)
        .disabled(purchasing != nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pack.title), \(pack.points) puntos, \(product.displayPrice)")
    }

    private var premiumNudge: some View {
        SoftCard(tint: Palette.turmeric) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(String(localized: "¿Vas a usarla mucho?")).eyebrow(Palette.turmeric)
                Text(String(localized: "Premium saca los límites y los anuncios sin que tengas que administrar puntos. Suele salir más barato que comprarlos seguido."))
                    .bodyStyle()
                    .fixedSize(horizontal: false, vertical: true)
                Button(String(localized: "Ver Premium")) {
                    app.isPresentingPaywall = true
                }
                .buttonStyle(AccentButtonStyle(accent: Palette.turmeric))
                .padding(.top, Space.xxs)
            }
        }
    }

    private var legalFooter: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Hairline()

            Text(String(localized: "El pago se cobra a tu Apple Account al confirmar. Los puntos se acreditan al instante y no vencen. Las compras de puntos son consumibles: no se restauran, pero si algo falla escríbenos a \(SupportContact.email) y lo resolvemos."))
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Space.md) {
                Button(String(localized: "Restaurar compras")) {
                    Task {
                        do { try await app.store.restorePurchases() }
                        catch { errorMessage = error.localizedDescription }
                    }
                }
                Link(String(localized: "Términos"), destination: SupportContact.termsURL)
                Link(String(localized: "Privacidad"), destination: SupportContact.privacyURL)
            }
            .font(Typeface.micro)
            .fontWeight(.semibold)
            .foregroundStyle(Palette.inkSoft)
            .padding(.top, 2)
        }
        .padding(.top, Space.sm)
    }

    // MARK: - Compra

    private func purchase(_ product: Product) async {
        purchasing = product.id
        defer { purchasing = nil }

        do {
            let outcome = try await app.store.purchase(product)
            switch outcome {
            case .success:
                Haptics.celebrate()
            case .pending:
                app.showToast(ToastPayload(
                    message: String(localized: "Falta una aprobación"),
                    detail: String(localized: "Te avisamos cuando se confirme."),
                    systemImage: "clock", accent: .turmeric
                ))
            case .cancelled:
                break
            case .failedVerification:
                errorMessage = String(localized: "No pudimos verificar la compra con App Store. No se te cobró.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
