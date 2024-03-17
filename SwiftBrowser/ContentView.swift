//
//  ContentView.swift
//  SwiftBrowser
//
//  Created by Ahmad Alhashemi on 17/03/2024.
//

import SwiftUI

struct ContentView: View {
    @State var addressBar: String = ""
    @State var currentTask: Task<(), Never>? = nil
    
    var body: some View {
        VStack {
            TextField("Address", text: $addressBar)
                .onSubmit {
                    guard let url = URL(string: addressBar) else { return }

                    currentTask?.cancel()
                    self.currentTask = Task {
                        try! await load(url: url)
                    }
                }
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
