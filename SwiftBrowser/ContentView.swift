//
//  ContentView.swift
//  SwiftBrowser
//
//  Created by Ahmad Alhashemi on 17/03/2024.
//

import SwiftUI

let SCROLL_STEP = 100.0

struct ContentView: View {
    @State var addressBar: String = ""
    @State var currentTask: Task<(), Never>? = nil
    @State var content: [LayoutElement] = []
    @State var scroll = 0.0
    
    var body: some View {
        VStack {
            TextField("Address", text: $addressBar)
                .onSubmit {
                    guard let url = URL(string: addressBar) else {
                        print("Failed to convert URL")
                        return
                    }

                    currentTask?.cancel()
                    self.currentTask = Task {
                        guard let content = try? await load(url: url) else {
                            print("Failed to load content")
                            return
                        }
                        await MainActor.run {
                            self.content = content
                        }
                    }
                }
            Browser(content: content, scroll: scroll)
            Spacer()
        }
        .padding()
        .onKeyPress(.downArrow) {
            scroll += SCROLL_STEP
            return .handled
        }
    }
}

#Preview {
    ContentView()
}
