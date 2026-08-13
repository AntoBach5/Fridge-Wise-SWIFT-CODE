//
//  RewardsView.swift
//  FridgeWise
//
//  Puntos, nivel y racha.
//
//  Postura de producto: la gamificación acompaña, no persigue. Nada de contadores
//  regresivos que presionan, ni "pierdes tu racha en 2 h", ni ruletas. Se premia
//  cocinar y aportar a la comunidad, que es lo que queremos que pase igual.
//
//  Guideline 3.1.1: los puntos son moneda virtual consumible. No se transfieren,
//  no se canjean por dinero, y aquí se declara explícitamente que no expiran.
//

import SwiftUI

struct RewardsView: View {

    @Environment(\.app) private var app
    @Binding var isTabBarDimmed: Bool

    @State private var celebrationController = RiveController(.celebration)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                header
                balanceCard
                levelCard
                featuredRewards
                earnGuide
                historySection
                fineprint
            }
            .padding(.top, Space.xs)
            .padding(.bottom, Space.tabBarInset)
            .readsScrollDirection(into: $isTabBarDimmed)
        }
        .coordinateSpace(name: "scroll")
        .scrollIndicators(.hidden)
        .editorialScrollFeel()
        .canvasBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Encabezado

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "Lo que")).displayStyle(31)
            HStack(spacing: 9) {
                Text(String(localized: "ganaste"))
                    .font(Typeface.displayItalic(31))
                    .foregroundStyle(Palette.ink)
                    .squiggleUnderline(Palette.turmeric)
                Text(String(localized: "cocinando")).displayStyle(31)
            }
            .padding(.bottom, Space.xxs)
        }
        .screenPadding()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Saldo

    private var balanceCard: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle.soft(Radius.lg)
                    .fill(Palette.surface)
                    .overlay {
                        FluidBackdrop(palette: .reward, intensity: 0.34)
                            .clipShape(RoundedRectangle.soft(Radius.lg))
                    }

                RiveStage(controller: celebrationController) { EmptyView() }
                    .allowsHitTesting(false)

                VStack(spacing: Space.md) {
                    Text(String(localized: "Saldo disponible")).eyebrow(Palette.clay)

                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        RollingNumber(value: app.ledger.balance,
                                      font: Typeface.stat(48),
                                      color: Palette.ink)
                        Text(String(localized: "puntos"))
                            .font(Typeface.displayItalic(20))
                            .foregroundStyle(Palette.inkSoft)
                    }

                    HStack(spacing: Space.xs) {
                        NavigationLink(value: Route.rewardCatalog) {
                            Text(String(localized: "Canjear"))
                                .font(Typeface.action)
                                .foregroundStyle(Palette.onInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background { Capsule().fill(Palette.inkSolid) }
                        }

                        NavigationLink(value: Route.pointsShop) {
                            Text(String(localized: "Comprar puntos"))
                                .font(Typeface.action)
                                .foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background { Capsule().fill(Palette.surface.opacity(0.85)) }
                                .overlay {
                                    Capsule().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
                                }
                        }
                    }
                    .padding(.top, Space.xxs)
                }
                .padding(Space.lg)
            }
            .overlay {
                RoundedRectangle.soft(Radius.lg)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
            .shadow(color: Palette.cardShadow, radius: 20, x: 0, y: 9)
        }
        .screenPadding()
    }

    // MARK: - Nivel

    private var levelCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(alignment: .center, spacing: Space.md) {
                    ZStack {
                        Circle()
                            .stroke(Palette.hairline, lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: app.profile.progressToNextLevel)
                            .stroke(app.profile.level.accent.color,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(app.profile.level.rawValue + 1)")
                            .font(.system(size: 19, weight: .medium, design: .serif))
                            .foregroundStyle(app.profile.level.accent.color)
                    }
                    .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.profile.level.title)
                            .font(Typeface.cardTitle)
                            .foregroundStyle(Palette.ink)

                        if let next = app.profile.level.next {
                            Text(String(localized: "\(app.profile.pointsToNextLevel) puntos para \(next.title)"))
                                .font(Typeface.micro)
                                .foregroundStyle(Palette.inkSoft)
                        } else {
                            Text(String(localized: "Llegaste al nivel máximo"))
                                .font(Typeface.micro)
                                .foregroundStyle(Palette.inkSoft)
                        }
                    }

                    Spacer(minLength: 0)
                }

                Hairline()

                HStack(spacing: Space.lg) {
                    MetricStat(value: "\(app.profile.streak.currentDays)",
                               label: String(localized: "Racha actual"),
                               systemImage: "flame", accent: Palette.turmeric)
                    MetricStat(value: "\(app.profile.streak.bestDays)",
                               label: String(localized: "Mejor racha"),
                               systemImage: "trophy", accent: Palette.clay)
                    MetricStat(value: "\(app.ledger.lifetimeEarned)",
                               label: String(localized: "Total ganado"),
                               systemImage: "sparkles", accent: Palette.sage)
                }

                if let next = app.profile.streak.nextMilestone {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(String(localized: "Próxima meta: \(next) días"))
                                .font(Typeface.micro)
                                .foregroundStyle(Palette.inkSoft)
                            Spacer()
                            Text(String(localized: "+\(PointsEvent.streakMilestone.amount) pts"))
                                .font(Typeface.micro)
                                .fontWeight(.bold)
                                .foregroundStyle(Palette.turmeric)
                        }
                        ProgressTrack(value: app.profile.streak.progressToNextMilestone,
                                      accent: Palette.turmeric, height: 5)
                    }
                }
            }
        }
        .screenPadding()
    }

    // MARK: - Canjes destacados

    private var featuredRewards: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: String(localized: "Canjes")) {
                NavigationLink(value: Route.rewardCatalog) {
                    Text(String(localized: "Ver todo"))
                        .font(Typeface.micro)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.turmeric)
                }
            }
            .screenPadding()

            ScrollView(.horizontal) {
                HStack(spacing: Space.sm) {
                    ForEach(SampleData.rewards.filter(\.isFeatured)) { reward in
                        RewardCard(reward: reward, balance: app.ledger.balance) {
                            app.redeem(reward)
                            celebrationController.fire("fire")
                        }
                    }
                }
                .padding(.horizontal, Space.screen)
            }
            .scrollIndicators(.hidden)
            .tightHorizontalRail()
        }
    }

    // MARK: - Cómo ganar

    private var earnGuide: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "Cómo se ganan"))
                .screenPadding()

            VStack(spacing: 0) {
                let events: [PointsEvent] = [
                    .recipeCooked, .reviewPosted, .scanCompleted,
                    .recipeShared, .reviewFoundHelpful, .dailyOpen
                ]
                ForEach(Array(events.enumerated()), id: \.element) { index, event in
                    HStack(spacing: Space.sm) {
                        ZStack {
                            Circle().fill(event.accent.color.opacity(0.14))
                            Image(systemName: event.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(event.accent.color)
                        }
                        .frame(width: 32, height: 32)

                        Text(event.title)
                            .font(Typeface.body)
                            .foregroundStyle(Palette.ink)

                        Spacer(minLength: 0)

                        Text("+\(event.amount)")
                            .font(Typeface.statSmall)
                            .foregroundStyle(event.accent.color)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, 11)
                    .accessibilityElement(children: .combine)

                    if index < events.count - 1 {
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
            .screenPadding()
        }
    }

    // MARK: - Historial

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(String(localized: "Movimientos"))
                .screenPadding()

            VStack(spacing: 0) {
                let entries = Array(app.ledger.entries.prefix(8))
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: Space.sm) {
                        AccentDot(color: entry.event.accent.color, size: 7)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.note ?? entry.event.title)
                                .font(Typeface.callout)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Text(entry.date.formatted(.relative(presentation: .named)))
                                .font(Typeface.micro)
                                .foregroundStyle(Palette.inkFaint)
                        }

                        Spacer(minLength: 0)

                        Text(entry.amount > 0 ? "+\(entry.amount)" : "\(entry.amount)")
                            .font(Typeface.statSmall)
                            .foregroundStyle(entry.amount > 0 ? Palette.basil : Palette.inkSoft)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)

                    if index < entries.count - 1 {
                        Hairline(inset: 30)
                    }
                }
            }
            .padding(.vertical, Space.xxs)
            .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
            }
            .screenPadding()
        }
    }

    /// Declaración obligatoria sobre la moneda virtual (Guideline 3.1.1).
    private var fineprint: some View {
        Text(String(localized: "Los puntos no vencen, no se pueden transferir a otras cuentas ni canjear por dinero. Solo sirven para desbloquear contenido y funciones dentro de Fridge Wise."))
            .font(Typeface.micro)
            .foregroundStyle(Palette.inkFaint)
            .fixedSize(horizontal: false, vertical: true)
            .screenPadding()
    }
}

