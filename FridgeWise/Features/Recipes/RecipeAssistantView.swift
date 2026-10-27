//
//  RecipeAssistantView.swift
//  FridgeWise
//
//  La barra de búsqueda de "Para ti" y la conversación que abre.
//
//  Qué es y qué no es:
//
//  · NO es un buscador de texto sobre el feed. Eso ya lo hacen los filtros, y
//    una lupa que solo filtra títulos en una app de 30 recetas es decorado.
//    Esta barra es la entrada a preguntar en lenguaje natural lo que la app ya
//    sabe: qué hay en la despensa, qué vence, qué se puede cocinar hoy.
//
//  · El modelo todavía no está conectado. La decisión importante es cómo se
//    comporta mientras no lo esté: la conversación se abre, el mensaje se
//    envía, se guarda en el hilo y el asistente contesta UNA vez, diciendo la
//    verdad — que todavía no sabe responder. La alternativa (tragarse el
//    mensaje en silencio) se percibe como una app rota, no como una función
//    que viene en camino, y es la clase de detalle por el que la gente deja
//    una reseña de una estrella antes de volver a abrirla.
//
//  · Las sugerencias se construyen con la despensa REAL del usuario. Es lo que
//    hace que la pantalla vacía no se sienta vacía, y de paso le enseña qué
//    clase de preguntas van a funcionar cuando el modelo entre.
//
//  La transición: la barra es el origen de un zoom hacia la hoja (iOS 18+), así
//  que la conversación crece desde la propia barra en lugar de aparecer desde
//  abajo. Donde no existe esa API, la hoja entra con su animación normal.
//

import SwiftUI

// MARK: - Barra

/// Campo de cristal que abre el asistente. No escribe: es un botón con forma
/// de campo. Un `TextField` que al tocarlo salta a otra pantalla pierde las
/// primeras letras que el usuario ya estaba tecleando.
struct RecipeAssistantBar: View {

    var accent: Color = Palette.plum
    var onOpen: () -> Void

    @Environment(\.app) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hintIndex = 0

    var body: some View {
        Button {
            Haptics.select()
            onOpen()
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(Typeface.scaled(15, weight: .medium))
                    .foregroundStyle(accent)

                // El índice se acota al leer, no al escribir: la lista de
                // pistas se construye con la despensa y encoge en cuanto deja
                // de haber algo por vencer. Indexar a pelo era un crash a la
                // espera de que el usuario confirmara su último tomate.
                Text(hints[min(hintIndex, hints.count - 1)])
                    .font(Typeface.body)
                    .foregroundStyle(Palette.inkFaint)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .id(hintIndex)
                    .transition(.opacity)

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.circle.fill")
                    .font(Typeface.scaled(20))
                    .foregroundStyle(accent.opacity(0.55))
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 13)
            .glassCapsule(role: .control, interactive: true)
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel(String(localized: "Preguntar al asistente de cocina"))
        .accessibilityHint(String(localized: "Abre una conversación sobre lo que tienes en la despensa"))
        .task(id: hints.count) { await rotateHints() }
    }

    /// El placeholder rota entre preguntas reales. Un placeholder fijo
    /// ("Buscar...") no le dice al usuario qué puede pedir.
    private var hints: [String] {
        var result = [String(localized: "Pregunta qué cocinar hoy")]
        if let expiring = app.expiringSoon.first {
            result.append(String(localized: "¿Qué hago con \(expiring.name.lowercased())?"))
        }
        result.append(String(localized: "Algo rápido con lo que tengo"))
        result.append(String(localized: "Una cena ligera para dos"))
        return result
    }

    private func rotateHints() async {
        hintIndex = 0
        guard !reduceMotion, hints.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                hintIndex = (hintIndex + 1) % hints.count
            }
        }
    }
}

// MARK: - Mensaje

struct AssistantMessage: Identifiable, Equatable {
    enum Author: Equatable { case person, assistant }

    let id = UUID()
    var author: Author
    var text: String
    /// Marca los mensajes que son una nota honesta del sistema y no una
    /// respuesta del modelo. Se pintan distinto a propósito: nunca presentamos
    /// un relleno nuestro con el mismo aspecto que tendrá una respuesta real.
    var isSystemNote: Bool = false
}

// MARK: - Conversación

struct RecipeAssistantView: View {

    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var messages: [AssistantMessage] = []
    @State private var draft = ""
    @State private var isThinking = false
    @FocusState private var isWriting: Bool

