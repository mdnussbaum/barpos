//
//  Persistence.swift
//  BarPOSv2
//
//  Created by Michael Nussbaum on 9/24/25.
//


import Foundation

enum Persistence {
    private static var dirURL: URL = {
        let fm = FileManager.default
        let url = try! fm.url(for: .applicationSupportDirectory,
                              in: .userDomainMask,
                              appropriateFor: nil,
                              create: true)
        let appURL = url.appendingPathComponent("BarPOSv2", isDirectory: true)
        if !fm.fileExists(atPath: appURL.path) {
            try? fm.createDirectory(at: appURL, withIntermediateDirectories: true)
        }
        return appURL
    }()

    static func fileURL(_ name: String) -> URL {
        dirURL.appendingPathComponent(name)
    }

    static func saveJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(value)
        try data.write(to: url, options: .atomic)
    }

    static func loadJSON<T: Decodable>(from url: URL, as type: T.Type) throws -> T {
        let data = try Data(contentsOf: url)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(T.self, from: data)
    }
}