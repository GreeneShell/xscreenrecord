//
//  ContentView.swift
//  xscreenrecord
//
//  Created by apple on 2025/6/12.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var screenRecorder = ScreenRecorder()
    @StateObject private var webSocketManager = WebSocketManager()
    @State private var serverAddress = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("XScreenRecord")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack {
                TextField("WebSocket 服务器地址", text: $serverAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                
                Button(action: {
                    if webSocketManager.isConnected {
                        webSocketManager.disconnect()
                    } else {
                        webSocketManager.connect(to: serverAddress)
                    }
                }) {
                    Text(webSocketManager.isConnected ? "断开连接" : "连接")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(webSocketManager.isConnected ? Color.red : Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            Text(webSocketManager.isConnected ? "已连接到服务器" : "未连接到服务器")
                .foregroundColor(webSocketManager.isConnected ? .green : .red)
            
            if screenRecorder.isRecording {
                Text(String(format: "录制时长: %.0f 秒", screenRecorder.recordingTime))
                    .font(.headline)
            }
            
            Button(action: {
                if screenRecorder.isRecording {
                    screenRecorder.stopRecording()
                } else {
                    screenRecorder.startRecording()
                }
            }) {
                Text(screenRecorder.isRecording ? "停止录制" : "开始录制")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50)
                    .background(screenRecorder.isRecording ? Color.red : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(!webSocketManager.isConnected)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
