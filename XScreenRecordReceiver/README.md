# XScreenRecord 接收端

这是一个简单的 Python WebSocket 服务器，用于接收 iOS 设备传输的屏幕录制数据并将其保存为视频文件。

## 安装依赖

```bash
pip install -r requirements.txt
```

## 使用方法

1. 运行服务器：
```bash
python receiver.py
```

2. 服务器将在 8080 端口监听连接
3. 录制的视频文件将保存在 `recordings` 目录下
4. 按 Ctrl+C 停止服务器

## 注意事项

- 确保 Mac 和 iOS 设备在同一局域网内
- 检查 Mac 的防火墙设置，确保 8080 端口开放
- 录制的视频文件使用 MP4 格式，分辨率为 1920x1080，帧率为 30fps 