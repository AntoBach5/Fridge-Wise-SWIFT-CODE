//
//  PillTabBar.swift
//  FridgeWise
//
//  La pill oscura flotante de la referencia, extendida a cinco destinos.
//
//  Decisiones:
//  · El indicador activo es un chip claro que VIAJA con matchedGeometryEffect.
//  · "Escanear" no es un tab más: es un botón de acento en el centro, con su propio
//    peso visual, porque es la acción que define el producto.
//  · La pill se contrae a ~72% de opacidad y baja 4pt cuando el usuario scrollea
//    hacia abajo, así el contenido manda. Vuelve al instante al frenar.
//  · Cero `TabView` nativo visible: usamos el nuestro y ocultamos el del sistema.
//

import SwiftUI

struct PillTabBar: View {
    @Binding var selection: AppTab
    /// Se atenúa mientras el usuario scrollea hacia abajo.
    var isDimmed: Bool = false
    var onScanTapped: () -> Void

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Space.sm) {
            pill
            scanButton
        }
        .padding(.horizontal, Space.screen)
        .opacity(isDimmed ? 0.72 : 1)
        .offset(y: isDimmed ? 4 : 0)
        .motion(Motion.standard, value: isDimmed)
    }

    // MARK: Pill

    private var pill: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.barItems) { tab in
                tabButton(tab)
            }
        }
        .padding(5)
        .background {
            Capsule(style: .continuous)
                .fill(Palette.inkSolid)
                .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 12)
        }
        .overlay {
            // Highlight superior: hace que la pill se lea como un objeto sólido
            // con luz encima, no como un rectángulo negro.
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: Stroke.hairline
                )
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        return Button {
            guard !isSelected else { return }
            Haptics.select()
            withAnimation(Motion.morph) { selection = tab }
        } label: {
            ZStack {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Palette.onInk.opacity(0.14))
                        .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                }

                Image(systemName: isSelected ? tab.filledIcon : tab.icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Palette.onInk : Palette.onInk.opacity(0.48))
                    .symbolEffect(.bounce, value: isSelected && !reduceMotion)
                    .frame(width: 52, height: 40)
            }
            .frame(width: 52, height: 40)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: Botón de escaneo

    private var scanButton: some View {
        Button {
            Haptics.commit()
            onScanTapped()
        } label: {
            ZStack {
                Circle()
                    .fill(Palette.tomato)
                    .shadow(color: Palette.tomato.opacity(0.38), radius: 18, x: 0, y: 9)

                // Anillo de respiración: llama la atención sin animación agresiva.
                Circle()
                    .strokeBorder(Palette.tomato.opacity(0.32), lineWidth: 1)
                    .scaleEffect(reduceMotion ? 1 : 1.22)
                    .opacity(reduceMotion ? 0 : 0.8)

                Image(systemName: "viewfinder")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Palette.onInk)
            }
            .frame(width: 54, height: 54)
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel(String(localized: "Escanear nevera"))
        .accessibilityHint(String(localized: "Abre la cámara para detectar ingredientes"))
    }
}

// MARK: - Detector de dirección de scroll

/// Publica si el usuario está scrolleando hacia abajo, para atenuar la pill.
/// Usa `.onScrollGeometryChange` cuando existe y cae a un `GeometryReader`
/// en `background` en iOS 17.
struct ScrollDirectionReader: ViewModifier {
    @Binding var isScrollingDown: Bool
    @State private var lastOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ScrollOffsetKey.self,
                                value: proxy.frame(in: .named("scroll")).minY)
            }
        }
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            let delta = offset - lastOffset
            guard abs(delta) > 6 else { return }
            let goingDown = delta < 0
            if goingDown != isScrollingDown {
                withAnimation(Motion.standard) { isScrollingDown = goingDown }
            }
            lastOffset = offset
        }
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func readsScrollDirection(into binding: Binding<Bool>) -> some View {
        modifier(ScrollDirectionReader(isScrollingDown: binding))
    }
}
