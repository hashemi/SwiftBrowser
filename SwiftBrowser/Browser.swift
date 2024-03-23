//
//  Browser.swift
//  SwiftBrowser
//
//  Created by Ahmad Alhashemi on 17/03/2024.
//

import Foundation
import SwiftUI

typealias LayoutElement = (Double, Double, String, NSFont)

func load(url: URL) async throws -> [LayoutElement] {
    let (data, response) = try await URLSession.shared.data(from: url)

    guard
        let body = String(data: data, encoding: .utf8),
        let response = response as? HTTPURLResponse,
        response.statusCode == 200
    else {
        return []
    }
    
    let node = HTMLParser(body: body).parse()
    return Layout(tree: node).displayList
}

extension NSFont {
    func measure(_ string: String) -> CGFloat {
        let attributedString = NSAttributedString(string: string, attributes: [.font: self])
        return attributedString.size().width
    }
}

func printTree(node: any Node, indent: Int = 0) {
    print(String(repeating: " ", count: indent), node)
    for child in node.children {
        printTree(node: child, indent: indent + 2)
    }
}

protocol Node: CustomStringConvertible {
    var parent: (any Node)? { get }
    var children: [any Node] { get }
}

class Text: Node {
    let text: String
    let parent: (any Node)?
    let children: [any Node] = []
    
    init(text: String, parent: any Node) {
        self.text = text
        self.parent = parent
    }
    
    var description: String { text.debugDescription }
}

class Element: Node {
    let tag: String
    let attributes: [String: String]
    let parent: (any Node)?
    var children: [any Node]
    
    init(tag: String, attributes: [String: String], parent: (any Node)?) {
        self.tag = tag
        self.attributes = attributes
        self.parent = parent
        self.children = []
    }
    
    var description: String { "<\(tag)>" }
}

extension UInt8 {
    var isWhitespace: Bool {
        Set([0x20, 0x09, 0x0A, 0x0D, 0x0C, 0x0B]).contains(self)
    }
}

extension Array where Element == UInt8 {
    func lowercased() -> [UInt8] {
        self.map {
            if $0 >= 65 && $0 <= 90 {
                return $0 + 32
            } else {
                return $0
            }
        }
    }
}

let SELF_CLOSING_TAGS = Set([
    "area", "base", "br", "col", "embed", "hr", "img", "input",
    "link", "meta", "param", "source", "track", "wbr",
])

let HEAD_TAGS = Set([
    "base", "basefont", "bgsound", "noscript",
    "link", "meta", "title", "style", "script",
])

class HTMLParser {
    let body: String
    var unfinished: [Element] = []
    
    init(body: String) {
        self.body = body
    }
    
    func getAttributes(_ text: [UInt8]) -> ([UInt8], [[UInt8]: [UInt8]]) {
        let parts = text.split(whereSeparator: \.isWhitespace)
        let tag = Array(parts[0]).lowercased()
        var attributes: [[UInt8]: [UInt8]] = [:]
        
        for attrpair in parts[1...] {
            let parts = attrpair.split(separator: UInt8(ascii: "="), maxSplits: 1)
            if parts.count > 1 {
                let key = parts[0]
                var value = parts[1]
                if value.count > 2 && [UInt8(ascii: "\""), UInt8(ascii: "'")].contains(value.first) {
                    value = value.dropFirst().dropFirst()
                }
                attributes[Array(key).lowercased()] = Array(value).lowercased()
            } else {
                attributes[Array(attrpair).lowercased()] = []
            }
        }
        return (tag, attributes)
    }
    
    func parse() -> Element {
        var text: [UInt8] = []
        var inTag = false
        for c in body.utf8 {
            switch c {
            case UInt8(ascii: "<"):
                inTag = true
                if !text.isEmpty {
                    addText(text)
                }
                text.removeAll()
            case UInt8(ascii: ">"):
                inTag = false
                addTag(text)
                text.removeAll()
            default:
                text.append(c)
            }
        }
        if !inTag && !text.isEmpty {
            addText(text)
        }
        return finish()
    }
    
    func addText(_ text: [UInt8]) {
        if text.allSatisfy(\.isWhitespace) { return }
        implicitTags("")
        
        let parent = unfinished.last!
        let node = Text(text: String(bytes: text, encoding: .utf8)!, parent: parent)
        parent.children.append(node)
    }
    
