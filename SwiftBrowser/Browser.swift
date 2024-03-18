//
//  Browser.swift
//  SwiftBrowser
//
//  Created by Ahmad Alhashemi on 17/03/2024.
//

import Foundation
import SwiftUI

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

func load(url: URL) async throws -> [(Int, Int, Character)] {
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

func layout(text: String) -> [(Int, Int, Character)] {
    var displayList: [(Int, Int, Character)] = []
    var cursorX = HSTEP
    var cursorY = VSTEP

    for c in text {
        displayList.append((cursorX, cursorY, c))
        cursorX += HSTEP
        if cursorX >= WIDTH - HSTEP {
            cursorY += VSTEP
            cursorX = HSTEP
        }
    }
    
    return displayList
}

let WIDTH = 800
let HEIGHT = 600

let HSTEP = 13
let VSTEP = 18


class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

struct Browser: NSViewRepresentable {
    var content: [(Int, Int, Character)] = []
    var scroll: Int
    
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