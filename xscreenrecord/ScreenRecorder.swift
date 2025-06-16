import Foundation
import ReplayKit
import AVFoundation
import Combine

enum RecordingError: Error {
    case alreadyRecording
    case notRecording
    case captureError(Error)
    case setupError(Error)
}

class ScreenRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var recordingTime: TimeInterval = 0
    @Published private(set) var error: RecordingError?
    
    private let recorder = RPScreenRecorder.shared()
    private var webSocketManager: WebSocketManager?
    private var timer: Timer?
    private var startTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupRecorder()
        setupWebSocket()
    }
    
    private func setupRecorder() {
        recorder.isMicrophoneEnabled = false
    }
    
    private func setupWebSocket() {
        webSocketManager = WebSocketManager()
    }
    
    func startRecording() async throws {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            recorder.startCapture { [weak self] (sampleBuffer, bufferType, error) in
                if let error = error {
                    continuation.resume(throwing: RecordingError.captureError(error))
                    return
                }
                
                guard let self = self else { return }
                
                if bufferType == .video {
                    self.webSocketManager?.sendVideoData(sampleBuffer)
                }
            } completionHandler: { error in
                if let error = error {
                    continuation.resume(throwing: RecordingError.setupError(error))
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.isRecording = true
                        self?.startTime = Date()
                        self?.startTimer()
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    func stopRecording() async throws {
        guard isRecording else {
            throw RecordingError.notRecording
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            recorder.stopCapture { error in
                if let error = error {
                    continuation.resume(throwing: RecordingError.captureError(error))
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.isRecording = false
                        self?.stopTimer()
                        self?.recordingTime = 0
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            self.recordingTime = Date().timeIntervalSince(startTime)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        startTime = nil
    }
    
    deinit {
        stopTimer()
    }
} 