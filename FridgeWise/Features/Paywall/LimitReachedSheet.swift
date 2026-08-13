//
//  LimitReachedSheet.swift
//  FridgeWise
//
//  Qué pasa cuando el plan gratuito se queda sin cupo.
//
//  Postura: esto NO es un muro. Se ofrecen tres salidas y dos de ellas son
//  gratis (esperar a mañana, canjear puntos ganados). Un límite que solo se
//  destraba pagando convierte la app en un rehén, y eso se paga con reseñas
//  de una estrella mucho antes que con suscripciones.
//

import SwiftUI

struct LimitReachedSheet: View {

    let prompt: AppEnvironment.LimitPrompt

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    private var relatedReward: Reward? {
        switch prompt.resource {
        case .scan:         SampleData.rewards.first { $0.kind == .extraScans }
        case .aiGeneration: SampleData.rewards.first { $0.kind == .extraGenerations }
        default:            nil
        }
    }

    var body: some View {
        VStack(spacing: Space.lg) {
            icon

            VStack(spacing: 4) {
                Text(headline).displayStyle(25)
                Text(emphasis)
                    .font(Typeface.displayItalic(25))
                    .foregroundStyle(Palette.ink)
                    .squiggleUnderline(Palette.turmeric, delay: 0.2)
            }
            .multilineTextAlignment(.center)

            Text(message)
                .bodyStyle()
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            VStack(spacing: Space.xs) {
                if let reward = relatedReward {
                    redeemOption(reward)
                }

                Button(String(localized: "Ver Premium")) {
                    dismiss()
                    app.isPresentingPaywall = true
                }
                .buttonStyle(InkButtonStyle(fill: Palette.turmeric, fullWidth: true))

                Button(resetLabel) { dismiss() }
                    .font(Typeface.action)
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.top, Space.xxs)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, Space.xl)
        .padding(.bottom, Space.lg)
        .screenPadding()
        .canvasBackground()
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(Palette.surface)
                .overlay {
                    FluidBackdrop(palette: .reward, intensity: 0.32).clipShape(Circle())
                }
            Image(systemName: prompt.resource.icon)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Palette.turmeric)
        }
        .frame(width: 82, height: 82)
        .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
    }

    private var headline: String {
        switch prompt.resource {
        case .scan:         String(localized: "Usaste tus")
        case .aiGeneration: String(localized: "Usaste tus")
        case .savedRecipe:  String(localized: "Tu estante está")
        case .listItem:     String(localized: "Tu lista está")
        }
    }

    private var emphasis: String {
        switch prompt.resource {
        case .scan:         String(localized: "\(prompt.limit) escaneos de hoy")
        case .aiGeneration: String(localized: "\(prompt.limit) recetas de hoy")
        case .savedRecipe:  String(localized: "lleno")
        case .listItem:     String(localized: "llena")
        }
    }

    private var message: String {
        switch prompt.resource {
        case .scan, .aiGeneration:
            String(localized: "El contador se reinicia a la medianoche. Mientras tanto puedes canjear puntos o pasarte a Premium.")
        case .savedRecipe:
            String(localized: "El plan gratuito guarda hasta \(prompt.limit) recetas. Borra alguna, o pásate a Premium para no volver a elegir.")
        case .listItem:
            String(localized: "El plan gratuito llega a \(prompt.limit) ítems activos. Marca lo que ya compraste para hacer lugar.")
        }
    }

    private var resetLabel: String {
        prompt.resource.isDaily
            ? String(localized: "Espero a mañana")
            : String(localized: "Ahora no")
    }

    private func redeemOption(_ reward: Reward) -> some View {
        let canAfford = app.ledger.balance >= reward.cost

        return Button {
            guard canAfford else {
                dismiss()
                return
            }
            app.redeem(reward)
            dismiss()
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.basil)

                VStack(alignment: .leading, spacing: 1) {
                    Text(reward.title)
                        .font(Typeface.action)
                        .foregroundStyle(Palette.ink)
                    Text(canAfford
                         ? String(localized: "Canjear por \(reward.cost) puntos")
                         : String(localized: "Te faltan \(reward.cost - app.ledger.balance) puntos"))
                        .font(Typeface.micro)
                        .foregroundStyle(canAfford ? Palette.basil : Palette.inkFaint)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.inkFaint)
            }
            .padding(Space.md)
            .background {
                RoundedRectangle.soft(Radius.card)
                    .fill(canAfford ? Palette.basil.opacity(0.08) : Palette.surface)
            }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(canAfford ? Palette.basil.opacity(0.3) : Palette.hairline,
                                  lineWidth: Stroke.hairline)
            }
        }
        .buttonStyle(.pressableCard)
        .disabled(!canAfford)
    }
}
