//
//  ReceiptScanner.swift
//  FridgeWise
//
//  Lectura de tickets de compra.
//
//  Por qué un servicio aparte del escáner de nevera, si los dos devuelven
//  ingredientes: el problema es de naturaleza distinta. La nevera es visión por
//  computador sobre objetos; el ticket es OCR sobre texto impreso, y el texto
//  SÍ se puede resolver bien hoy y en el dispositivo. Por eso esta
//  implementación no es un mock: usa `VNRecognizeTextRequest` de verdad.
//
//  El 90% del trabajo no es leer el ticket —Vision lo hace— sino descartar lo
//  que no es comida. Un ticket trae cabecera de tienda, CIF, líneas de IVA,
//  formas de pago, puntos de fidelidad y un "GRACIAS POR SU VISITA". Si todo eso
//  entra a la despensa, la app queda con "Efectivo" y "Base imponible" entre los
//  ingredientes y el usuario no vuelve. El filtro de abajo es, por lejos, la
//  parte con más valor del archivo.
//
//  La imagen no sale del dispositivo: Vision corre local. Eso es lo que permite
//  no declarar recolección de datos por este flujo en el Privacy Manifest.
//

import UIKit
import Vision

// MARK: - Contrato

protocol ReceiptScanning: Sendable {
    /// Lee un ticket y va emitiendo el avance, con el mismo contrato que el
    /// escáner de nevera para que la pantalla de escaneo sea una sola.
    func scan(_ image: UIImage) -> AsyncThrowingStream<ScanPhase, Error>
}

// MARK: - Implementación con Vision

struct VisionReceiptScanner: ReceiptScanning {

    func scan(_ image: UIImage) -> AsyncThrowingStream<ScanPhase, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.preparing)

                    let lines = try await Self.recognizeText(in: image)
                    try Task.checkCancellation()

                    // Sin texto reconocible no inventamos nada: devolver
                    // ingredientes plausibles de un ticket que no se leyó sería
                    // mentirle al usuario sobre lo que compró.
                    guard !lines.isEmpty else {
                        continuation.finish(throwing: ScanError.receiptUnreadable)
                        return
                    }

                    let items = ReceiptParser.ingredients(from: lines)
                    guard !items.isEmpty else {
                        continuation.finish(throwing: ScanError.noIngredientsFound)
                        return
                    }

                    var detected: [Ingredient] = []
                    for (index, item) in items.enumerated() {
                        try Task.checkCancellation()

                        continuation.yield(.analyzing(progress: Double(index + 1) / Double(items.count)))
                        // El ritmo es deliberado: los ítems aparecen de a uno
                        // para que el usuario pueda seguir la lectura en vez de
                        // recibir veinte filas de golpe.
                        try await Task.sleep(for: .milliseconds(120))

                        detected.append(item)
                        continuation.yield(.detected(item))
                    }

                    let overall = detected.compactMap(\.confidence).reduce(0, +)
                        / Double(max(detected.count, 1))

                    continuation.yield(.finished(
                        ScanResult(detected: detected, overallConfidence: overall)
                    ))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: ScanError.cancelled)
                } catch let error as ScanError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: ScanError.receiptUnreadable)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// OCR en el dispositivo. Devuelve las líneas en el orden en que aparecen
    /// impresas, que es lo que permite emparejar cantidad y producto después.
    ///
    /// Dos cosas que no son opcionales aquí:
    ///
    /// · Corre en una cola de fondo. `perform` es SÍNCRONO y el
    ///   reconocimiento en nivel `.accurate` sobre la foto de un ticket largo
    ///   tarda cerca de un segundo. Lanzado desde la vista heredaría el hilo
    ///   principal y congelaría la animación del análisis justo mientras el
    ///   usuario la está mirando.
    ///
    /// · El `continuation` se reanuda en un solo sitio por rama. Con el
    ///   `completionHandler` de `VNRecognizeTextRequest` hay un camino en el
    ///   que el handler ya corrió y además `perform` lanza: eso reanuda dos
    ///   veces y el proceso muere. Leyendo `request.results` después de
    ///   `perform` el camino es único.
    private static func recognizeText(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw ScanError.receiptUnreadable }
        let orientation = image.cgImageOrientation

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                // El ticket está en el idioma de la tienda; el inglés entra
                // como red de seguridad para marcas y productos importados.
                request.recognitionLanguages = ["es-ES", "es", "en-US"]

                let handler = VNImageRequestHandler(cgImage: cgImage,
                                                    orientation: orientation,
                                                    options: [:])
                do {
                    try handler.perform([request])
                    let lines = (request.results ?? [])
                        // De arriba hacia abajo. Vision no garantiza el orden y
                        // en un ticket el orden ES la información.
                        .sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
                        .compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: lines)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Parser

/// Convierte las líneas crudas de un ticket en ingredientes de despensa.
/// Está aparte del servicio para poder probarlo con tickets reales sin cámara.
enum ReceiptParser {

