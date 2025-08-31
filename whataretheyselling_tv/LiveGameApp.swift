//
//  LiveGameApp.swift
//  whataretheyselling_tv
//
//  Created by TeJay Guilliams on 8/30/25.
//


// LiveGameApp.swift
import SwiftUI

@main
struct LiveGameApp: App {
    var body: some Scene {
        WindowGroup {
            LiveGameScreen(
                streamURL: URL(string: "https://fl3.moveonjoy.com/QVC/index.m3u8")!
            )
        }
    }
}
