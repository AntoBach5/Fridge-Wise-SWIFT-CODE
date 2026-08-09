//
//  PaywallView.swift
//  FridgeWise
//
//  Suscripción Premium.
//
//  Checklist de Guideline 3.1.2 que esta pantalla cumple — si falta uno, rechazo:
//    ☑ Título y descripción de qué incluye la suscripción
//    ☑ Duración del período (mensual / anual)
//    ☑ Precio, tomado de StoreKit y localizado
//    ☑ Precio por unidad cuando ayuda a comparar (equivalente mensual del anual)
//    ☑ Declaración explícita de renovación automática y cómo cancelar
//    ☑ Enlace funcional a Términos de uso (EULA)
//    ☑ Enlace funcional a Política de privacidad
//    ☑ Botón de restaurar compras
//    ☑ Cierre disponible sin comprar, sin trucos ni "x" escondida
//

import SwiftUI
import StoreKit

struct PaywallView: View {

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            CanvasBackground()
            FluidBackdrop(palette: .reward, intensity: 0.26)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    hero
                    benefits
                    planPicker
                    renewalDisclosure
                }
                .screenPadding()
                .padding(.top, Space.lg)
                .padding(.bottom, 220)
            }
            .scrollIndicators(.hidden)

            VStack {
                closeButton
                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) { footer }
        .task {
            if app.store.subscriptions.isEmpty {
                await app.store.loadProducts()
            }
            // Preseleccionamos el anual sólo porque es el mejor valor real,
            // y el mensual queda igual de visible. Nada de esconder opciones.
            selected = app.store.subscriptions.first { $0.id == PremiumProduct.yearly.rawValue }
                ?? app.store.subscriptions.first
        }
        .alert(String(localized: "No se pudo completar"),
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button(String(localized: "Entendido"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Encabezado

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                Haptics.select()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 34, height: 34)
                    .background { Circle().fill(Palette.surface) }
                    .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "Cerrar"))
        }
        .padding(.horizontal, Space.sm)
        .padding(.top, Space.xs)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            InfoChip(label: String(localized: "Premium"), systemImage: "crown.fill",
                     accent: Palette.turmeric, weight: .tinted)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Cociná sin")).displayStyle(33)
                HStack(spacing: 9) {
                    Text(String(localized: "límites"))
                        .font(Typeface.displayItalic(33))
                        .foregroundStyle(Palette.ink)
                        .squiggleUnderline(Palette.turmeric)
                    Text(String(localized: "ni cortes")).displayStyle(33)
                }
                .padding(.bottom, Space.xxs)
            }

            Text(String(localized: "Escaneos y recetas sin tope, cero publicidad, y todo el modo cocina desbloqueado."))
                .bodyStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Space.xxl)
    }

    // MARK: - Beneficios

    private var benefits: some View {
        VStack(spacing: 0) {
            comparisonRow(String(localized: "Escaneos por día"),
                          free: "\(PlanLimits.free.scansPerDay)",
                          premium: String(localized: "Sin tope"))
            Hairline()
            comparisonRow(String(localized: "Recetas con IA por día"),
                          free: "\(PlanLimits.free.aiGenerationsPerDay)",
                          premium: String(localized: "Sin tope"))
            Hairline()
            comparisonRow(String(localized: "Recetas guardadas"),
                          free: "\(PlanLimits.free.savedRecipes)",
                          premium: String(localized: "Sin tope"))
            Hairline()
            comparisonRow(String(localized: "Publicidad"),
                          free: String(localized: "Sí"),
                          premium: String(localized: "Nunca"))
            Hairline()
            comparisonRow(String(localized: "Modo cocina"),
                          free: String(localized: "Básico"),
                          premium: String(localized: "Completo"))
        }
        .padding(.vertical, Space.xxs)
        .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
        .overlay {
            RoundedRectangle.soft(Radius.card)
                .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
        }
        .overlay(alignment: .top) {
            HStack {
                Spacer()
                Text(String(localized: "Gratis")).eyebrow()
                    .frame(width: 62)
                Text(String(localized: "Premium")).eyebrow(Palette.turmeric)
                    .frame(width: 72)
            }
            .padding(.horizontal, Space.md)
            .offset(y: -18)
        }
        .padding(.top, Space.md)
    }

    private func comparisonRow(_ title: String, free: String, premium: String) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(Typeface.callout)
                .foregroundStyle(Palette.ink)

            Spacer(minLength: Space.xs)

            Text(free)
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
                .frame(width: 62)

            Text(premium)
                .font(Typeface.micro)
                .fontWeight(.bold)
                .foregroundStyle(Palette.turmeric)
                .frame(width: 72)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(String(localized: "Gratis")): \(free). Premium: \(premium)")
    }

    // MARK: - Planes

    @ViewBuilder
    private var planPicker: some View {
        if app.store.subscriptions.isEmpty {
            VStack(spacing: Space.xs) {
                SkeletonBlock(height: 72, radius: Radius.card)
                SkeletonBlock(height: 72, radius: Radius.card)
            }
        } else {
            VStack(spacing: Space.xs) {
                ForEach(app.store.subscriptions, id: \.id) { product in
                    planRow(product)
                }
            }
        }
    }

    private func planRow(_ product: Product) -> some View {
        let isSelected = selected?.id == product.id
        let isYearly = product.id == PremiumProduct.yearly.rawValue

        return Button {
            Haptics.select()
            withAnimation(Motion.standard) { selected = product }
        } label: {
            HStack(spacing: Space.md) {
                DrawnCheckbox(isOn: isSelected, accent: Palette.turmeric, size: 22)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(product.displayName.isEmpty
                             ? (isYearly ? String(localized: "Anual") : String(localized: "Mensual"))
                             : product.displayName)
                            .font(Typeface.cardTitle)
                            .foregroundStyle(Palette.ink)

                        if isYearly {
                            InfoChip(label: String(localized: "Ahorrás"),
                                     accent: Palette.basil, weight: .tinted)
                        }
                    }

                    // Precio por mes del anual: comparar honestamente es mejor
                    // negocio que esconder el número grande.
                    if let monthly = app.store.monthlyEquivalent(for: product) {
                        Text(String(localized: "equivale a \(monthly) por mes"))
                            .font(Typeface.micro)
                            .foregroundStyle(Palette.inkFaint)
                    } else if let intro = app.store.introductoryOffer(for: product) {
                        Text(intro)
                            .font(Typeface.micro)
                            .fontWeight(.semibold)
                            .foregroundStyle(Palette.basil)
                    }
                }

                Spacer(minLength: 0)

                Text(product.displayPrice)
                    .font(Typeface.statSmall)
                    .foregroundStyle(Palette.ink)
            }
            .padding(Space.md)
            .background {
                RoundedRectangle.soft(Radius.card)
                    .fill(isSelected ? Palette.turmeric.opacity(0.09) : Palette.surface)
            }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(isSelected ? Palette.turmeric.opacity(0.45) : Palette.hairline,
                                  lineWidth: isSelected ? 1.2 : Stroke.hairline)
            }
        }
        .buttonStyle(.pressableCard)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    /// Requisito 3.1.2: texto de renovación visible ANTES de comprar.
    @ViewBuilder
    private var renewalDisclosure: some View {
        if let selected {
            Text(app.store.renewalDisclosure(for: selected))
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Pie

    private var footer: some View {
        VStack(spacing: Space.sm) {
            Button {
                Task { await purchase() }
            } label: {
                if isPurchasing {
                    ProgressView().tint(Palette.onInk)
                } else {
                    Text(hasIntroductoryOffer
                         ? String(localized: "Empezar prueba gratis")
                         : String(localized: "Suscribirme"))
                }
            }
            .buttonStyle(InkButtonStyle(fill: Palette.turmeric, fullWidth: true))
            .disabled(selected == nil || isPurchasing)
            .opacity(selected == nil ? 0.5 : 1)

            HStack(spacing: Space.md) {
                Button(String(localized: "Restaurar compras")) {
                    Task {
                        do {
                            try await app.store.restorePurchases()
                            if app.store.isPremium { dismiss() }
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                Link(String(localized: "Términos de uso"), destination: SupportContact.eulaURL)
                Link(String(localized: "Privacidad"), destination: SupportContact.privacyURL)
            }
            .font(Typeface.micro)
            .fontWeight(.semibold)
            .foregroundStyle(Palette.inkSoft)
        }
        .padding(.horizontal, Space.screen)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.md)
        .background {
            Rectangle()
                .fill(Palette.canvas)
                .mask {
                    LinearGradient(colors: [.clear, .black, .black],
                                   startPoint: .top, endPoint: .bottom)
                }
                .ignoresSafeArea()
        }
    }

    private var hasIntroductoryOffer: Bool {
        guard let selected else { return false }
        return app.store.introductoryOffer(for: selected) != nil
    }

    private func purchase() async {
        guard let product = selected else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let outcome = try await app.store.purchase(product)
            switch outcome {
            case .success:
                app.profile.plan = .premium
                Haptics.celebrate()
                app.showToast(ToastPayload(
                    message: String(localized: "Bienvenido a Premium"),
                    detail: String(localized: "Sin límites, sin anuncios."),
                    systemImage: "crown.fill", accent: .turmeric
                ))
                dismiss()
            case .pending:
                app.showToast(ToastPayload(
                    message: String(localized: "Falta una aprobación"),
                    detail: String(localized: "Te avisamos cuando se confirme."),
                    systemImage: "clock", accent: .turmeric
                ))
                dismiss()
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