    func addTag(_ text: [UInt8]) {
        let (tag, attributes) = getAttributes(text)
        if tag.first == UInt8(ascii: "!") { return }
        implicitTags(String(bytes: tag, encoding: .utf8)!)
        if tag.first == UInt8(ascii: "/") {
            if unfinished.count == 1 { return }
            let node = unfinished.popLast()!
            let parent = unfinished.last!
            parent.children.append(node)
        } else if SELF_CLOSING_TAGS.contains(String(bytes: tag, encoding: .utf8)!) {
            let parent = unfinished.last!
            let node = Element(
                tag: String(bytes: tag, encoding: .utf8)!,
                attributes: Dictionary(uniqueKeysWithValues: attributes.map({ (String(bytes: $0.key, encoding: .utf8)!, String(bytes: $0.value, encoding: .utf8)!) })),
                parent: parent
            )
            parent.children.append(node)
        } else {
            let parent = unfinished.last
            let node = Element(
                tag: String(bytes: tag, encoding: .utf8)!,
                attributes: Dictionary(uniqueKeysWithValues: attributes.map({ (String(bytes: $0.key, encoding: .utf8)!, String(bytes: $0.value, encoding: .utf8)!) })),
                parent: parent
            )
            unfinished.append(node)
        }
    }
    
    func finish() -> Element {
        if unfinished.isEmpty {
            implicitTags("")
        }
        while unfinished.count > 1 {
            let node = unfinished.popLast()!
            let parent = unfinished.last!
            parent.children.append(node)
        }
        return unfinished.popLast()!
    }
    
    func implicitTags(_ tag: String) {
        while true {
            let openTags = unfinished.map(\.tag)
            if openTags.isEmpty && tag != "html" {
                addTag(Array("html".utf8))
            } else if openTags == ["html"] && !["head", "body", "/html"].contains(tag) {
                if HEAD_TAGS.contains(tag) {
                    addTag(Array("head".utf8))
                } else {
                    addTag(Array("body".utf8))
                }
            } else if openTags == ["html", "head"] && !(HEAD_TAGS + ["/head"]).contains(tag) {
                addTag(Array("/head".utf8))
            } else {
                break
            }
        }
    }
}

struct Layout {
    enum Weight { case regular, bold }
    enum Style { case roman, italic }

    var displayList: [LayoutElement] = []
    var line: [(Double, String, NSFont)] = []

    var cursorX = HSTEP
    var cursorY = VSTEP
    var weight = Weight.regular
    var style = Style.roman
    var size = 16.0
    
    var font: NSFont {
        let font = NSFont.systemFont(ofSize: size)
        var traits: NSFontTraitMask = []
        if weight == .bold { traits.insert(.boldFontMask) }
        if style == .italic { traits.insert(.italicFontMask) }
        if traits.isEmpty {
            return font
        } else {
            return NSFontManager.shared.convert(font, toHaveTrait: traits)
        }
    }
    
    init(tree: Node) {
        recurse(tree)
        flush()
    }
    
    private mutating func word(_ word: String) {
        let w = font.measure(word)
        line.append((cursorX, word, font))
        cursorX += w + font.measure(" ")

        if cursorX + w > WIDTH - HSTEP {
            flush()
        }
    }
    
    private mutating func openTag(_ tag: String) {
        switch tag {
        case "i", "em": style = .italic
        case "b", "strong": weight = .bold
        case "small": size -= 2
        case "big": size += 4
        case "br": flush()
        default: break
        }
    }
    
    private mutating func closeTag(_ tag: String) {
        switch tag {
        case "i", "em": style = .roman
        case "b", "strong": weight = .regular
        case "small": size += 2
        case "big": size -= 4
        case "p":
            flush()
            cursorY += VSTEP
        default: break
        }
    }
    
    private mutating func flush() {
        guard !line.isEmpty else { return }
        let maxAscent = line.map(\.2).map(\.ascender).max()!
        let baseline = cursorY + 1.25 * maxAscent
        for (x, word, font) in line {
            let y = baseline - font.ascender
            displayList.append((x, y, word, font))
        }

        let maxDescent = line.map(\.2).map(\.descender).max()!
        cursorY = baseline + 1.25 * maxDescent
        cursorX = HSTEP
        line.removeAll()
    }
    
    private mutating func recurse(_ tree: Node) {
        switch tree {
        case let text as Text:
            for word in text.text.split(separator: /[\r\t\n ]+/).map(String.init) {
                self.word(word)
            }
        case let element as Element:
            openTag(element.tag)
            for child in tree.children {
                recurse(child)
            }
            closeTag(element.tag)
        default:
            fatalError("Unrecognized node type")
        }
    }
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
            textLayer.fontSize = f.pointSize
            textLayer.foregroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
            textLayer.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            textLayer.position = CGPoint(x: x, y: y - scroll)
            textLayer.anchorPoint = CGPoint(x: 0, y: 0)
            textLayer.alignmentMode = .left
            parentLayer.addSublayer(textLayer)
        }
    }
}
