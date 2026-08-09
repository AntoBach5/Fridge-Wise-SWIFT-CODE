//
//  ReviewComposerSheet.swift
//  FridgeWise
//
//  Escribir un comentario.
//
//  Detalles que importan:
//  · El filtro corre MIENTRAS escribís, no al enviar. Enterarte de que tu
//    comentario no se puede publicar después de escribirlo es hostil.
//  · La primera vez hay que aceptar las normas (Guideline 1.2 exige un EULA
//    con tolerancia cero al contenido abusivo antes de participar).
//  · Los puntos se muestran en el botón, no como sorpresa posterior.
//

import SwiftUI

struct ReviewComposerSheet: View {

    let recipe: Recipe

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 0
    @State private var body_: String = ""
    @State private var advisory: String?
    @State private var isBlocked = false
    @State private var showsAgreement = false
    @FocusState private var isFocused: Bool

    private let characterLimit = 600

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header
            ratingPicker
            editor

            if let advisory {
                advisoryBanner(advisory)
            }

            Spacer(minLength: 0)

            publishButton
        }
        .padding(.top, Space.lg)
        .padding(.bottom, Space.md)
        .screenPadding()
        .canvasBackground()
        .dismissKeyboardOnDrag()
        .task {
            showsAgreement = app.profile.agreement.needsAcceptance
            if !showsAgreement { isFocused = true }
        }
        .sheet(isPresented: $showsAgreement) {
            CommunityAgreementSheet(
                onAccept: {
                    app.profile.agreement = CommunityAgreement(
                        acceptedVersion: CommunityAgreement.currentVersion,
                        acceptedAt: .now
                    )
                    showsAgreement = false
                    isFocused = true
                },
                onDecline: {
                    showsAgreement = false
                    dismiss()
                }
            )
            .presentationDetents([.height(520)])
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(Palette.canvas)
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Secciones

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(String(localized: "¿Cómo te salió?")).displayStyle(25)
            Text(recipe.title)
                .font(Typeface.callout)
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
        }
    }

    private var ratingPicker: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(String(localized: "Tu valoración")).eyebrow()

            HStack(spacing: Space.xs) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        Haptics.tick()
                        withAnimation(Motion.tap) { rating = value }
                    } label: {
                        Image(systemName: value <= rating ? "star.fill" : "star")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(value <= rating ? Palette.turmeric : Palette.hairline)
                            .scaleEffect(value == rating ? 1.12 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "\(value) estrellas"))
                    .accessibilityAddTraits(value == rating ? [.isSelected, .isButton] : .isButton)
                }

                Spacer()

                if rating > 0 {
                    Text(ratingCaption)
                        .font(Typeface.micro)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.turmeric)
                        .transition(.opacity)
                }
            }
            .motion(Motion.tap, value: rating)
        }
    }

    private var ratingCaption: String {
        switch rating {
        case 1: String(localized: "No funcionó")
        case 2: String(localized: "Le falta")
        case 3: String(localized: "Está bien")
        case 4: String(localized: "Muy buena")
        default: String(localized: "Excelente")
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text(String(localized: "Tu experiencia")).eyebrow()
                Spacer()
                Text("\(body_.count)/\(characterLimit)")
                    .font(Typeface.micro)
                    .monospacedDigit()
                    .foregroundStyle(body_.count > characterLimit ? Palette.tomato : Palette.inkFaint)
            }

            ZStack(alignment: .topLeading) {
                if body_.isEmpty {
                    Text(String(localized: "¿La cambiaste en algo? ¿Algún truco que descubriste? Eso es lo que más ayuda."))
                        .font(Typeface.body)
                        .foregroundStyle(Palette.inkFaint)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.sm + 2)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $body_)
                    .font(Typeface.body)
                    .foregroundStyle(Palette.ink)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
            }
            .frame(height: 130)
            .background { RoundedRectangle.soft(Radius.md).fill(Palette.surface) }
            .overlay {
                RoundedRectangle.soft(Radius.md)
                    .strokeBorder(borderColor, lineWidth: Stroke.hairline)
            }
            .onChange(of: body_) { _, text in
                screen(text)
            }
        }
    }

    private var borderColor: Color {
        if isBlocked { return Palette.tomato.opacity(0.5) }
        if advisory != nil { return Palette.turmeric.opacity(0.5) }
        return Palette.hairline
    }

    private func screen(_ text: String) {
        guard text.count > 8 else {
            advisory = nil
            isBlocked = false
            return
        }
        let result = app.moderation.screen(text)
        withAnimation(Motion.standard) {
            advisory = result.advisory
            isBlocked = !result.canPublish
        }
    }

    private func advisoryBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Space.xs) {
            Image(systemName: isBlocked ? "xmark.octagon" : "exclamationmark.triangle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isBlocked ? Palette.tomato : Palette.turmeric)
                .padding(.top, 1)

            Text(message)
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle.soft(Radius.sm)
                .fill((isBlocked ? Palette.tomato : Palette.turmeric).opacity(0.10))
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Publicar

    private var publishButton: some View {
        VStack(spacing: Space.xs) {
            Button {
                publish()
            } label: {
                HStack(spacing: 7) {
                    Text(String(localized: "Publicar"))
                    Text(String(localized: "+\(PointsEvent.reviewPosted.amount) pts"))
                        .font(Typeface.micro)
                        .fontWeight(.bold)
                        .opacity(0.7)
                }
            }
            .buttonStyle(InkButtonStyle(fullWidth: true))
            .disabled(!canPublish)
            .opacity(canPublish ? 1 : 0.45)

            Text(String(localized: "Al publicar aceptás las normas de la comunidad."))
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
        }
    }

    private var canPublish: Bool {
        rating > 0
            && body_.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
            && body_.count <= characterLimit
            && !isBlocked
    }

    private func publish() {
        let result = app.postReview(on: recipe, rating: rating, body: body_)
        switch result {
        case .published:
            dismiss()
        case .flagged(let reason):
            app.showToast(ToastPayload(
                message: String(localized: "Publicado, en revisión"),
                detail: reason,
                systemImage: "clock", accent: .turmeric
            ))
            dismiss()
        case .rejected(let reason):
            withAnimation(Motion.standard) {
                advisory = reason
                isBlocked = true
            }
        }
    }
}

// MARK: - Normas

/// Guideline 1.2: aceptación explícita de términos con tolerancia cero
/// al contenido abusivo, ANTES de poder publicar.
struct CommunityAgreementSheet: View {

    var onAccept: () -> Void
    var onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Antes de")).displayStyle(26)
                Text(String(localized: "participar"))
                    .font(Typeface.displayItalic(26))
                    .foregroundStyle(Palette.ink)
                    .squiggleUnderline(Palette.plum)
                    .padding(.bottom, Space.xxs)
            }

            VStack(alignment: .leading, spacing: Space.md) {
                rule("hand.raised", String(localized: "Tolerancia cero"),
                     String(localized: "Nada de acoso, odio ni contenido sexual. Retiramos y bloqueamos sin aviso."))
                rule("cross.case", String(localized: "Seguridad alimentaria"),
                     String(localized: "No publiques consejos que puedan enfermar a alguien. Revisamos lo que se marca como riesgoso."))
                rule("flag", String(localized: "Reportá lo que veas"),
                     String(localized: "Cada comentario tiene la opción de reportar. Respondemos en menos de 24 horas."))
                rule("doc.on.doc", String(localized: "Contenido propio"),
                     String(localized: "Publicá recetas y fotos tuyas, o dá crédito a quien corresponda."))
            }

            Spacer(minLength: 0)

            VStack(spacing: Space.xs) {
                Button(String(localized: "Acepto las normas")) { onAccept() }
                    .buttonStyle(InkButtonStyle(fullWidth: true))

                Button(String(localized: "Ahora no")) { onDecline() }
                    .font(Typeface.action)
                    .foregroundStyle(Palette.inkSoft)

                HStack(spacing: Space.sm) {
                    Link(String(localized: "Normas completas"), destination: SupportContact.guidelinesURL)
                    Text("·").foregroundStyle(Palette.inkFaint)
                    Link(String(localized: "Términos"), destination: SupportContact.termsURL)
                }
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
                .padding(.top, 2)
            }
        }
        .padding(.top, Space.xl)
        .padding(.bottom, Space.md)
        .screenPadding()
        .canvasBackground()
    }

    private func rule(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            ZStack {
                Circle().fill(Palette.plum.opacity(0.13))
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.plum)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typeface.headline)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
