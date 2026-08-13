//
//  ReviewViews.swift
//  FridgeWise
//
//  Comentarios y valoraciones.
//
//  Cada fila lleva su menú de moderación (reportar / bloquear) accesible en dos
//  toques. No está escondido en un submenú ni requiere ir a Ajustes: la
//  Guideline 1.2 pide que reportar sea trivial, y además es lo correcto.
//

import SwiftUI

// MARK: - Fila de comentario

struct ReviewRow: View {

    let review: Review
    let recipe: Recipe
    var compact: Bool = false

    @Environment(\.app) private var app
    @State private var isReporting = false
    @State private var showsBlockConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            header

            Text(review.body)
                .font(Typeface.body)
                .foregroundStyle(Palette.ink)
                .lineSpacing(4)
                .lineLimit(compact ? 3 : nil)
                .fixedSize(horizontal: false, vertical: true)

            if let variation = review.variationNote {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 9, weight: .semibold))
                    Text(variation)
                        .font(Typeface.micro)
                        .italic()
                }
                .foregroundStyle(Palette.plum)
            }

            if review.moderation == .underReview {
                moderationNotice
            }

            if !compact {
                footer
            }
        }
        .padding(.vertical, compact ? Space.xs : Space.sm)
        .contextMenu {
            moderationActions
        }
        .sheet(isPresented: $isReporting) {
            ReportSheet(review: review)
                .presentationDetents([.height(560)])
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Palette.canvas)
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            String(localized: "¿Bloquear a \(review.author.displayName)?"),
            isPresented: $showsBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Bloquear"), role: .destructive) {
                app.block(review.author)
            }
            Button(String(localized: "Cancelar"), role: .cancel) {}
        } message: {
            Text(String(localized: "No vas a ver más sus comentarios ni sus recetas. Puedes desbloquearlo desde Ajustes."))
        }
    }

    private var header: some View {
        HStack(spacing: Space.xs) {
            AvatarBadge(initials: review.author.initials, accent: review.author.accent)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(review.author.displayName)
                        .font(Typeface.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.ink)

                    if review.author.isVerifiedCook {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.basil)
                            .accessibilityLabel(String(localized: "Cocinero verificado"))
                    }
                }

                HStack(spacing: 5) {
                    StarRating(rating: Double(review.rating), size: 9)
                    Text("·").foregroundStyle(Palette.inkFaint)
                    Text(review.relativeDate)
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkFaint)
                }
            }

            Spacer(minLength: 0)

            if !compact {
                Menu {
                    moderationActions
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.inkFaint)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "Opciones del comentario"))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Space.md) {
            Button {
                app.markHelpful(review, on: recipe)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: review.didMarkHelpful ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 11, weight: .medium))
                    Text(String(localized: "Útil"))
                        .font(Typeface.micro)
                        .fontWeight(.semibold)
                    if review.helpfulCount > 0 {
                        Text("\(review.helpfulCount)")
                            .font(Typeface.micro)
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(review.didMarkHelpful ? Palette.basil : Palette.inkSoft)
            }
            .buttonStyle(.plain)
            .disabled(review.didMarkHelpful)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private var moderationNotice: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 9, weight: .semibold))
            Text(String(localized: "En revisión. Solo lo ves tú por ahora."))
                .font(Typeface.micro)
                .fontWeight(.medium)
        }
        .foregroundStyle(Palette.turmeric)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background { Capsule().fill(Palette.turmeric.opacity(0.12)) }
    }

    @ViewBuilder
    private var moderationActions: some View {
        Button {
            Haptics.select()
            isReporting = true
        } label: {
            Label(String(localized: "Reportar comentario"), systemImage: "flag")
        }

        Button(role: .destructive) {
            Haptics.select()
            showsBlockConfirmation = true
        } label: {
            Label(String(localized: "Bloquear a \(review.author.displayName)"),
                  systemImage: "hand.raised")
        }
    }
}

// MARK: - Avatar

struct AvatarBadge: View {
    let initials: String
    var accent: AccentFamily = .sage
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle().fill(accent.color.opacity(0.18))
            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold, design: .serif))
                .foregroundStyle(accent.color)
        }
        .frame(width: size, height: size)
        .overlay { Circle().strokeBorder(accent.color.opacity(0.22), lineWidth: Stroke.hairline) }
        .accessibilityHidden(true)
    }
}

