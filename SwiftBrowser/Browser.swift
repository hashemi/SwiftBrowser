//
//  Browser.swift
//  SwiftBrowser
//
//  Created by Ahmad Alhashemi on 17/03/2024.
//

import Foundation
import SwiftUI

typealias LayoutElement = (Double, Double, String, NSFont)

enum Token {
    case text(String)
    case tag(String)
}

func lex(body: String) -> [Token] {
    var out: [Token] = []
    var buffer: [UInt8] = []
    var bufferAsString: String { String(bytes: buffer, encoding: .utf8)! }
    
    var inTag = false

    for c in body.utf8 {
        switch c {
        case UInt8(ascii: "<"):
            inTag = true
            if !buffer.isEmpty {
                out.append(.text(bufferAsString))
                buffer.removeAll()
            }
        case UInt8(ascii: ">"):
            inTag = false
            out.append(.tag(bufferAsString))
            buffer.removeAll()
        default:
            buffer.append(c)
        }
    }
    
    if !inTag && !buffer.isEmpty {
        out.append(.text(bufferAsString))
    }
    
    return out
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
    
    let tokens = lex(body: body)
    return layout(tokens: tokens)
}

extension NSFont {
    func measure(_ string: String) -> CGFloat {
        let attributedString = NSAttributedString(string: string, attributes: [.font: self])
        return attributedString.size().width
    }
    
    var bold: NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: [.boldFontMask])
    }
    var italic: NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: [.italicFontMask])
    }
    var noBold: NSFont {
        NSFontManager.shared.convert(self, toNotHaveTrait: [.boldFontMask])
    }
    var noItalic: NSFont {
        NSFontManager.shared.convert(self, toNotHaveTrait: [.italicFontMask])
    }
}

func layout(tokens: [Token]) -> [LayoutElement] {
    var font = NSFont.systemFont(ofSize: 18)

    var displayList: [LayoutElement] = []
    var cursorX = HSTEP
    var cursorY = VSTEP

    for tok in tokens {
        switch tok {
        case .text(let text):
            for word in text.split(separator: /[\r\t\n ]+/).map(String.init) {
                let w = font.measure(word)
                displayList.append((cursorX, cursorY, word, font))
                cursorX += w + font.measure(" ")

                if cursorX + w > WIDTH - HSTEP {
                    cursorY += (font.ascender + font.descender + font.leading) * 1.25
                    cursorX = HSTEP
                }
            }
        case .tag(let tag):
            print(tag)
            switch tag {
            case "i", "em": font = font.italic
            case "/i", "/em": font = font.noItalic
            case "b", "strong": font = font.bold
            case "/b", "/strong": font = font.noBold
            default: break
            }
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
        
        for (x, y, c, f) in content {
            if y > scroll + HEIGHT { continue }
            if y + VSTEP < scroll { continue }
            
            let textLayer = CATextLayer()
            textLayer.string = "\(c)"
            textLayer.font = f
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
