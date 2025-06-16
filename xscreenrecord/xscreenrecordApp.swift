//
//  xscreenrecordApp.swift
//  xscreenrecord
//
//  Created by apple on 2025/6/12.
//

import SwiftUI
import ReplayKit
import UIKit

@main
struct XScreenRecordApp: App {
    init() {
        requestPermissions()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func requestPermissions() {
        // 请求屏幕录制权限
        RPScreenRecorder.shared().isAvailable { available in
            if available {
                print("屏幕录制功能可用")
            } else {
                print("屏幕录制功能不可用")
            }
        }
    }
}
