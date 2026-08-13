//
//  TrackingConsent.swift
//  FridgeWise
//
//  App Tracking Transparency.
//
//  Requisitos que respeta esta implementación:
//  · Guideline 5.1.2 + ATT: sin autorización NO se accede al IDFA ni se
//    comparte nada con brokers. Los anuncios pasan a contextuales.
//  · El prompt del sistema se muestra UNA sola vez en la vida de la app; por eso
//    va precedido de una pantalla propia que explica el porqué. Pedirlo en frío
//    al primer segundo quema la única oportunidad y baja la tasa de aceptación.
//  · NUNCA se bloquea funcionalidad por rechazar el tracking. Condicionar
//    features al consentimiento es rechazo directo.
//  · El prompt solo se puede mostrar con la app en foreground activo.
//

import SwiftUI
import AppTrackingTransparency
import AdSupport

@MainActor
@Observable
final class TrackingConsent {

    enum Status: Equatable {
        case notDetermined
        case authorized
        case denied
        case restricted     // control parental / gestión de dispositivo

        var allowsPersonalization: Bool { self == .authorized }
    }

    private(set) var status: Status = .notDetermined
    /// El usuario ya vio nuestra explicación previa.
    private(set) var didShowPrimer = false

    init() {
        refresh()
    }

    func refresh() {
        status = switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized:    .authorized
        case .denied:        .denied
        case .restricted:    .restricted
        case .notDetermined: .notDetermined
        @unknown default:    .notDetermined
        }
    }

    var canAskSystemPrompt: Bool {
        status == .notDetermined
    }

    func markPrimerShown() {
        didShowPrimer = true
    }

    /// Lanza el prompt del sistema. Llamar SOLO después de nuestra explicación
    /// previa y con la app activa.
    func requestAuthorization() async {
        guard canAskSystemPrompt else { return }
        let result = await ATTrackingManager.requestTrackingAuthorization()
        status = switch result {
        case .authorized:    .authorized
        case .denied:        .denied
        case .restricted:    .restricted
        case .notDetermined: .notDetermined
        @unknown default:    .notDetermined
        }
    }

    /// Identificador publicitario. Devuelve `nil` salvo autorización explícita.
    /// Es el único punto de la app que lo toca.
    var advertisingIdentifier: String? {
        guard status == .authorized else { return nil }
        let id = ASIdentifierManager.shared().advertisingIdentifier
        guard id.uuidString != "00000000-0000-0000-0000-000000000000" else { return nil }
        return id.uuidString
    }
}

// MARK: - Explicación previa

/// Pantalla propia que se muestra ANTES del prompt del sistema.
/// Honesta y sin dark patterns: "No, gracias" tiene el mismo peso visual que aceptar.
struct TrackingPrimerView: View {
    var onContinue: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: Space.lg) {
            ZStack {
                Circle().fill(Palette.surface)
                FluidBackdrop(palette: .pantry, intensity: 0.3).clipShape(Circle())
                Image(systemName: "hand.raised")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Palette.plum)
            }
            .frame(width: 88, height: 88)
            .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: Stroke.hairline) }

            VStack(spacing: 6) {
                Text(String(localized: "Sobre los anuncios")).displayStyle(26)
                Text(String(localized: "y tu privacidad"))
                    .font(Typeface.displayItalic(26))
                    .foregroundStyle(Palette.ink)
                    .squiggleUnderline(Palette.plum)
            }
            .multilineTextAlignment(.center)

            Text(String(localized: "La versión gratuita se sostiene con publicidad. Si nos das permiso, los anuncios son más relevantes y nos pagan mejor, lo que nos deja mantener gratis el escaneo.\n\nSi dices que no, la app funciona exactamente igual: vas a ver los mismos anuncios, pero genéricos."))
                .bodyStyle()
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xs)

            VStack(spacing: Space.xs) {
                Button(String(localized: "Continuar")) { onContinue() }
                    .buttonStyle(InkButtonStyle(fullWidth: true))

                Button(String(localized: "No, gracias")) { onSkip() }
                    .buttonStyle(QuietButtonStyle(fullWidth: true))
            }
            .padding(.top, Space.xs)

            Text(String(localized: "Nunca vendemos tus fotos ni tu despensa. Puedes cambiar esto cuando quieras desde Ajustes."))
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
                .multilineTextAlignment(.center)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity)
    }
}
