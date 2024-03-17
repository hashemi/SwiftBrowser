//
//  Browser.swift
//  SwiftBrowser
//
//  Created by Ahmad Alhashemi on 17/03/2024.
//

import Foundation

func show(body: String) {
    var inTag = false
    for c in body.utf8 {
        switch c {
        case UInt8(ascii: "<"):
            inTag = true
        case UInt8(ascii: ">"):
            inTag = false
        case _ where !inTag:
            print(UnicodeScalar(c), terminator: "")
        default:
            break
        }
    }
}

func load(url: URL) async throws {
    let (data, response) = try await URLSession.shared.data(from: url)

    guard
        let body = String(data: data, encoding: .utf8),
        let response = response as? HTTPURLResponse,
        response.statusCode == 200
    else {
        return
    }

    show(body: body)
}
