//
//  CrateApp.swift
//  Crate
//
//  Created by Jude Wilson (Bethel) on 8/2/25.
//

import SwiftUI

@main
struct CrateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        WindowGroup("Terminal", id: "terminal", for: String.self) { $containerID in
            if let id = containerID {
                PopoutTerminalHost(containerID: id)
            }
        }
        .defaultSize(width: 800, height: 500)
    }
}
