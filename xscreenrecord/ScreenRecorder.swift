import Foundation
import ReplayKit
import AVFoundation

class ScreenRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    private let recorder = RPScreenRecorder.shared()
    private var timer: Timer?
    private var startTime: Date?
    private var webSocketManager: WebSocketManager?
    
    override init() {
        super.init()
        recorder.isMicrophoneEnabled = false
        setupWebSocket()
    }
    
    private func setupWebSocket() {
        webSocketManager = WebSocketManager()
    }
    
    func startRecording(completion: @escaping (Bool) -> Void) {
        guard !recorder.isRecording else {
            completion(false)
            return
        }
        
        recorder.startCapture { [weak self] (sampleBuffer, bufferType, error) in
            guard let self = self, error == nil else {
                completion(false)
                return
            }
            
            if bufferType == .video {
                self.webSocketManager?.sendVideoData(sampleBuffer)
            }
        } completionHandler: { error in
            if let error = error {
                print("Failed to start recording: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func stopRecording() {
        guard recorder.isRecording else { return }
        
        recorder.stopCapture { error in
            if let error = error {
                print("Failed to stop recording: \(error.localizedDescription)")
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            self.recordingTime = Date().timeIntervalSince(startTime)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
} 