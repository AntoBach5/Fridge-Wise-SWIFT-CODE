//
//  LiquidGlass.swift
//  FridgeWise
//
//  Capa de cristal del sistema de diseño, construida sobre la API oficial de
//  Apple (`glassEffect`, `GlassEffectContainer`, `glassEffectID`).
//
//  Por qué un archivo propio y no `.ultraThinMaterial` suelto en cada vista:
//
//  · Liquid Glass NO es un material. Un material desenfoca lo que hay detrás y
//    se queda quieto. El cristal de Apple además refracta los bordes, tiene
//    reflejo especular, responde al toque y —lo que de verdad lo delata— se
//    FUNDE con los cristales vecinos cuando se mueven. Eso último solo existe
//    dentro de un `GlassEffectContainer`, así que todas las barras de la app
//    pasan por `GlassRail`.
//
//  · El proyecto despliega desde iOS 17 y la API vive en iOS 26, de modo que
//    cada uso está doblemente protegido:
//      - `#if compiler(>=6.2)` → el SDK de iOS 26 viaja con Swift 6.2. Sin esta
//        guarda, compilar con un Xcode anterior fallaría aunque el `#available`
//        estuviera bien escrito: el símbolo `Glass` no existiría todavía.
//      - `if #available(iOS 26.0, *)` → en tiempo de ejecución.
//    El camino alternativo imita el cristal con material + especular + sombra.
//    No es igual (nada lo es), pero se lee como cristal y no como un gris.
//
//  · Cero azul de sistema, igual que el resto de la paleta: el tinte sale
//    siempre de `Palette`.
//

import SwiftUI

// MARK: - Roles

/// Para qué se usa el cristal. Define el tinte base y el contraste del borde,
/// que es lo único que cambia entre un control sobre papel y una insignia
/// flotando sobre la cámara.
enum GlassRole {

    /// Barras flotantes y cromo de navegación. Tinte de tinta: la pill tiene que
    /// seguir leyéndose como el objeto oscuro de la marca.
    case chrome

    /// Segmentados, chips, campos de búsqueda. Sobre papel cálido.
    case control

    /// Insignias sobre la cámara o sobre una foto. Cristal oscuro, texto blanco.
    case overlay

    /// Tinte del cristal nativo. Bajo a propósito: el cristal de Apple ya aporta
    /// su propio fondo, el tinte solo lo empuja hacia la marca.
    var nativeTint: Color? {
        switch self {
        case .chrome:  Palette.inkSolid.opacity(0.62)
        case .control: nil
        case .overlay: Color.black.opacity(0.28)
        }
    }

    /// Relleno de respaldo para iOS 17–18, debajo del material.
    var fallbackFill: Color {
        switch self {
        case .chrome:  Palette.inkSolid.opacity(0.88)
        case .control: Palette.surface.opacity(0.55)
        case .overlay: Color.black.opacity(0.38)
        }
    }

    /// Reflejo del borde. En el cromo y en los overlays el brillo va arriba
    /// (luz que cae); en los controles sobre papel basta el hairline cálido.
    var fallbackStroke: AnyShapeStyle {
        switch self {
        case .chrome, .overlay:
            AnyShapeStyle(LinearGradient(
                colors: [.white.opacity(0.26), .white.opacity(0.04)],
                startPoint: .top, endPoint: .bottom
            ))
        case .control:
            AnyShapeStyle(LinearGradient(
                colors: [.white.opacity(0.45), Palette.hairline],
                startPoint: .top, endPoint: .bottom
            ))
        }
    }
}

// MARK: - Disponibilidad

enum LiquidGlass {

    /// `true` solo si el cristal nativo existe en este dispositivo.
    /// Las vistas la consultan para decidir contraste de texto, nunca para
    /// dibujar: el dibujo lo resuelve el modificador.
    static var isSupported: Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { return true }
        #endif
        return false
    }
}

// MARK: - Superficie

/// Pone cristal detrás del contenido, recortado a `shape`.
private struct GlassSurface<S: InsettableShape>: ViewModifier {

    let shape: S
    let role: GlassRole
    /// El cristal se deforma y brilla bajo el dedo. Solo en elementos tocables.
    let isInteractive: Bool
    /// Sombra propia. Se apaga cuando el elemento ya vive dentro de una barra
    /// que proyecta la suya: dos sombras apiladas ensucian el borde.
    let castsShadow: Bool

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(nativeGlass, in: shape)
                .shadow(color: shadowColor,
                        radius: castsShadow ? 22 : 0,
                        x: 0, y: castsShadow ? 11 : 0)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var nativeGlass: Glass {
        var glass = Glass.regular
        if let tint = role.nativeTint { glass = glass.tint(tint) }
        if isInteractive { glass = glass.interactive() }
        return glass
    }
    #endif

