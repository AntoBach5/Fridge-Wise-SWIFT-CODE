//
//  RewardCatalogView.swift
//  FridgeWise
//
//  Catálogo completo de canjes.
//
//  Guideline 3.2.2: nada de azar. Cada canje muestra el costo exacto por
//  adelantado y lo que da exactamente. No hay cajas sorpresa ni ruletas.
//

import SwiftUI

struct RewardCatalogView: View {

    @Environment(\.app) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                balanceStrip

                if !app.ledger.activeBenefits.filter(\.isActive).isEmpty {
                    activeBenefits
                }

                ForEach(SampleData.rewards) { reward in
                    rewardRow(reward)
                }

                Text(String(localized: "Todos los canjes desbloquean contenido o funciones dentro de la app. Los puntos no vencen y no se pueden convertir en dinero."))
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs)
            }
            .screenPadding()
            .padding(.bottom, Space.xxl)
        }
        .scrollIndicators(.hidden)
        .editorialScrollFeel()
        .canvasBackground()
        .navigationTitle(String(localized: "Canjear puntos"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.canvas, for: .navigationBar)
    }

    private var balanceStrip: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.turmeric)

            RollingNumber(value: app.ledger.balance, font: Typeface.stat(24))

            Text(String(localized: "disponibles"))
                .font(Typeface.callout)
                .foregroundStyle(Palette.inkSoft)

            Spacer()

            NavigationLink(value: Route.pointsShop) {
                Text(String(localized: "Comprar más"))
                    .font(Typeface.micro)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.turmeric)
            }
        }
        .padding(Space.md)
        .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
        .overlay {
            RoundedRectangle.soft(Radius.card)
                .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
        }
    }

    private var activeBenefits: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            SectionHeader(title: String(localized: "Activos ahora"), accent: Palette.basil) {
                EmptyView()
            }

            ForEach(app.ledger.activeBenefits.filter(\.isActive)) { benefit in
                HStack(spacing: Space.sm) {
                    AccentDot(color: Palette.basil, size: 7)

                    Text(benefit.title)
                        .font(Typeface.callout)
                        .foregroundStyle(Palette.ink)

                    Spacer(minLength: 0)

                    if let expires = benefit.expiresAt {
                        Text(expires.formatted(.relative(presentation: .named)))
                            .font(Typeface.micro)
                            .foregroundStyle(Palette.basil)
                    } else if let uses = benefit.remainingUses {
                        Text(String(localized: "\(uses) restantes"))
                            .font(Typeface.micro)
                            .foregroundStyle(Palette.basil)
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, 10)
                .background { RoundedRectangle.soft(Radius.md).fill(Palette.basil.opacity(0.08)) }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func rewardRow(_ reward: Reward) -> some View {
        let canAfford = app.ledger.balance >= reward.cost

        return SoftCard(padding: Space.md, tint: canAfford ? reward.accent.color : nil) {
            HStack(alignment: .top, spacing: Space.md) {
                ZStack {
                    Circle().fill(reward.accent.color.opacity(canAfford ? 0.16 : 0.07))
                    Image(systemName: reward.icon)
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(reward.accent.color.opacity(canAfford ? 1 : 0.5))
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(reward.title)
                        .font(Typeface.cardTitle)
                        .foregroundStyle(Palette.ink)

                    Text(reward.detail)
                        .font(Typeface.callout)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    if !canAfford {
                        Text(String(localized: "Te faltan \(reward.cost - app.ledger.balance) puntos"))
                            .font(Typeface.micro)
                            .fontWeight(.semibold)
                            .foregroundStyle(Palette.tomato)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    app.redeem(reward)
                } label: {
                    VStack(spacing: 1) {
                        Text("\(reward.cost)")
                            .font(Typeface.statSmall)
                            .monospacedDigit()
                        Text(String(localized: "pts"))
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .frame(width: 58, height: 44)
                }
                .buttonStyle(InkButtonStyle(
                    fill: canAfford ? reward.accent.color : Palette.canvasSunken,
                    foreground: canAfford ? Palette.onInk : Palette.inkFaint,
                    horizontalPadding: 0,
                    verticalPadding: 0
                ))
                .disabled(!canAfford)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
