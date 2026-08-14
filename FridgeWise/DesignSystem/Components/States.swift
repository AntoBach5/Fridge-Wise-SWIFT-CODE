//
//  States.swift
//  FridgeWise
//
//  Estados vacíos, de carga y notificaciones.
//  Regla de la casa: un estado vacío NUNCA es un texto gris centrado.
//  Siempre tiene una ilustración con movimiento, una frase con voz propia,
//  y exactamente una acción.
//

import SwiftUI

// MARK: - Texto expandible

/// Texto que se corta a N líneas y ofrece expandirse **solo si de verdad se cortó**.
///
/// La detección es real, no por longitud de caracteres: `ViewThatFits` intenta
/// colocar el texto entero en el alto disponible y, si no cabe, cae a la rama
/// vacía que marca el truncado. Mostrar "Leer más" bajo un texto que ya se ve
/// completo es ruido, y no mostrarlo cuando falta media frase es peor.
struct ExpandableText: View {

    let text: String
    var collapsedLines: Int = 3
    var font: Font = Typeface.body
    var lineSpacing: CGFloat = 4
    var accent: Color = Palette.plum

    @State private var isExpanded = false
    @State private var isTruncated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(text)
                .font(font)
                .foregroundStyle(Palette.ink)
                .lineSpacing(lineSpacing)
                .lineLimit(isExpanded ? nil : collapsedLines)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    ViewThatFits(in: .vertical) {
                        Text(text)
                            .font(font)
                            .lineSpacing(lineSpacing)
                            .hidden()
                        Color.clear.task { isTruncated = true }
                    }
                }

            if isTruncated {
                Button {
                    Haptics.select()
                    withAnimation(Motion.standard) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded
                             ? String(localized: "Leer menos")
                             : String(localized: "Leer más"))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .font(Typeface.micro)
                    .fontWeight(.semibold)
                    .foregroundStyle(accent)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityHint(isTruncated && !isExpanded
                           ? String(localized: "Toca dos veces para leer el texto completo")
                           : "")
        .accessibilityAddTraits(isTruncated ? .isButton : [])
        .accessibilityAction {
            if isTruncated { withAnimation(Motion.standard) { isExpanded.toggle() } }
        }
    }
}

// MARK: - Vacío

struct EmptyStateView: View {
    let headline: String
    let emphasis: String?
    let message: String
    var systemImage: String = "sparkles"
    var accent: Color = Palette.sage
    var palette: FluidPalette = .pantry
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Palette.surface)
                    .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }
                    .overlay {
                        FluidBackdrop(palette: palette, intensity: 0.30)
                            .clipShape(Circle())
                    }

                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(accent)
                    .symbolEffect(.pulse)
            }
            .frame(width: 96, height: 96)
            .padding(.bottom, Space.xs)

            VStack(spacing: 4) {
                Text(headline)
                    .displayStyle(23)
                    .multilineTextAlignment(.center)

                if let emphasis {
                    Text(emphasis)
                        .font(Typeface.displayItalic(23))
                        .foregroundStyle(Palette.ink)
                        .squiggleUnderline(accent)
                        .padding(.bottom, 4)
                }
            }

            Text(message)
                .bodyStyle()
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            if let actionTitle, let action {
                Button(actionTitle) {
                    Haptics.commit()
                    action()
                }
                .buttonStyle(InkButtonStyle())
                .padding(.top, Space.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
    }
}

// MARK: - Carga

/// Barrido de brillo para esqueletos. Se apaga con "Reducir movimiento".
struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, Palette.surfaceRaised.opacity(0.85), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.55)
                        .offset(x: phase * proxy.size.width * 1.6)
                        .blendMode(.plusLighter)
                    }
                }
            }
            .clipped()
            .task {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

/// Bloque esqueleto con la forma del contenido real. Nunca un spinner:
/// el esqueleto le dice al usuario qué va a aparecer.
struct SkeletonBlock: View {
    var height: CGFloat = 14
    var width: CGFloat? = nil
    var radius: CGFloat = Radius.xs

    var body: some View {
        RoundedRectangle.soft(radius)
            .fill(Palette.hairline.opacity(0.65))
            .frame(width: width, height: height)
            .shimmering()
    }
}

/// Esqueleto con la silueta exacta de una `RecipeCard`.
struct RecipeCardSkeleton: View {
    var body: some View {
        SoftCard(padding: Space.md) {
            VStack(alignment: .leading, spacing: Space.sm) {
                RoundedRectangle.soft(Radius.md)
                    .fill(Palette.hairline.opacity(0.5))
                    .frame(height: 118)
                    .shimmering()
                SkeletonBlock(height: 16, width: 190)
                SkeletonBlock(height: 12, width: 130)
                HStack(spacing: Space.xs) {
                    SkeletonBlock(height: 20, width: 58, radius: Radius.pill)
                    SkeletonBlock(height: 20, width: 72, radius: Radius.pill)
                }
            }
        }
    }
}

// MARK: - Notificación efímera

/// Banner que baja desde arriba. Se usa para "+15 puntos", "Agregado a To Buy",
/// "Límite del plan gratuito alcanzado".
struct ToastBanner: View {
    let message: String
    var systemImage: String = "checkmark"
    var accent: Color = Palette.basil
    var detail: String? = nil

    var body: some View {
        HStack(spacing: Space.sm) {
            ZStack {
                Circle().fill(accent.opacity(0.16))
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(message)
                    .font(Typeface.action)
                    .foregroundStyle(Palette.ink)
                if let detail {
                    Text(detail)
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkFaint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 11)
        .background {
            Capsule(style: .continuous).fill(Palette.surfaceRaised)
        }
        .overlay {
            Capsule(style: .continuous).strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
        }
        .shadow(color: Palette.cardShadowDeep, radius: 22, x: 0, y: 10)
        .padding(.horizontal, Space.screen)
    }
}

/// Presenta el toast activo de `AppEnvironment` encima de cualquier vista.
struct ToastLayer: ViewModifier {
    let toast: ToastPayload?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast {
                ToastBanner(message: toast.message,
                            systemImage: toast.systemImage,
                            accent: toast.accent.color,
                            detail: toast.detail)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, Space.xs)
            }
        }
        .motion(Motion.entrance, value: toast)
    }
}

struct ToastPayload: Equatable, Identifiable {
    let id = UUID()
    var message: String
    var detail: String? = nil
    var systemImage: String = "checkmark"
    var accent: AccentFamily = .basil
}

extension View {
    func toastLayer(_ toast: ToastPayload?) -> some View {
        modifier(ToastLayer(toast: toast))
    }
}