    var body: some View {
        ZStack {
            CanvasBackground()

            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.md) {
                            opening

                            ForEach(messages) { message in
                                bubble(message)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.94, anchor: message.author == .person ? .bottomTrailing : .bottomLeading)
                                            .combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }

                            if isThinking {
                                TypingIndicator()
                                    .id(Self.thinkingAnchor)
                            }

                            // Ancla de scroll: un bloque invisible al final es
                            // más fiable que apuntar al último mensaje, que
                            // cambia de id en cada envío.
                            Color.clear
                                .frame(height: 1)
                                .id(Self.bottomAnchor)
                        }
                        .screenPadding()
                        .padding(.top, Space.md)
                        .padding(.bottom, Space.lg)
                    }
                    .scrollIndicators(.hidden)
                    .lockedVerticalScroll()
                    .dismissKeyboardOnDrag()
                    .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
                    .onChange(of: isThinking) { _, _ in scrollToBottom(proxy) }
                }

                composer
            }
        }
    }

    private static let bottomAnchor = "assistant.bottom"
    private static let thinkingAnchor = "assistant.thinking"

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.standard) {
            proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
        }
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(alignment: .center, spacing: Space.sm) {
            ZStack {
                Circle().fill(Palette.plum.opacity(0.15))
                Image(systemName: "sparkles")
                    .font(Typeface.scaled(14, weight: .medium))
                    .foregroundStyle(Palette.plum)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "Asistente de cocina"))
                    .font(Typeface.headline)
                    .foregroundStyle(Palette.ink)
                Text(String(localized: "Conoce tu despensa"))
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.inkFaint)
            }

            Spacer(minLength: 0)

            Button {
                Haptics.select()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(Typeface.scaled(13, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 34, height: 34)
                    .liquidGlass(in: Circle(), role: .control, interactive: true, shadow: false)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Cerrar"))
        }
        .screenPadding()
        .padding(.top, Space.md)
        .padding(.bottom, Space.sm)
        .overlay(alignment: .bottom) { Hairline() }
    }

    // MARK: - Apertura

    /// Lo que se ve antes del primer mensaje. No es un estado vacío: es el
    /// asistente presentándose con datos del usuario.
    @ViewBuilder
    private var opening: some View {
        if messages.isEmpty {
            VStack(alignment: .leading, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Pregúntame por")).displayStyle(26)
                    Text(String(localized: "tu despensa"))
                        .font(Typeface.displayItalic(26))
                        .foregroundStyle(Palette.ink)
                        .squiggleUnderline(Palette.plum)
                }
                .padding(.bottom, Space.xxs)

                Text(pantrySummary)
                    .bodyStyle()
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(String(localized: "Prueba con")).eyebrow()

                    ForEach(starters, id: \.self) { starter in
                        starterChip(starter)
                    }
                }
                .padding(.top, Space.xs)
            }
            .padding(.bottom, Space.sm)
        }
    }

    private var pantrySummary: String {
        let count = app.pantry.count
        guard count > 0 else {
            return String(localized: "Todavía no tengo nada en tu despensa. Escanea la nevera o un ticket y podré proponerte cosas concretas.")
        }
        if let expiring = app.expiringSoon.first {
            return String(localized: "Tengo \(count) ingredientes anotados y sé que tu \(expiring.name.lowercased()) vence pronto. Puedes preguntarme en lenguaje normal.")
        }
        return String(localized: "Tengo \(count) ingredientes anotados. Puedes preguntarme en lenguaje normal.")
    }

    /// Arranques de conversación hechos con la despensa de verdad.
    private var starters: [String] {
        var result: [String] = []
        if let expiring = app.expiringSoon.first {
            result.append(String(localized: "¿Qué cocino con \(expiring.name.lowercased()) antes de que se pase?"))
        }
        result.append(String(localized: "Algo en menos de 20 minutos con lo que tengo"))
        result.append(String(localized: "¿Qué me falta para una cena para cuatro?"))
        return result
    }

    private func starterChip(_ text: String) -> some View {
        Button {
            Haptics.tick()
            send(text)
        } label: {
            HStack(spacing: Space.xs) {
                Text(text)
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(Typeface.scaled(10, weight: .bold))
                    .foregroundStyle(Palette.plum)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 11)
            .liquidGlass(in: RoundedRectangle.soft(Radius.md),
                         role: .control, interactive: true, shadow: false)
        }
        .buttonStyle(.pressableCard)
    }

    // MARK: - Burbujas

    private func bubble(_ message: AssistantMessage) -> some View {
        HStack {
            if message.author == .person { Spacer(minLength: Space.xxl) }

            Text(message.text)
                .font(Typeface.body)
                .foregroundStyle(message.author == .person ? Palette.onInk : Palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
                .padding(.horizontal, Space.md)
                .padding(.vertical, 11)
                .modifier(BubbleSurface(message: message))

            if message.author == .assistant { Spacer(minLength: Space.xxl) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.author == .person
            ? String(localized: "Tú: \(message.text)")
            : String(localized: "Asistente: \(message.text)"))
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: Space.xs) {
            TextField(String(localized: "Escribe tu pregunta"), text: $draft, axis: .vertical)
                .font(Typeface.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(1...4)
                .focused($isWriting)
                .submitLabel(.send)
                .onSubmit { send(draft) }

            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up")
                    .font(Typeface.scaled(13, weight: .bold))
                    .foregroundStyle(Palette.onInk)
                    .frame(width: 32, height: 32)
                    .background { Circle().fill(canSend ? Palette.plum : Palette.inkFaint) }
                    .hitTarget(size: 32)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .motion(Motion.tap, value: canSend)
            .accessibilityLabel(String(localized: "Enviar"))
        }
        .padding(.leading, Space.md)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .glassCapsule(role: .control, interactive: true)
        .overlay {
            Capsule().strokeBorder(isWriting ? Palette.plum.opacity(0.5) : .clear,
                                   lineWidth: Stroke.regular)
        }
        .motion(Motion.standard, value: isWriting)
        .screenPadding()
        .padding(.bottom, Space.sm)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    // MARK: - Envío

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }

        Haptics.commit()
        draft = ""
        isWriting = false

        withAnimation(Motion.entrance) {
            messages.append(AssistantMessage(author: .person, text: trimmed))
            isThinking = true
        }

        Task { await answer() }
    }

    /// El hueco donde va a entrar el modelo.
    ///
    /// Cuando exista, esto llama al generador y devuelve recetas navegables; la
    /// vista no tiene que cambiar, porque ya habla en mensajes. Hasta entonces
    /// contesta una sola vez y lo dice claro: el usuario tiene que salir de aquí
    /// sabiendo que su pregunta no se perdió y que la función no está lista.
    private func answer() async {
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 900))
        guard !Task.isCancelled else { return }

        let reply = String(localized: "Todavía no sé contestar esto — estoy aprendiendo a leer tu despensa. Tu pregunta queda guardada en esta conversación. Mientras tanto, «Generar con lo que tienes» te arma una receta con lo que hay ahora mismo.")
        withAnimation(Motion.standard) {
            isThinking = false
            messages.append(AssistantMessage(
                author: .assistant,
                text: reply,
                isSystemNote: true
            ))
        }
        Haptics.tick()
        // La respuesta aparece fuera del foco de VoiceOver: se anuncia.
        AccessibilityNotification.Announcement(reply).post()
    }
}

