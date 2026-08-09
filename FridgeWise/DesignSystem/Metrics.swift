//
//  Metrics.swift
//  FridgeWise
//
//  Escala de espaciado, radios y grosores. Todo múltiplo de 4.
//  Nada en la app usa un número mágico: si aparece un `padding(13)` en un PR, se rechaza.
//

import SwiftUI

enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 44

    /// Margen lateral de pantalla. Amplio a propósito — es lo que da el aire editorial.
    static let screen: CGFloat = 22

    /// Espacio reservado abajo para que la pill del tab bar nunca tape contenido.
    static let tabBarInset: CGFloat = 108
}

enum Radius {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let card: CGFloat = 22
    static let lg: CGFloat = 28
    static let sheet: CGFloat = 34
    static let pill: CGFloat = 999
}

enum Stroke {
    /// Hairline de tarjeta. Sub-punto: se ve nítido en pantallas @3x.
    static let hairline: CGFloat = 0.75
    static let regular: CGFloat = 1.5
    static let heavy: CGFloat = 2.5
}

extension RoundedRectangle {
    /// Siempre esquinas continuas (squircle). Las circulares se ven de Android.
    static func soft(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

extension View {
    /// Margen lateral estándar de pantalla.
    func screenPadding() -> some View {
        self.padding(.horizontal, Space.screen)
    }
}
