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
    func tightHorizontalRail() -> some View {
        #if canImport(SwiftUIIntrospect)
        self.introspect(.scrollView, on: .iOS(.v17, .v18)) { scrollView in
            scrollView.alwaysBounceHorizontal = false
            scrollView.showsHorizontalScrollIndicator = false
            // Los botones dentro del riel responden al primer toque en lugar de
            // esperar a que el scroll decida si es un drag.
            scrollView.delaysContentTouches = false
        }
        #else
        self
        #endif
    }

    /// Scroll vertical con la desaceleración lenta que usa Apple en apps editoriales.
    /// Hace que las listas largas se sientan más "pesadas" y menos resbaladizas.
    func editorialScrollFeel() -> some View {
        #if canImport(SwiftUIIntrospect)
        self.introspect(.scrollView, on: .iOS(.v17, .v18)) { scrollView in
            scrollView.decelerationRate = .normal
            scrollView.showsVerticalScrollIndicator = false
            scrollView.delaysContentTouches = false
        }
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
