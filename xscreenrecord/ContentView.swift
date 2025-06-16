//
//  ContentView.swift
//  xscreenrecord
//
//  Created by apple on 2025/6/12.
//

import SwiftUI
import ReplayKit

struct ContentView: View {
    @StateObject private var screenRecorder = ScreenRecorder()
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("XScreenRecord")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            StatusView(isRecording: screenRecorder.isRecording)
            
            if screenRecorder.isRecording {
                RecordingTimerView(time: screenRecorder.recordingTime)
            }
            
            RecordButton(isRecording: screenRecorder.isRecording) {
                Task {
                    await handleRecordingAction()
                }
            }
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleRecordingAction() async {
        do {
            if screenRecorder.isRecording {
                try await screenRecorder.stopRecording()
            } else {
                try await screenRecorder.startRecording()
            }
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
}

struct StatusView: View {
    let isRecording: Bool
    
    var body: some View {
        Text(isRecording ? "Recording..." : "Ready to Record")
            .foregroundColor(isRecording ? .red : .green)
            .font(.headline)
    }
}

struct RecordingTimerView: View {
    let time: TimeInterval
    
    var body: some View {
        Text(timeString(from: time))
            .font(.title)
            .monospacedDigit()
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(isRecording ? "Stop Recording" : "Start Recording")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(isRecording ? Color.red : Color.blue)
                .cornerRadius(10)
        }
    }
}

#Preview {
    ContentView()
}
