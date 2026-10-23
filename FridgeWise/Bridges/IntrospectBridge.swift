//
//  IntrospectBridge.swift
//  FridgeWise
//
//  Puente a siteline/swiftui-introspect.
//  https://github.com/siteline/swiftui-introspect
//
//  Introspect es un bisturí, no un martillo. Cada uso aquí está justificado porque
//  SwiftUI puro NO expone la propiedad, y cada uno es reversible si Apple algún día
//  publica la API nativa: se borra el cuerpo del modifier y la app sigue funcionando.
//
//  Lo que arreglamos:
//  · `keyboardDismissMode` en scroll views  → SwiftUI no lo expone en iOS 17.
//  · Rubber-band horizontal en carruseles   → evita el "wobble" en rieles cortos.
//  · Fondo del UITableView en sheets legacy → mata el gris de sistema.
//  · Indicadores de scroll                  → apagados en carruseles con paginado.
//  · Delaying de content touches            → botones dentro de scroll responden al toque.
//
//  Nota de versiones: si SPM resuelve una versión de Introspect que todavía no
//  conoce `.v18`, borra `.v18` de las listas de plataforma de abajo.
//

import SwiftUI
import UIKit

#if canImport(SwiftUIIntrospect)
import SwiftUIIntrospect
#endif

extension View {

    /// Cierra el teclado al arrastrar. Imprescindible en el composer de comentarios
    /// y en el buscador de ingredientes.
    func dismissKeyboardOnDrag() -> some View {
        #if canImport(SwiftUIIntrospect)
        self.introspect(.scrollView, on: .iOS(.v17, .v18)) { scrollView in
            scrollView.keyboardDismissMode = .interactive
        }
        #else
        self
        #endif
    }