// MARK: - Hilo completo

struct CommunityThreadView: View {

    let recipe: Recipe

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var isWriting = false
    @State private var sort: Sort = .helpful

    enum Sort: String, CaseIterable, Hashable {
        case helpful, recent, critical

        var title: String {
            switch self {
            case .helpful:  String(localized: "Más útiles")
            case .recent:   String(localized: "Recientes")
            case .critical: String(localized: "Críticos")
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                summary
                MorphingSegments(items: Sort.allCases, title: \.title, selection: $sort)
                    .screenPadding()

                let reviews = sortedReviews
                if reviews.isEmpty {
                    EmptyStateView(
                        headline: String(localized: "Nadie comentó"),
                        emphasis: String(localized: "todavía"),
                        message: String(localized: "Si la cocinaste, cuenta cómo te fue. Ayuda a que otros se decidan."),
                        systemImage: "bubble.left",
                        accent: Palette.plum,
                        palette: .intelligence,
                        actionTitle: String(localized: "Escribir el primero"),
                        action: { isWriting = true }
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(reviews.enumerated()), id: \.element.id) { index, review in
                            ReviewRow(review: review, recipe: recipe)
                            if index < reviews.count - 1 {
                                Hairline()
                            }
                        }
                    }
                    .screenPadding()
                }

                communityGuidelines
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .editorialScrollFeel()
        .canvasBackground()
        .navigationTitle(String(localized: "Comentarios"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.canvas, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            Button {
                Haptics.select()
                isWriting = true
            } label: {
                Label(String(localized: "Escribir un comentario"), systemImage: "square.and.pencil")
            }
            .buttonStyle(InkButtonStyle(fullWidth: true))
            .padding(.horizontal, Space.screen)
            .padding(.bottom, Space.md)
        }
        .sheet(isPresented: $isWriting) {
            ReviewComposerSheet(recipe: recipe)
                .presentationDetents([.height(480)])
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Palette.canvas)
                .presentationDragIndicator(.visible)
        }
    }

    private var sortedReviews: [Review] {
        let base = app.reviews(for: recipe)
        return switch sort {
        case .helpful:  base.sorted { $0.helpfulCount > $1.helpfulCount }
        case .recent:   base.sorted { $0.createdAt > $1.createdAt }
        case .critical: base.filter { $0.rating <= 3 }.sorted { $0.rating < $1.rating }
        }
    }

    private var summary: some View {
        SoftCard {
            HStack(spacing: Space.lg) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(format: "%.1f", recipe.rating))
                        .font(Typeface.display(34))
                        .foregroundStyle(Palette.ink)
                    StarRating(rating: recipe.rating, size: 12)
                    Text(String(localized: "\(recipe.ratingCount) valoraciones"))
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkFaint)
                }

                Spacer(minLength: Space.md)

                VStack(spacing: 5) {
                    ForEach([5, 4, 3, 2, 1], id: \.self) { stars in
                        HStack(spacing: 6) {
                            Text("\(stars)")
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Palette.inkFaint)
                                .frame(width: 8)
                            ProgressTrack(value: distribution(for: stars),
                                          accent: Palette.turmeric, height: 4)
                        }
                    }
                }
                .frame(width: 110)
            }
        }
        .screenPadding()
    }

    /// Distribución sintética a partir del promedio. En producción viene del backend.
    private func distribution(for stars: Int) -> Double {
        let distance = abs(Double(stars) - recipe.rating)
        return max(0.04, 1 - distance / 2.6)
    }

    /// Guideline 1.2: las normas y el contacto tienen que estar publicados
    /// y ser alcanzables desde donde ocurre el contenido.
    private var communityGuidelines: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Hairline()
                .padding(.bottom, Space.xs)

            Text(String(localized: "Normas de la comunidad")).eyebrow()

            Text(SupportContact.moderationSLA)
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Space.md) {
                Link(String(localized: "Ver normas"), destination: SupportContact.guidelinesURL)
                Link(String(localized: "Contactar moderación"),
                     destination: URL(string: "mailto:\(SupportContact.moderationEmail)")!)
            }
            .font(Typeface.micro)
            .fontWeight(.semibold)
            .foregroundStyle(Palette.plum)
            .padding(.top, 2)
        }
        .screenPadding()
        .padding(.top, Space.md)
    }
}
