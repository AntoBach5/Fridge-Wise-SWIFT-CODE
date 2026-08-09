//
//  RootView.swift
//  FridgeWise
//
//  Contenedor raíz. No usa `TabView`: cada tab tiene su propio `NavigationStack`
//  y se cambia con un `ZStack` + opacidad, para poder controlar la transición
//  y que la pill flotante nunca se re-monte al cambiar de sección.
//

import SwiftUI

struct RootView: View {

    @Environment(\.app) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selection: AppTab = .kitchen
    @State private var isTabBarDimmed = false

    // Un path por tab: el back stack de Recetas no se pisa con el de Listas.
    @State private var kitchenPath = NavigationPath()
    @State private var recipesPath = NavigationPath()
    @State private var listsPath = NavigationPath()
    @State private var rewardsPath = NavigationPath()

    var body: some View {
        ZStack(alignment: .bottom) {
            CanvasBackground()

            content
                .ignoresSafeArea(.keyboard, edges: .bottom)

            PillTabBar(selection: $selection, isDimmed: isTabBarDimmed) {
                app.isPresentingScanner = true
            }
            .padding(.bottom, Space.xs)
        }
        .toastLayer(app.toast)
        // Escáner: pantalla completa porque es una tarea con cámara — un sheet
        // parcial encima de la cámara se siente barato y complica el encuadre.
        .fullScreenCover(isPresented: Binding(
            get: { app.isPresentingScanner },
            set: { app.isPresentingScanner = $0 }
        )) {
            ScanFlowView()
        }
        .sheet(isPresented: Binding(
            get: { app.isPresentingPaywall },
            set: { app.isPresentingPaywall = $0 }
        )) {
            PaywallView()
        }
        .sheet(item: Binding(
            get: { app.limitPrompt },
            set: { app.limitPrompt = $0 }
        )) { prompt in
            LimitReachedSheet(prompt: prompt)
                .presentationDetents([.height(430)])
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Palette.canvas)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: selection) { _, _ in
            // Al cambiar de sección la pill vuelve a estado normal.
            withAnimation(Motion.standard) { isTabBarDimmed = false }
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        ZStack {
            tabContainer(.kitchen) {
                NavigationStack(path: $kitchenPath) {
                    KitchenView(isTabBarDimmed: $isTabBarDimmed)
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }

            tabContainer(.recipes) {
                NavigationStack(path: $recipesPath) {
                    RecipeFeedView(isTabBarDimmed: $isTabBarDimmed)
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }

            tabContainer(.lists) {
                NavigationStack(path: $listsPath) {
                    ListsView(isTabBarDimmed: $isTabBarDimmed)
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }

            tabContainer(.rewards) {
                NavigationStack(path: $rewardsPath) {
                    RewardsView(isTabBarDimmed: $isTabBarDimmed)
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
        }
    }

    /// Cross-fade con un desplazamiento mínimo. Sin el slide completo de un
    /// `TabView`, que a esta escala se siente pesado.
    @ViewBuilder
    private func tabContainer<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isActive = selection == tab

        content()
            .opacity(isActive ? 1 : 0)
            .scaleEffect(isActive || reduceMotion ? 1 : 0.985)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
            .motion(.easeOut(duration: 0.22), value: isActive)
    }

    // MARK: - Rutas

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .recipeDetail(let id):
            if let recipe = recipe(for: id) {
                RecipeDetailView(recipe: recipe)
            }
        case .communityThread(let id):
            if let recipe = recipe(for: id) {
                CommunityThreadView(recipe: recipe)
            }
        case .ingredientDetail:
            EmptyView()
        case .pointsShop:
            PointsShopView()
        case .rewardCatalog:
            RewardCatalogView()
        case .settings:
            SettingsView()
        case .blockedUsers:
            BlockedUsersView()
        case .dataAndPrivacy:
            DataPrivacyView()
        }
    }

    private func recipe(for id: Recipe.ID) -> Recipe? {
        app.feed.first { $0.id == id }
            ?? app.lastGeneration.first { $0.id == id }
    }
}
