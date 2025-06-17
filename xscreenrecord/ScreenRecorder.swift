import Foundation
import ReplayKit
import AVFoundation
import Combine
import UIKit

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
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    override init() {
        super.init()
        setupRecorder()
        setupWebSocket()
        setupNotifications()
    }
    
    private func setupRecorder() {
        recorder.isMicrophoneEnabled = false
        recorder.isCameraEnabled = false
        
        // 配置录制选项
        if #available(iOS 15.0, *) {
            recorder.captureHandler = { [weak self] (sampleBuffer, bufferType, error) in
                if let error = error {
                    print("录制错误: \(error.localizedDescription)")
                    return
                }
                
                guard let self = self else { return }
                
                if bufferType == .video {
                    self.webSocketManager?.sendVideoData(sampleBuffer)
                }
            }
        }
    }
    
    private func setupWebSocket() {
        webSocketManager = WebSocketManager()
        webSocketManager?.$isConnected
            .sink { [weak self] isConnected in
                if !isConnected && self?.isRecording == true {
                    self?.handleWebSocketDisconnection()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidEnterBackground() {
        if isRecording {
            startBackgroundTask()
        }
    }
    
    @objc private func handleAppWillEnterForeground() {
        if backgroundTask != .invalid {
            endBackgroundTask()
        }
    }
    
    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func handleWebSocketDisconnection() {
        // 如果WebSocket断开，尝试重新连接
        webSocketManager = WebSocketManager()
    }
    
    func startRecording() async throws {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            if #available(iOS 15.0, *) {
                recorder.startCapture { error in
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
            } else {
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
                        self?.webSocketManager?.sendStopRecording()
                        self?.isRecording = false
                        self?.stopTimer()
                        self?.recordingTime = 0
                        self?.endBackgroundTask()
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
        endBackgroundTask()
        NotificationCenter.default.removeObserver(self)
    }
} 