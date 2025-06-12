import Foundation
import Network

class WebSocketManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var serverAddress: String = ""
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    
    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }
    
    func connect(to address: String) {
        guard let url = URL(string: address) else {
            print("无效的 WebSocket 地址")
            return
        }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    func send(data: Data) {
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("发送数据失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    print("收到数据: \(data.count) 字节")
                case .string(let text):
                    print("收到文本: \(text)")
                @unknown default:
                    break
                }
                self?.receiveMessage()
            case .failure(let error):
                print("接收消息失败: \(error.localizedDescription)")
                self?.isConnected = false
            }
        }
    }
}

extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
} 