import Foundation
import AVFoundation

class WebSocketManager {
    private var webSocket: URLSessionWebSocketTask?
    private let serverURL = URL(string: "ws://localhost:8080")!
    
    init() {
        setupWebSocket()
    }
    
    private func setupWebSocket() {
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: serverURL)
        webSocket?.resume()
    }
    
    func sendVideoData(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let imageData = uiImage.jpegData(compressionQuality: 0.5) else { return }
        
        let message = URLSessionWebSocketTask.Message.data(imageData)
        webSocket?.send(message) { error in
            if let error = error {
                print("Failed to send video data: \(error.localizedDescription)")
            }
        }
    }
    
    deinit {
        webSocket?.cancel(with: .normalClosure, reason: nil)
    }
} 