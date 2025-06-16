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
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("XScreenRecord")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(isRecording ? "Recording..." : "Ready to Record")
                .foregroundColor(isRecording ? .red : .green)
            
            if isRecording {
                Text(timeString(from: recordingTime))
                    .font(.title)
                    .monospacedDigit()
            }
            
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(isRecording ? Color.red : Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private func startRecording() {
        screenRecorder.startRecording { success in
            if success {
                isRecording = true
                startTimer()
            }
        }
    }
    
    private func stopRecording() {
        screenRecorder.stopRecording()
        isRecording = false
        stopTimer()
    }
    
    private func startTimer() {
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            recordingTime += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
