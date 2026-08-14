//
//  Persistence.swift
//  FridgeWise
//
//  Persistencia local en JSON dentro de Application Support.
//
//  Por qué no SwiftData/Core Data: el estado de esta app es un puñado de
//  colecciones chicas que se leen enteras al abrir. Un archivo JSON atómico
//  es más simple, más fácil de migrar y trivial de exportar — lo que además
//  nos resuelve el "descarga tus datos" que pide la normativa de privacidad.
//
//  Todo se escribe con `.atomic` para que un cierre forzado no deje el archivo
//  a medio escribir.
//

import Foundation

actor PersistenceStore {

    enum Bucket: String, CaseIterable {
        case pantry
        case lists
        case savedRecipes
        case points
        case profile
        case moderation
        case reviews
        /// Biblioteca de recetas. Las generadas no existen en ningún servidor:
        /// si no las guardamos aquí, al cerrar la app se pierden para siempre.
        case recipes
        /// Recordatorios de cocina programados en el calendario.
        case plans

        var filename: String { "\(rawValue).json" }
    }

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryName: String = "FridgeWise") {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL.temporaryDirectory

        self.directory = base.appendingPathComponent(directoryName, isDirectory: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    private func ensureDirectory() throws {
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // La despensa y las listas no son secretos de estado, pero tampoco
        // tienen por qué salir en un backup de iCloud sin que el usuario lo pida.
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = false
        var mutableURL = directory
        try? mutableURL.setResourceValues(resourceValues)
    }

    func save<T: Encodable>(_ value: T, to bucket: Bucket) throws {
        try ensureDirectory()
        let data = try encoder.encode(value)
        try data.write(to: directory.appendingPathComponent(bucket.filename), options: .atomic)
    }

    func load<T: Decodable>(_ type: T.Type, from bucket: Bucket) -> T? {
        let url = directory.appendingPathComponent(bucket.filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    /// Borrado completo. Requisito de la Guideline 5.1.1(v): si la app permite
    /// crear una cuenta, tiene que permitir borrarla y sus datos desde adentro.
    func deleteEverything() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    /// Exportación para "Descargar mis datos".
    func exportAll() -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return nil }

        var bundle: [String: Any] = [:]
        for url in contents where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            bundle[url.deletingPathExtension().lastPathComponent] = json
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: bundle, options: [.prettyPrinted, .sortedKeys]
        ) else { return nil }

        let exportURL = URL.temporaryDirectory
            .appendingPathComponent("FridgeWise-datos-\(Date().formatted(.iso8601.year().month().day())).json")
        try? data.write(to: exportURL, options: .atomic)
        return exportURL
    }
}