    static func ingredients(from lines: [String]) -> [Ingredient] {
        var seen = Set<String>()
        var result: [Ingredient] = []

        for line in lines {
            guard let entry = parse(line) else { continue }

            // Un ticket repite el mismo producto en varias líneas (ofertas,
            // dos unidades sueltas). La despensa no quiere duplicados.
            let key = entry.name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            result.append(Ingredient(
                name: entry.name,
                category: category(for: key),
                quantity: entry.quantity,
                // Lo leído de un ticket nunca entra como certeza: el OCR
                // confunde caracteres y el nombre comercial no es el alimento.
                // Al quedar por debajo de 0.75 cae en "¿Está bien esto?" de la
                // hoja de revisión, que es exactamente donde debe caer.
                confidence: 0.68,
                isConfirmed: false
            ))
        }

        return result
    }

    private struct Entry {
        var name: String
        var quantity: String?
    }

    /// Limpia una línea y decide si es un producto.
    private static func parse(_ raw: String) -> Entry? {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.count >= 3 else { return nil }

        let folded = line.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                 locale: .current)

        // 1. Fuera todo lo que es administración del ticket.
        guard !noise.contains(where: { folded.contains($0) }) else { return nil }

        // 2. Fuera fechas, horas y códigos de barras.
        guard !isMetadata(folded) else { return nil }

        // 3. Cantidad al principio: "2 X ", "2x", "1,250 KG", "0.5 L".
        let quantity = leadingQuantity(in: line)
        if let range = quantity?.range {
            line.removeSubrange(range)
        }

        // 4. Precios y códigos al final: "  1,29", "1.29 €", "x 2,50", "A 21%".
        line = stripTrailingPrices(from: line)
        line = line.trimmingCharacters(in: CharacterSet(charactersIn: " \t-·*.,:;|/"))

        // 5. Lo que queda tiene que parecer un nombre: al menos tres letras
        //    seguidas. "1L" o "UD" no son un producto.
        guard longestLetterRun(in: line) >= 3 else { return nil }
        guard line.count <= 42 else { return nil }

