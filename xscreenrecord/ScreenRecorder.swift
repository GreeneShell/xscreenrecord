import Foundation
import ReplayKit
import AVFoundation

class ScreenRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    private let recorder = RPScreenRecorder.shared()
    private var timer: Timer?
    private var startTime: Date?
    
    override init() {
        super.init()
        recorder.isMicrophoneEnabled = false
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        recorder.startRecording { [weak self] error in
            if let error = error {
                print("录制开始失败: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                self?.isRecording = true
                self?.startTime = Date()
                self?.startTimer()
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        recorder.stopRecording { [weak self] error in
            if let error = error {
                print("录制停止失败: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                self?.isRecording = false
                self?.stopTimer()
                self?.recordingTime = 0
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