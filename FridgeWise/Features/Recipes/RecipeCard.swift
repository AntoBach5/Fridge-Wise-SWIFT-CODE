//
//  RecipeCard.swift
//  FridgeWise
//
//  La tarjeta que más se repite en la app, en dos densidades.
//
//  Jerarquía de lectura, en este orden y no otro:
//    1. la imagen (¿me da hambre?)
//    2. el título en serif (¿qué es?)
//    3. el match con la despensa (¿puedo hacerlo AHORA?)
//    4. las métricas (¿me conviene?)
//
//  El match va tercero y con color propio porque es la respuesta a la pregunta
//  que trae al usuario a esta app. Una tarjeta de receta genérica pondría las
//  calorías ahí; nosotros no somos una app de calorías.
//

import SwiftUI

struct RecipeCard: View {

    let recipe: Recipe
    var style: Style = .full

    enum Style {
        /// Tarjeta ancha del feed principal.
        case full
        /// Tarjeta de riel horizontal.
        case rail
    }

    @Environment(\.app) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            artwork
            details
        }
        .background {
            RoundedRectangle.soft(Radius.card).fill(Palette.surface)
        }
        .overlay {
            RoundedRectangle.soft(Radius.card)
                .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
        }
        .clipShape(RoundedRectangle.soft(Radius.card))
        .shadow(color: Palette.cardShadow, radius: 16, x: 0, y: 7)
        .frame(width: style == .rail ? 248 : nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Arte

    private var artwork: some View {
        ZStack(alignment: .topLeading) {
            RecipeHeroArt(recipe: recipe)
                .frame(height: style == .full ? 158 : 122)
                .frame(maxWidth: .infinity)

            HStack(alignment: .top) {
                SourceBadge(source: recipe.source, compact: style == .rail)
                Spacer()
                saveButton
            }
            .padding(Space.sm)
        }
    }

    private var saveButton: some View {
        Button {
            app.toggleSave(recipe)
        } label: {
            Image(systemName: app.isSaved(recipe) ? "bookmark.fill" : "bookmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(app.isSaved(recipe) ? Palette.clay : Palette.inkSoft)
                .frame(width: 30, height: 30)
                .background { Circle().fill(Palette.surface.opacity(0.92)) }
                .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
                .symbolEffect(.bounce, value: app.isSaved(recipe))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(app.isSaved(recipe)
            ? String(localized: "Quitar de guardadas")
            : String(localized: "Guardar receta"))
    }

    // MARK: - Detalle

    private var details: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.title)
                    .font(Typeface.cardTitle)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if style == .full {
                    Text(recipe.subtitle)
                        .font(Typeface.callout)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                }
            }

            matchIndicator

            Hairline()

            metrics
        }
        .padding(Space.md)
    }

    /// La línea que responde "¿puedo hacerlo ahora?".
    private var matchIndicator: some View {
        HStack(spacing: Space.xs) {
            AccentDot(color: matchColor, size: 7)

            Text(recipe.matchDescription)
                .font(Typeface.micro)
                .fontWeight(.semibold)
                .foregroundStyle(matchColor)

            Spacer(minLength: Space.xs)

            if style == .full {
                // Micro-barra de match: el dato numérico sin ocupar una fila.
                Capsule()
                    .fill(Palette.hairline.opacity(0.8))
                    .frame(width: 44, height: 3)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(matchColor)
                            .frame(width: 44 * recipe.pantryMatch, height: 3)
                    }
            }
        }
    }

    private var matchColor: Color {
        switch recipe.pantryMatch {
        case 1:      Palette.basil
        case 0.7...: Palette.turmeric
        default:     Palette.clay
        }
    }

    private var metrics: some View {
        HStack(spacing: style == .full ? Space.md : Space.sm) {
            metric("clock", "\(recipe.minutes)′")
            DifficultyMeter(level: recipe.difficulty, showsLabel: style == .full)
            metric("flame", "\(recipe.calories)")

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Circle()
                    .fill(recipe.grade.color)
                    .frame(width: 16, height: 16)
                    .overlay {
                        Text(recipe.grade.letter)
                            .font(.system(size: 9, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                    }
            }
        }
    }

    private func metric(_ icon: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.inkFaint)
            Text(value)
                .font(Typeface.micro)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(Palette.inkSoft)
        }
    }

    private var accessibilityDescription: String {
        """
        \(recipe.title). \(recipe.subtitle). \
        \(recipe.matchDescription). \(recipe.minutes) minutos. \
        \(recipe.calories) calorías. \
        \(String(localized: "Salud nutricional")) \(recipe.grade.letter), \(recipe.grade.caption).
        """
    }
}

// MARK: - Fila compacta

/// Versión de una línea, para "guardadas" y resultados de búsqueda.
struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: Space.sm) {
            RecipeHeroArt(recipe: recipe)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle.soft(Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(Typeface.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(recipe.minutes)′")
                    Text("·")
                    Text("\(recipe.calories) kcal")
                    Text("·")
                    Text(recipe.grade.letter)
                        .foregroundStyle(recipe.grade.color)
                        .fontWeight(.semibold)
                }
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(.vertical, Space.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
