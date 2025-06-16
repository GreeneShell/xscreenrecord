//
//  xscreenrecordApp.swift
//  xscreenrecord
//
//  Created by apple on 2025/6/12.
//

import SwiftUI
import ReplayKit
import AVFoundation

@main
struct XScreenRecordApp: App {
    @StateObject private var permissionManager = PermissionManager()
    
    var body: some Scene {
        WindowGroup {
            if permissionManager.arePermissionsGranted {
                ContentView()
            } else {
                PermissionRequestView(permissionManager: permissionManager)
            }
        }
    }
}

class PermissionManager: ObservableObject {
    @Published private(set) var arePermissionsGranted = false
    @Published private(set) var screenRecordingPermission = false
    @Published private(set) var microphonePermission = false
    
    init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        checkScreenRecordingPermission()
        checkMicrophonePermission()
        
        arePermissionsGranted = screenRecordingPermission && microphonePermission
    }
    
    private func checkScreenRecordingPermission() {
        RPScreenRecorder.shared().isMicrophoneEnabled = false
        screenRecordingPermission = true
    }
    
    private func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphonePermission = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.microphonePermission = granted
                    self.arePermissionsGranted = self.screenRecordingPermission && self.microphonePermission
                }
            }
        default:
            microphonePermission = false
        }
    }
}

struct PermissionRequestView: View {
    @ObservedObject var permissionManager: PermissionManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Permissions Required")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("XScreenRecord needs the following permissions to function:")
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 10) {
                PermissionRow(
                    title: "Screen Recording",
                    isGranted: permissionManager.screenRecordingPermission,
                    systemImage: "record.screen"
                )
                
                PermissionRow(
                    title: "Microphone",
                    isGranted: permissionManager.microphonePermission,
                    systemImage: "mic"
                )
            }
            .padding()
            
            Button("Check Permissions") {
                permissionManager.checkPermissions()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct PermissionRow: View {
    let title: String
    let isGranted: Bool
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(isGranted ? .green : .red)
            
            Text(title)
            
            Spacer()
            
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
        }
    }
}
