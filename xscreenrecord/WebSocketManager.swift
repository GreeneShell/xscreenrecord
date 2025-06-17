import Foundation
import AVFoundation
import Combine
import UIKit
import CoreImage
import Network

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
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectDelay: TimeInterval = 1.0
    private var isReconnecting = false
    private var networkMonitor: NWPathMonitor?
    
    init(serverURL: URL = URL(string: "ws://192.168.31.90:8080")!) {
        self.serverURL = serverURL
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        setupNetworkMonitoring()
        setupWebSocket()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                self?.reconnectIfNeeded()
            }
        }
        networkMonitor?.start(queue: DispatchQueue.global())
    }
    
    private func setupWebSocket() {
        webSocket = session.webSocketTask(with: serverURL)
        webSocket?.resume()
        isConnected = true
        reconnectAttempts = 0
        reconnectDelay = 1.0
        startPing()
        receiveMessage()
    }
    
    private func startPing() {
        webSocket?.sendPing { [weak self] error in
            if let error = error {
                self?.handleError(.connectionFailed(error))
            } else {
                DispatchQueue.global().asyncAfter(deadline: .now() + 30) { [weak self] in
                    self?.startPing()
                }
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
        guard isConnected else {
            reconnectIfNeeded()
            return
        }
        
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
    
    func sendStopRecording() {
        guard isConnected else { return }
        
        let stopMessage = URLSessionWebSocketTask.Message.string("STOP_RECORDING")
        webSocket?.send(stopMessage) { [weak self] error in
            if let error = error {
                self?.handleError(.sendFailed(error))
            }
        }
    }
    
    private func handleError(_ error: WebSocketError) {
        DispatchQueue.main.async { [weak self] in
            self?.error = error
            self?.isConnected = false
            self?.reconnectIfNeeded()
        }
    }
    
    private func reconnectIfNeeded() {
        guard !isReconnecting else { return }
        
        isReconnecting = true
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        
        if reconnectAttempts < maxReconnectAttempts {
            reconnectTimer?.invalidate()
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectDelay, repeats: false) { [weak self] _ in
                self?.setupWebSocket()
                self?.isReconnecting = false
            }
            reconnectAttempts += 1
            reconnectDelay *= 2 // 指数退避
        } else {
            print("达到最大重连次数")
            isReconnecting = false
        }
    }
    
    deinit {
        reconnectTimer?.invalidate()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        networkMonitor?.cancel()
    }
} 