// MARK: - Superficie de la burbuja

/// La burbuja del usuario es tinta sólida; la del asistente, cristal. La nota
/// del sistema además va punteada: se tiene que distinguir de un vistazo de lo
/// que algún día sea una respuesta de verdad.
private struct BubbleSurface: ViewModifier {
    let message: AssistantMessage

    func body(content: Content) -> some View {
        switch (message.author, message.isSystemNote) {
        case (.person, _):
            content.background {
                RoundedRectangle.soft(Radius.md).fill(Palette.inkSolid)
            }
        case (.assistant, true):
            content
                .liquidGlass(in: RoundedRectangle.soft(Radius.md),
                             role: .control, shadow: false)
                .overlay {
                    RoundedRectangle.soft(Radius.md)
                        .strokeBorder(Palette.plum.opacity(0.45),
                                      style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
        case (.assistant, false):
            content.liquidGlass(in: RoundedRectangle.soft(Radius.md), role: .control)
        }
    }
}

// MARK: - Indicador de escritura

/// Tres puntos que respiran. Existe para que el silencio entre la pregunta y
/// la respuesta tenga una forma; sin él, enviar un mensaje no parece hacer nada.
private struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Palette.plum.opacity(phase == index ? 0.9 : 0.3))
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == index ? 1.15 : 1)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 13)
        .liquidGlass(in: Capsule(style: .continuous), role: .control, shadow: false)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(280))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.26)) { phase = (phase + 1) % 3 }
            }
        }
        .accessibilityLabel(String(localized: "Pensando"))
    }
}
