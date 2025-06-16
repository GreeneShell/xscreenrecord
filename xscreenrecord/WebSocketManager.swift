import Foundation
import AVFoundation
import Combine
import UIKit
import CoreImage

enum WebSocketError: Error {
    case invalidURL
    case connectionFailed(Error)
    case sendFailed(Error)
    case disconnected
}

class WebSocketManager: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var error: WebSocketError?
    
    private var webSocket: URLSessionWebSocketTask?
    private let session: URLSession
    private var serverURL: URL
    private var reconnectTimer: Timer?
    private var messageQueue = DispatchQueue(label: "com.xscreenrecord.websocket")
    
    init(serverURL: URL = URL(string: "ws://localhost:8080")!) {
        self.serverURL = serverURL
        self.session = URLSession(configuration: .default)
        setupWebSocket()
    }
    
    private func setupWebSocket() {
        webSocket = session.webSocketTask(with: serverURL)
        webSocket?.resume()
        isConnected = true
        startPing()
        receiveMessage()
    }
    
    private func startPing() {
        webSocket?.sendPing { [weak self] error in
            if let error = error {
                self?.handleError(.connectionFailed(error))
            }
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.receiveMessage()
            case .failure(let error):
                self.handleError(.connectionFailed(error))
            }
        }
    }
    
    func sendVideoData(_ sampleBuffer: CMSampleBuffer) {
        guard isConnected else { return }
        
        messageQueue.async { [weak self] in
            guard let self = self,
                  let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            let uiImage = UIImage(cgImage: cgImage)
            guard let imageData = uiImage.jpegData(compressionQuality: 0.5) else { return }
            
            let message = URLSessionWebSocketTask.Message.data(imageData)
            self.webSocket?.send(message) { error in
                if let error = error {
                    self.handleError(.sendFailed(error))
                }
            }
        }
    }
    
    private func handleError(_ error: WebSocketError) {
        DispatchQueue.main.async { [weak self] in
            self?.error = error
            self?.isConnected = false
            self?.reconnect()
        }
    }
    
    private func reconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.setupWebSocket()
        }
    }
    
    deinit {
        reconnectTimer?.invalidate()
        webSocket?.cancel(with: .normalClosure, reason: nil)
    }
} 