    private var shadowColor: Color {
        switch role {
        case .chrome:  Color.black.opacity(0.22)
        case .control: Palette.cardShadow
        case .overlay: Color.black.opacity(0.30)
        }
    }

    /// Respaldo para iOS 17–18: material + relleno cálido + especular.
    /// El orden importa — el material va encima del relleno para que el
    /// desenfoque siga leyéndose y el relleno solo aporte temperatura.
    @ViewBuilder
    private func fallback(_ content: Content) -> some View {
        content
            .background { shape.fill(role.fallbackFill) }
            .background { shape.fill(.ultraThinMaterial) }
            .overlay { shape.strokeBorder(role.fallbackStroke, lineWidth: Stroke.hairline) }
            .shadow(color: shadowColor,
                    radius: castsShadow ? 20 : 0,
                    x: 0, y: castsShadow ? 10 : 0)
    }
}

/// El mismo cristal, teñido con un color de produce. Chips activos, botón de
/// escanear, acciones con carga semántica.
private struct TintedGlassSurface<S: InsettableShape>: ViewModifier {

    let shape: S
    let accent: Color
    let isInteractive: Bool

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(tinted, in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var tinted: Glass {
        let glass = Glass.regular.tint(accent)
        return isInteractive ? glass.interactive() : glass
    }
    #endif

    @ViewBuilder
    private func fallback(_ content: Content) -> some View {
        content
            .background { shape.fill(accent) }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.35), .clear],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: Stroke.hairline
                )
            }
    }
}

// MARK: - Identidad para el morphing

/// Marca un cristal para que el contenedor lo reconozca entre estados y lo haga
/// fluir en vez de desaparecer y reaparecer. Es lo que convierte el indicador
/// de un segmentado en una gota que viaja y se estira.
private struct GlassMorphID<ID: Hashable & Sendable>: ViewModifier {

    let id: ID
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - API

extension View {

    /// Cristal líquido detrás del contenido.
    ///
    ///     Text("Para ti")
    ///         .padding(.horizontal, Space.md)
    ///         .liquidGlass(in: Capsule(style: .continuous), role: .control)
    func liquidGlass<S: InsettableShape>(
        in shape: S,
        role: GlassRole = .control,
        interactive: Bool = false,
        shadow: Bool = true
    ) -> some View {
        modifier(GlassSurface(shape: shape, role: role,
                              isInteractive: interactive, castsShadow: shadow))
    }

    /// Cristal teñido con un acento de la paleta.
    func liquidGlass<S: InsettableShape>(
        in shape: S,
        tint: Color,
        interactive: Bool = true
    ) -> some View {
        modifier(TintedGlassSurface(shape: shape, accent: tint, isInteractive: interactive))
    }

    /// Cápsula de cristal: el 90% de los usos (chips, pills, campos, barras).
    func glassCapsule(
        role: GlassRole = .control,
        interactive: Bool = false,
        shadow: Bool = true
    ) -> some View {
        liquidGlass(in: Capsule(style: .continuous), role: role,
                    interactive: interactive, shadow: shadow)
    }

    /// Identidad del cristal dentro de un `GlassRail`.
    func glassMorphID<ID: Hashable & Sendable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        modifier(GlassMorphID(id: id, namespace: namespace))
    }
}

// MARK: - Barra de navegación

extension View {
    /// Fondo de papel para la barra de navegación solo antes de iOS 26.
    /// En iOS 26 la barra es Liquid Glass y se separa del contenido con el
    /// scroll edge effect; un fondo opaco propio lo anula (HIG · Toolbars).
    @ViewBuilder
    func legacyNavigationBarBackground(_ color: Color) -> some View {
        if LiquidGlass.isSupported {
            self
        } else {
            self.toolbarBackground(color, for: .navigationBar)
        }
    }
}

// MARK: - Contenedor

/// Agrupa cristales hermanos para que se fundan y se separen al moverse.
///
/// Sin este contenedor, dos cápsulas de cristal una al lado de la otra son dos
/// recortes independientes y el efecto se cae: cada una desenfoca su propio
/// trozo de fondo y entre ellas queda una costura. Dentro del contenedor el
/// sistema las resuelve como un solo cuerpo de cristal, y cuando una se
/// desplaza —cambio de segmento, scroll de un riel, aparición del botón de
/// escanear— se estiran y se despegan como gotas. `spacing` es la distancia a
/// la que empiezan a atraerse.
struct GlassRail<Content: View>: View {

    var spacing: CGFloat = Space.sm
    @ViewBuilder var content: Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