    /// Riel horizontal que no hace rubber-band cuando el contenido es más corto
    /// que la pantalla. Sin esto, un carrusel de 2 tarjetas "tiembla" al tocarlo.
    ///
    /// Además queda bloqueado por eje: un riel horizontal metido dentro de un
    /// scroll vertical se queda quieto si el arrastre empezó siendo vertical.
    /// Esto es lo que evitaba que la pantalla se fuera de lado al scrollear en
    /// diagonal, que es como se scrollea de verdad con el pulgar.
    func tightHorizontalRail() -> some View {
        self
            .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])
            .introspectScrollView { scrollView in
                scrollView.alwaysBounceHorizontal = false
                scrollView.alwaysBounceVertical = false
                scrollView.showsHorizontalScrollIndicator = false
                scrollView.isDirectionalLockEnabled = true
                // Los botones dentro del riel responden al primer toque en lugar de
                // esperar a que el scroll decida si es un drag.
                scrollView.delaysContentTouches = false
            }
    }

    /// Scroll vertical con la desaceleración lenta que usa Apple en apps editoriales.
    /// Hace que las listas largas se sientan más "pesadas" y menos resbaladizas.
    /// Incluye el bloqueo de eje de `lockedVerticalScroll()`.
    func editorialScrollFeel() -> some View {
        self
            .lockedVerticalScroll()
            .introspectScrollView { scrollView in
                scrollView.decelerationRate = .normal
                scrollView.delaysContentTouches = false
            }
    }

    /// Scroll que SOLO se mueve en vertical.
    ///
    /// El síntoma era que la pantalla se desplazaba de lado al scrollear. Son
    /// tres causas que se suman, y se atacan las tres:
    ///
    /// 1. `isDirectionalLockEnabled` — en cuanto UIKit decide que el arrastre es
    ///    vertical, ignora por completo la componente horizontal durante todo el
    ///    gesto. Es el arreglo de fondo: sin él, cualquier diagonal arrastra.
    /// 2. `alwaysBounceHorizontal = false` + `scrollBounceBehavior` — matan el
    ///    rebote lateral en los bordes, que es la parte del movimiento que el
    ///    usuario percibe como "la pantalla se va".
    /// 3. `contentOffset.x` fijado a 0 — red de seguridad. Si algún hijo mide
    ///    más que el viewport (un título largo, una tarjeta con sombra), el
    ///    scroll view se vuelve desplazable en horizontal aunque sus ejes sean
    ///    verticales, y entonces nada de lo anterior alcanza.
    ///
    /// La condición 3 no se puede expresar en SwiftUI puro, y por eso este
    /// modificador sigue necesitando Introspect.
    func lockedVerticalScroll() -> some View {
        self
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .introspectScrollView { scrollView in
                scrollView.isDirectionalLockEnabled = true
                scrollView.alwaysBounceHorizontal = false
                scrollView.showsHorizontalScrollIndicator = false
                scrollView.showsVerticalScrollIndicator = false
                if scrollView.contentSize.width <= scrollView.bounds.width,
                   scrollView.contentOffset.x != 0 {
                    scrollView.contentOffset.x = 0
                }
            }
    }

    /// Un solo punto de entrada a Introspect para los scroll views.
    ///
    /// Centralizarlo tiene un motivo concreto: la lista de plataformas hay que
    /// ampliarla cada vez que sale una versión de iOS, y repartida por seis
    /// modificadores se olvida uno. Cuando no hay versión declarada el bloque
    /// simplemente no corre, la app no se rompe, pero el ajuste se pierde —
    /// y un bug de scroll que vuelve "solo en los iPhone nuevos" es muy caro
    /// de encontrar.
    @ViewBuilder
    private func introspectScrollView(
        _ customize: @escaping (UIScrollView) -> Void
    ) -> some View {
        #if canImport(SwiftUIIntrospect)
        self.introspect(.scrollView, on: .iOS(.v17, .v18), customize: customize)
        #else
        self
        #endif
    }

    /// Elimina el fondo gris del `UITableView` que sigue apareciendo en algunos
    /// contextos de sheet, y mata los separadores nativos que rompen el diseño.
    func stripSystemListChrome() -> some View {
        #if canImport(SwiftUIIntrospect)
        self.introspect(.list, on: .iOS(.v17, .v18)) { collectionView in
            collectionView.backgroundColor = .clear
            collectionView.backgroundView = nil
        }
        #else
        self
        #endif
    }

    /// Permite el gesto de "swipe back" incluso cuando ocultamos el back button
    /// nativo por uno custom. Sin esto los usuarios quedan atrapados en el detalle.
    ///
    /// Aplicar sobre el `NavigationStack`, no sobre la pantalla de detalle: el
    /// delegado tiene que sobrevivir a que el detalle se cierre.
    func keepInteractivePopGesture() -> some View {
        modifier(InteractivePopGesture())
    }

    /// Oculta la tab bar nativa por completo: la app usa la pill custom.
    /// (Se mantiene el `TabView` nativo por el manejo de estado y accesibilidad.)
    func hideSystemTabBar() -> some View {
        #if canImport(SwiftUIIntrospect)
        self.introspect(.tabView, on: .iOS(.v17, .v18)) { tabBarController in
            tabBarController.tabBar.isHidden = true
            tabBarController.tabBar.isUserInteractionEnabled = false
        }
        #else
        self
        #endif
    }

    /// Ajusta el inset inferior del scroll para que la pill flotante nunca tape
    /// la última fila, sin tener que meter un spacer fantasma en cada vista.
    func inset(forFloatingTabBar height: CGFloat = Space.tabBarInset) -> some View {
        #if canImport(SwiftUIIntrospect)
        self.introspect(.scrollView, on: .iOS(.v17, .v18)) { scrollView in
            var insets = scrollView.contentInset
            guard insets.bottom < height else { return }
            insets.bottom = height
            scrollView.contentInset = insets
            scrollView.verticalScrollIndicatorInsets.bottom = height
        }
        #else
        self.safeAreaInset(edge: .bottom) { Color.clear.frame(height: height) }
        #endif
    }
}

// MARK: - Swipe-back

/// Delegado propio para el gesto de volver atrás.
///
/// El atajo habitual es poner `interactivePopGestureRecognizer.delegate = nil`,
/// y es justamente lo que hacía que la pantalla se arrastrara de lado durante un
/// scroll vertical: sin delegado, el reconocedor acepta CUALQUIER arrastre, en
/// cualquier dirección, incluso en la raíz del stack donde no hay nada que
/// desapilar. El resultado es una pantalla que se mueve sola y no vuelve a nada.
///
/// Este delegado impone las dos condiciones que el sistema aplicaría de fábrica:
/// que haya algo detrás, y que el gesto sea claramente horizontal hacia la derecha.
final class InteractivePopGestureDelegate: NSObject, UIGestureRecognizerDelegate {

    weak var navigationController: UINavigationController?

    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController,
              navigationController.viewControllers.count > 1,
              let pan = recognizer as? UIPanGestureRecognizer
        else { return false }

        let translation = pan.translation(in: pan.view)
        return translation.x > abs(translation.y)
    }

    /// El swipe-back y el scroll vertical no compiten: o uno o el otro.
    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        false
    }
}

private struct InteractivePopGesture: ViewModifier {

    /// `@State` mantiene vivo al delegado mientras exista el stack: el
    /// `UIGestureRecognizer` lo referencia de forma débil.
    @State private var delegate = InteractivePopGestureDelegate()

    func body(content: Content) -> some View {
        #if canImport(SwiftUIIntrospect)
        content.introspect(.navigationStack, on: .iOS(.v17, .v18)) { navigationController in
            delegate.navigationController = navigationController
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = delegate
        }
        #else
        content
        #endif
    }
}
