//
//  Browser.swift
//  SwiftBrowser
//
//  Created by Ahmad Alhashemi on 17/03/2024.
//

import Foundation
import SwiftUI

typealias LayoutElement = (Double, Double, String)

func lex(body: String) -> String {
    var text: [UInt8] = []
    var inTag = false
    for c in body.utf8 {
        switch c {
        case UInt8(ascii: "<"):
            inTag = true
        case UInt8(ascii: ">"):
            inTag = false
        case _ where !inTag:
            text.append(c)
        default:
            break
        }
    }
    return String(bytes: text, encoding: .utf8)!
}

func load(url: URL) async throws -> [LayoutElement] {
    let (data, response) = try await URLSession.shared.data(from: url)

    guard
        let body = String(data: data, encoding: .utf8),
        let response = response as? HTTPURLResponse,
        response.statusCode == 200
    else {
        return []
    }
    
    let text = lex(body: body)
    return layout(text: text)
}

extension NSFont {
    func measure(_ string: String) -> CGFloat {
        let attributedString = NSAttributedString(string: string, attributes: [.font: self])
        return attributedString.size().width
    }
}

func layout(text: String) -> [LayoutElement] {
    let font = NSFont.systemFont(ofSize: 18)

    var displayList: [LayoutElement] = []
    var cursorX = HSTEP
    var cursorY = VSTEP

    for word in text.split(separator: /[\r\t\n ]+/).map(String.init) {
        let w = font.measure(word)
        displayList.append((cursorX, cursorY, word))
        cursorX += w + font.measure(" ")

        if cursorX + w > WIDTH - HSTEP {
            cursorY += (font.ascender + font.descender + font.leading) * 1.25
            cursorX = HSTEP
        }
    }

    return displayList
}

let WIDTH = 800.0
let HEIGHT = 600.0

let HSTEP = 13.0
let VSTEP = 18.0


class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

struct Browser: NSViewRepresentable {
    var content: [LayoutElement] = []
    var scroll: Double
    
    func makeNSView(context: Context) -> some NSView {
        let view = FlippedView(frame: CGRect(x: 0, y: 0, width: WIDTH, height: HEIGHT))
        
        let parentLayer = CALayer()
        parentLayer.frame = view.bounds
        view.layer = parentLayer
        
        return view
    }
    
    func updateNSView(_ view: NSViewType, context: Context) {
        let parentLayer = view.layer!
        parentLayer.sublayers = []
        
        for (x, y, c) in content {
            if y > scroll + HEIGHT { continue }
            if y + VSTEP < scroll { continue }
            
            let textLayer = CATextLayer()
            textLayer.string = "\(c)"
            textLayer.font = NSFont.systemFont(ofSize: 18)
            textLayer.fontSize = 18
            textLayer.foregroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
            textLayer.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            textLayer.position = CGPoint(x: x, y: y - scroll)
            textLayer.anchorPoint = CGPoint(x: 0, y: 0)
            textLayer.alignmentMode = .left
            parentLayer.addSublayer(textLayer)
        }
    }
}