// MARK: - Tarjeta de canje

struct RewardCard: View {
    let reward: Reward
    let balance: Int
    var onRedeem: () -> Void

    private var canAfford: Bool { balance >= reward.cost }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            ZStack {
                Circle().fill(reward.accent.color.opacity(0.15))
                Image(systemName: reward.icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(reward.accent.color)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(reward.title)
                    .font(Typeface.cardTitle)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(reward.detail)
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Space.xs)

            Button {
                onRedeem()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(reward.cost)")
                        .font(Typeface.action)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(InkButtonStyle(
                fill: canAfford ? reward.accent.color : Palette.canvasSunken,
                foreground: canAfford ? Palette.onInk : Palette.inkFaint,
                verticalPadding: 10,
                fullWidth: true
            ))
            .disabled(!canAfford)
        }
        .padding(Space.md)
        .frame(width: 212, height: 232, alignment: .topLeading)
        .background { RoundedRectangle.soft(Radius.card).fill(Palette.surface) }
        .overlay {
            RoundedRectangle.soft(Radius.card)
                .strokeBorder(reward.accent.color.opacity(0.2), lineWidth: Stroke.hairline)
        }
        .shadow(color: Palette.cardShadow, radius: 14, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reward.title). \(reward.detail). \(reward.cost) puntos")
    }
}
