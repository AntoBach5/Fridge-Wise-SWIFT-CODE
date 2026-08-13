//
//  ReportSheet.swift
//  FridgeWise
//
//  Reportar contenido. Guideline 1.2, punto 2.
//
//  Está escrito para que reportar sea rápido y sin fricción: un motivo, una nota
//  opcional, listo. Nada de pedir cuenta, ni justificaciones, ni confirmaciones
//  encadenadas. Cuanta más fricción, menos reportes, y menos reportes es
//  exactamente lo que Apple no quiere ver en una app con UGC.
//

import SwiftUI

struct ReportSheet: View {

    let review: Review

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var reason: ReportReason?
    @State private var note = ""
    @State private var alsoBlock = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header

            ScrollView {
                VStack(spacing: Space.xs) {
                    ForEach(ReportReason.allCases) { option in
                        reasonRow(option)
                    }

                    if reason != nil {
                        noteField
                        blockToggle
                    }
                }
                .padding(.bottom, Space.md)
            }
            .scrollIndicators(.hidden)
            .dismissKeyboardOnDrag()

            submitButton
        }
        .padding(.top, Space.lg)
        .padding(.bottom, Space.md)
        .screenPadding()
        .canvasBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(String(localized: "Reportar")).displayStyle(26)

            Text(String(localized: "Cuéntanos qué pasa con el comentario de \(review.author.displayName). Lo revisamos en menos de 24 horas."))
                .bodyStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func reasonRow(_ option: ReportReason) -> some View {
        let isSelected = reason == option

        return Button {
            Haptics.select()
            withAnimation(Motion.standard) { reason = option }
        } label: {
            HStack(alignment: .top, spacing: Space.sm) {
                ZStack {
                    Circle().fill(isSelected ? Palette.tomato.opacity(0.16) : Palette.canvasSunken)
                    Image(systemName: option.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? Palette.tomato : Palette.inkSoft)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(Typeface.headline)
                        .foregroundStyle(Palette.ink)
                    Text(option.detail)
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                DrawnCheckbox(isOn: isSelected, accent: Palette.tomato, size: 20)
                    .padding(.top, 2)
            }
            .padding(Space.sm)
            .background {
                RoundedRectangle.soft(Radius.md)
                    .fill(isSelected ? Palette.tomato.opacity(0.07) : Palette.surface)
            }
            .overlay {
                RoundedRectangle.soft(Radius.md)
                    .strokeBorder(isSelected ? Palette.tomato.opacity(0.3) : Palette.hairline,
                                  lineWidth: Stroke.hairline)
            }
        }
        .buttonStyle(.pressableCard)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(String(localized: "Algo más (opcional)")).eyebrow()

            TextField(String(localized: "Contexto que nos ayude a decidir"),
                      text: $note, axis: .vertical)
                .font(Typeface.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(2...4)
                .padding(Space.sm)
                .background { RoundedRectangle.soft(Radius.md).fill(Palette.surface) }
                .overlay {
                    RoundedRectangle.soft(Radius.md)
                        .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
                }
        }
        .padding(.top, Space.xs)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var blockToggle: some View {
        Button {
            Haptics.tick()
            withAnimation(Motion.tap) { alsoBlock.toggle() }
        } label: {
            HStack(spacing: Space.sm) {
                DrawnCheckbox(isOn: alsoBlock, accent: Palette.tomato, size: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "Bloquear también a \(review.author.displayName)"))
                        .font(Typeface.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(String(localized: "No vas a ver más su contenido"))
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkFaint)
                }

                Spacer(minLength: 0)
            }
            .padding(Space.sm)
        }
        .buttonStyle(.plain)
        .transition(.opacity)
    }

    private var submitButton: some View {
        VStack(spacing: Space.xs) {
            Button(String(localized: "Enviar reporte")) {
                guard let reason else { return }
                app.report(review, reason: reason,
                           note: note.isEmpty ? nil : note)
                if alsoBlock {
                    app.block(review.author)
                }
                dismiss()
            }
            .buttonStyle(InkButtonStyle(fill: Palette.tomato, fullWidth: true))
            .disabled(reason == nil)
            .opacity(reason == nil ? 0.45 : 1)

            Text(String(localized: "También puedes escribirnos a \(SupportContact.moderationEmail)"))
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkFaint)
        }
    }
}
