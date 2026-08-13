//
//  AdCoordinator.swift
//  FridgeWise
//
//  Política de anuncios. El SDK real (AdMob u otro) se enchufa en
//  `AdProviding`; lo que vive aquí son las REGLAS, que es lo que hay que
//  defender en el review y ante el usuario.
//
//  Reglas duras — ninguna es negociable por producto:
//  1. Cero anuncios para Premium o con el beneficio "día sin anuncios" activo.
//  2. Cero anuncios durante el escaneo y durante el Modo Cocina. Interrumpir a
//     alguien con las manos llenas de harina es hostil y además saca reseñas de 1★.
//  3. Nada de intersticial al abrir la app (Guideline 4.x y sentido común).
//  4. Todo anuncio está rotulado "PUBLICIDAD" y es visualmente distinguible
//     del contenido (Guideline 2.3.1: nada de imitar UI de la app).
//  5. Sin permiso de ATT ⇒ SOLO anuncios contextuales, jamás personalizados.
//  6. Tope de frecuencia: como mucho 1 unidad nativa cada 6 tarjetas y
//     1 intersticial cada 8 minutos, nunca dos seguidos.
//

import SwiftUI

// MARK: - Contrato

protocol AdProviding: Sendable {
    /// `true` si hay inventario listo para mostrar.
    func hasNativeAd() async -> Bool
    /// Personalizado solo si ATT lo autorizó.
    func requestNativeAd(personalized: Bool) async -> NativeAdPayload?
}

struct NativeAdPayload: Identifiable, Sendable, Equatable {
    var id: UUID = UUID()
    var headline: String
    var body: String
    var advertiser: String
    var callToAction: String
    var imageSystemName: String
    var destinationURL: URL?
}

// MARK: - Coordinador

@MainActor
@Observable
final class AdCoordinator {

    /// Contextos donde la app JAMÁS muestra publicidad.
    enum ProtectedContext: String, CaseIterable {
        case scanning, cookingMode, checkout, onboarding
    }

    private(set) var currentNativeAd: NativeAdPayload?
    private(set) var protectedContexts: Set<ProtectedContext> = []
    private var lastInterstitialAt: Date?

    private let provider: AdProviding
    /// Inyectado desde `AppEnvironment`: refleja premium + beneficios canjeados.
    var adsDisabled: () -> Bool = { false }
    var personalizationAllowed: () -> Bool = { false }

    init(provider: AdProviding = HouseAdProvider()) {
        self.provider = provider
    }

    // MARK: Contextos protegidos

    func enterProtectedContext(_ context: ProtectedContext) {
        protectedContexts.insert(context)
        currentNativeAd = nil
    }

    func exitProtectedContext(_ context: ProtectedContext) {
        protectedContexts.remove(context)
    }

    var canShowAds: Bool {
        !adsDisabled() && protectedContexts.isEmpty
    }

    // MARK: Nativos en feed

    /// Cada cuántas tarjetas se intercala una unidad nativa.
    static let feedInterval = 6

    func shouldInsertAd(afterIndex index: Int) -> Bool {
        guard canShowAds else { return false }
        return index > 0 && (index + 1) % Self.feedInterval == 0
    }

    func loadNativeAd() async {
        guard canShowAds else {
            currentNativeAd = nil
            return
        }
        currentNativeAd = await provider.requestNativeAd(
            personalized: personalizationAllowed()
        )
    }

    // MARK: Intersticiales

    /// Solo en transiciones naturales (terminar de cocinar, cerrar una receta),
    /// nunca al abrir la app ni en medio de una tarea.
    func canShowInterstitial() -> Bool {
        guard canShowAds else { return false }
        guard let last = lastInterstitialAt else { return true }
        return Date().timeIntervalSince(last) > 8 * 60
    }

    func didShowInterstitial() {
        lastInterstitialAt = .now
    }
}

// MARK: - Proveedor propio

/// Placeholder de desarrollo: promociona features de la propia app.
/// Sirve además como inventario de relleno cuando la red no tiene fill,
/// así el layout nunca queda con un hueco vacío.
struct HouseAdProvider: AdProviding {
    func hasNativeAd() async -> Bool { true }

    func requestNativeAd(personalized: Bool) async -> NativeAdPayload? {
        NativeAdPayload(
            headline: String(localized: "Cocina sin interrupciones"),
            body: String(localized: "Premium saca los anuncios y te da escaneos y recetas sin límite."),
            advertiser: String(localized: "Fridge Wise"),
            callToAction: String(localized: "Ver Premium"),
            imageSystemName: "sparkles"
        )
    }
}

// MARK: - Vista

/// Unidad nativa rotulada. Comparte el lenguaje visual de la app pero con
/// una diferencia deliberada — fondo hundido y borde punteado — para que
/// nadie la confunda con una receta (Guideline 2.3.1).
struct NativeAdCard: View {
    let payload: NativeAdPayload
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.xs) {
                    Text(String(localized: "Publicidad")).eyebrow(Palette.inkFaint)
                    Rectangle()
                        .fill(Palette.hairline)
                        .frame(height: Stroke.hairline)
                    Text(payload.advertiser)
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkFaint)
                }

                HStack(alignment: .top, spacing: Space.md) {
                    ZStack {
                        RoundedRectangle.soft(Radius.md)
                            .fill(Palette.turmeric.opacity(0.14))
                        Image(systemName: payload.imageSystemName)
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(Palette.turmeric)
                    }
                    .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(payload.headline)
                            .font(Typeface.cardTitle)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        Text(payload.body)
                            .font(Typeface.callout)
                            .foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }

                Text(payload.callToAction)
                    .font(Typeface.action)
                    .foregroundStyle(Palette.turmeric)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle.soft(Radius.card).fill(Palette.canvasSunken)
            }
            .overlay {
                RoundedRectangle.soft(Radius.card)
                    .strokeBorder(
                        Palette.hairline,
                        style: StrokeStyle(lineWidth: Stroke.hairline, dash: [4, 3])
                    )
            }
        }
        .buttonStyle(.pressableCard)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Publicidad: \(payload.headline)"))
    }
}
