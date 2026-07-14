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
        let base = (try? fm.url(for: .applicationSupportDirectory,
                               in: .userDomainMask,
                               appropriateFor: nil,
                               create: true))
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let appURL = base.appendingPathComponent("BarPOSv2", isDirectory: true)
        if fm.fileExists(atPath: appURL.path) == false {
            try? fm.createDirectory(at: appURL, withIntermediateDirectories: true)
        }
        return appURL
    }()

    static func fileURL(_ name: String) -> URL {
        dirURL.appendingPathComponent(name)
    }

    static func saveJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = []
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

    static func appendJSONL<T: Encodable>(_ value: T, to url: URL) throws {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        var data = try enc.encode(value)
        data.append(0x0A)  // newline
        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url, options: .atomic)
        }
    }

    static func loadJSONL<T: Decodable>(from url: URL, as type: T.Type) -> [T] {
        guard let raw = try? Data(contentsOf: url) else { return [] }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return raw.split(separator: 0x0A).compactMap {
            try? dec.decode(T.self, from: Data($0))
        }
    }
}