        return Entry(name: prettify(line), quantity: quantity?.text)
    }

    /// Palabras que delatan una línea que no es comida. Se comparan sin tildes
    /// y en minúsculas contra la línea completa.
    private static let noise: [String] = [
        "total", "subtotal", "iva", "i.v.a", "base imponible", "cuota",
        "efectivo", "tarjeta", "credito", "debito", "contactless", "cambio",
        "entrega", "devolucion", "cambios", "importe", "pago", "pagado",
        "ticket", "factura", "simplificada", "num.", "n.", "caja", "cajero",
        "operacion", "transaccion", "autorizacion", "aid", "terminal",
        "cif", "nif", "n.i.f", "c.i.f", "telefono", "tel.", "tfno",
        "www", "http", ".com", ".es", "@",
        "gracias", "vuelva", "visita", "atendido", "atencion al cliente",
        "cliente", "socio", "tarjeta cliente", "puntos", "saldo", "acumulado",
        "ahorro", "descuento total", "oferta aplicada", "promocion",
        "unidades", "art.", "articulos", "linea", "lineas",
        "direccion", "calle", "avda", "avenida", "plaza", "c/", "cp ",
        "horario", "abierto", "supermercado", "hipermercado", "s.a", "s.l",
        "copia", "original", "reservado", "conserve", "garantia", "devoluciones"
    ]

    /// Fechas (12/03/26), horas (19:42), códigos largos y líneas sin letras.
    private static func isMetadata(_ folded: String) -> Bool {
        if folded.range(of: #"\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}"#, options: .regularExpression) != nil {
            return true
        }
        if folded.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) != nil {
            return true
        }
        if folded.range(of: #"\d{8,}"#, options: .regularExpression) != nil {
            return true
        }
        // Una línea donde las letras no llegan a un tercio del total es un
        // código, un importe o una fila de guiones.
        let letters = folded.filter { $0.isLetter }.count
        return letters * 3 < folded.count
    }

    private struct Quantity {
        var text: String
        var range: Range<String.Index>
    }

    /// Cantidad impresa delante del producto. Se guarda como texto porque es lo
    /// que el usuario quiere leer ("2 ud", "1,25 kg"), no un número a convertir.
    private static func leadingQuantity(in line: String) -> Quantity? {
        let patterns = [
            #"^\s*(\d+[.,]?\d*)\s*(kg|g|gr|l|ml|cl|ud|uds|u)\b\.?\s*"#,
            #"^\s*(\d{1,3})\s*[xX*]\s*"#,
            #"^\s*(\d{1,3})\s+(?=\p{L})"#
        ]

        for pattern in patterns {
            guard let match = line.range(of: pattern, options: .regularExpression) else { continue }
            let captured = line[match]
                .trimmingCharacters(in: CharacterSet(charactersIn: " \tTxX*"))
                .replacingOccurrences(of: "  ", with: " ")
            guard !captured.isEmpty else { continue }
            return Quantity(text: normalizedUnit(captured), range: match)
        }
        return nil
    }

    private static func normalizedUnit(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.rangeOfCharacter(from: .letters) != nil { return lower }
        return "\(lower) ud"
    }

    /// Quita importes, porcentajes de IVA y códigos de la cola de la línea.
    private static func stripTrailingPrices(from line: String) -> String {
        var result = line
        let patterns = [
            #"\s*[\d.,]+\s*(€|eur|euros)\s*$"#,
            #"\s*[A-Z]?\s*\d{1,2}\s*%\s*$"#,
            #"\s*[\d]+[.,]\d{2}\s*$"#,
            #"\s*[xX*]\s*[\d.,]+\s*$"#
        ]

        // Se aplica en bucle: una línea puede terminar en "2,50 1,29 €" y hay
        // que pelar las dos, no solo la última.
        var didStrip = true
        while didStrip {
            didStrip = false
            for pattern in patterns {
                guard let range = result.range(of: pattern, options: [.regularExpression, .caseInsensitive])
                else { continue }
                result.removeSubrange(range)
                didStrip = true
            }
        }
        return result
    }

    private static func longestLetterRun(in text: String) -> Int {
        var best = 0
        var current = 0
        for character in text {
            if character.isLetter {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    /// Los tickets vienen EN MAYÚSCULAS. Dejarlas gritando se ve como un error
    /// de la app, no como el ticket.
    private static func prettify(_ text: String) -> String {
        let collapsed = text
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard collapsed == collapsed.uppercased() else { return collapsed }
        return collapsed.localizedCapitalized
    }

    // MARK: Categoría

    /// Heurística por palabra clave. No pretende acertar siempre: la hoja de
    /// revisión deja cambiar la categoría en un toque, y es mejor proponer
    /// "Frutas y verduras" para el tomate que mandar todo a "Condimentos".
    private static func category(for folded: String) -> PantryCategory {
        for (category, words) in categoryKeywords {
            if words.contains(where: { folded.contains($0) }) { return category }
        }
        return .condiments
    }

    private static let categoryKeywords: [(PantryCategory, [String])] = [
        (.frozen, ["congelad", "helado", "nugget", "varitas", "pizza",
                   "guisante", "menestra", "hielo"]),
        (.dairy, ["leche", "yogur", "yoghurt", "queso", "mantequilla", "nata",
                  "crema", "kefir", "cuajada", "flan", "natilla", "mozzarella",
                  "parmesano", "mascarpone", "requeson", "margarina"]),
        (.protein, ["pollo", "pavo", "ternera", "cerdo", "lomo", "solomillo",
                    "jamon", "chorizo", "salchich", "bacon", "panceta",
                    "huevo", "atun", "salmon", "merluza", "bacalao", "gamba",
                    "langostino", "mejillon", "pescado", "carne", "filete",
                    "albondiga", "tofu", "seitan", "lenteja", "garbanzo",
                    "alubia", "judia", "frijol", "soja"]),
        (.produce, ["tomate", "lechuga", "espinaca", "rucula", "canonigo",
                    "cebolla", "ajo", "patata", "zanahoria", "pimiento",
                    "calabac", "calabaza", "berenjena", "pepino", "brocoli",
                    "coliflor", "col ", "repollo", "champinon", "seta",
                    "manzana", "platano", "banana", "naranja", "mandarina",
                    "limon", "lima", "pera", "uva", "fresa", "frambuesa",
                    "arandano", "melon", "sandia", "piña", "pina", "kiwi",
                    "aguacate", "mango", "melocoton", "nectarina", "ciruela",
                    "cereza", "higo", "puerro", "apio", "remolacha", "nabo",
                    "jengibre", "perejil", "cilantro", "albahaca", "fruta",
                    "verdura", "hortaliza", "ensalada"]),
        (.grains, ["arroz", "pasta", "espagueti", "spaghetti", "macarron",
                   "fideo", "tallarin", "lasaña", "lasana", "cuscus", "couscous",
                   "quinoa", "avena", "cereal", "harina", "pan ", "pan.",
                   "barra", "chapata", "tortilla de trigo", "tortita",
                   "galleta", "bizcocho", "tostada", "muesli", "copos"]),
        (.condiments, ["aceite", "vinagre", "sal ", "pimienta", "azucar",
                       "especia", "comino", "pimenton", "curry", "oregano",
                       "mostaza", "ketchup", "mayonesa", "salsa", "caldo",
                       "pastilla", "levadura", "canela", "vainilla", "miel",
                       "mermelada", "cacao", "cafe", "te ", "infusion"])
    ]
}

// MARK: - Orientación

extension UIImage {
    /// Vision trabaja sobre el `CGImage` crudo y se pierde la orientación que
    /// traía la foto. Sin esta traducción, un ticket vertical se analiza
    /// acostado y el OCR devuelve basura.
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:            .up
        case .upMirrored:    .upMirrored
        case .down:          .down
        case .downMirrored:  .downMirrored
        case .left:          .left
        case .leftMirrored:  .leftMirrored
        case .right:         .right
        case .rightMirrored: .rightMirrored
        @unknown default:    .up
        }
    }
}
