//
//  CrateApp.swift
//  Crate
//
//  Created by Jude Wilson (Bethel) on 8/2/25.
//

import SwiftUI

@main
struct CrateApp: App {
    @State private var manager = CrateManager()

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager)
        }

        WindowGroup("Terminal", id: "terminal", for: String.self) { $containerID in
            if let id = containerID {
                PopoutTerminalHost(containerID: id)
            }
        }
        .defaultSize(width: 800, height: 500)

        MenuBarExtra {
            MenuBarView(manager: manager)
        } label: {
            Image(systemName: "shippingbox.fill")
        }
        .menuBarExtraStyle(.menu)
    }
}
