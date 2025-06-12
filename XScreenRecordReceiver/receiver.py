import asyncio
import websockets
import cv2
import numpy as np
from datetime import datetime
import os


class ScreenRecorder:
    def __init__(self):
        self.output_dir = "recordings"
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)

        # 视频编码器设置
        self.fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        self.fps = 30
        self.video_writer = None
        self.frame_count = 0
        self.recording = False

    def start_recording(self):
        if not self.recording:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = os.path.join(
                self.output_dir, f"screen_recording_{timestamp}.mp4"
            )
            self.video_writer = cv2.VideoWriter(
                output_file, self.fourcc, self.fps, (1920, 1080)
            )
            self.recording = True
            self.frame_count = 0
            print(f"开始录制: {output_file}")

    def stop_recording(self):
        if self.recording:
            self.recording = False
            if self.video_writer:
                self.video_writer.release()
                print(f"录制完成，共 {self.frame_count} 帧")

    def process_frame(self, frame_data):
        if not self.recording:
            self.start_recording()

        try:
            # 将接收到的数据转换为numpy数组
            nparr = np.frombuffer(frame_data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            if frame is not None:
                self.video_writer.write(frame)
                self.frame_count += 1

                # 每100帧打印一次进度
                if self.frame_count % 100 == 0:
                    print(f"已录制 {self.frame_count} 帧")
        except Exception as e:
            print(f"处理帧时出错: {str(e)}")


async def handle_connection(websocket, path, recorder):
    print("新的客户端连接")
    try:
        async for message in websocket:
            if isinstance(message, bytes):
                recorder.process_frame(message)
            else:
                print(f"收到文本消息: {message}")
    except websockets.exceptions.ConnectionClosed:
        print("客户端断开连接")
        recorder.stop_recording()
    except Exception as e:
        print(f"处理连接时出错: {str(e)}")
        recorder.stop_recording()


async def main():
    recorder = ScreenRecorder()
    server = await websockets.serve(
        lambda ws, path: handle_connection(ws, path, recorder),
        "0.0.0.0",  # 监听所有网络接口
        8080,  # 端口号
    )

    print("WebSocket 服务器已启动，监听端口 8080")
    print("等待 iOS 设备连接...")

    try:
        await asyncio.Future()  # 保持服务器运行
    except KeyboardInterrupt:
        print("\n服务器正在关闭...")
        recorder.stop_recording()
        server.close()
        await server.wait_closed()
        print("服务器已关闭")


if __name__ == "__main__":
    asyncio.run(main())
