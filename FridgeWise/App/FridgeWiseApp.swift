//
//  FridgeWiseApp.swift
//  FridgeWise
//

import SwiftUI

@main
struct FridgeWiseApp: App {

    @State private var app = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.app, app)
                // La app tiene identidad propia en claro y oscuro; no forzamos
                // un esquema. Forzar `.dark` es una señal clásica de app apurada.
                .tint(Palette.ink)
                // Dynamic Type hasta Accesibilidad 3. Los componentes densos
                // (calendario, segmentados) se acotan por su cuenta.
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                .task { await app.onLaunch() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                app.onForeground()
            case .background:
                Task { await app.save() }
            default:
                break
            }
        }
    }
}
