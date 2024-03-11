//
//  ContentView.swift
//  RealmEncryptionFailureTest
//
//  Created by Jeremy Penner on 2024-03-11.
//

import SwiftUI

struct ContentView: View {
    var actions: Actions

    var body: some View {
        VStack(spacing: 100) {
            Button("Create test database") {
                try! actions.createTestDatabases()
            }
            .buttonStyle(.bordered)
            Button("Compact test database") {
                try! actions.compactAndWrite()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    ContentView(actions: Actions())
}
