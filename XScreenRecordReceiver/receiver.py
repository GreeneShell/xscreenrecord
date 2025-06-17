import asyncio
import websockets
import cv2
import numpy as np
from datetime import datetime
import os
import subprocess
import tempfile


class ScreenRecorder:
    def __init__(self):
        self.output_dir = "recordings"
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)

        self.temp_dir = tempfile.mkdtemp()
        self.frame_count = 0
        self.recording = False
        self.ffmpeg_process = None
        self.temp_frames = []
        self.current_connection = None

    def start_recording(self):
        if not self.recording:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            self.output_file = os.path.join(
                self.output_dir, f"screen_recording_{timestamp}.mp4"
            )
            self.recording = True
            self.frame_count = 0
            self.temp_frames = []
            print(f"开始录制: {self.output_file}")

    def stop_recording(self):
        if self.recording:
            self.recording = False
            if self.ffmpeg_process:
                self.ffmpeg_process.terminate()
                self.ffmpeg_process.wait()
                self.ffmpeg_process = None
            
            if self.temp_frames:
                print(f"正在处理 {len(self.temp_frames)} 帧...")
                self.process_frames()
            print(f"录制完成，共 {self.frame_count} 帧")
            self.temp_frames = []

    def process_frames(self):
        try:
            # 使用FFmpeg将帧转换为视频
            ffmpeg_cmd = [
                'ffmpeg',
                '-y',  # 覆盖已存在的文件
                '-f', 'rawvideo',
                '-vcodec', 'rawvideo',
                '-s', '1080x1920',  # 视频尺寸（竖屏）
                '-pix_fmt', 'bgr24',  # 像素格式
                '-r', '30',  # 帧率
                '-i', '-',  # 从管道读取输入
                '-c:v', 'libx264',  # 使用H.264编码
                '-preset', 'medium',  # 编码速度预设
                '-crf', '23',  # 质量参数（0-51，越小质量越好）
                '-movflags', '+faststart',  # 优化网络播放
                '-vf', 'transpose=2',  # 旋转视频（2表示逆时针旋转90度）
                self.output_file
            ]

            # 启动FFmpeg进程
            process = subprocess.Popen(
                ffmpeg_cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )

            # 写入所有帧
            for frame in self.temp_frames:
                process.stdin.write(frame.tobytes())

            # 关闭输入流并等待处理完成
            process.stdin.close()
            process.wait()

            if process.returncode == 0:
                print(f"视频处理完成: {self.output_file}")
            else:
                print(f"视频处理失败，错误码: {process.returncode}")
                stderr = process.stderr.read().decode()
                print(f"错误信息: {stderr}")

        except Exception as e:
            print(f"处理视频时出错: {str(e)}")
        finally:
            # 清理临时帧
            self.temp_frames = []

    def process_frame(self, frame_data):
        if not self.recording:
            self.start_recording()

        try:
            # 将接收到的数据转换为numpy数组
            nparr = np.frombuffer(frame_data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            if frame is not None:
                # 调整帧大小以确保一致性
                frame = cv2.resize(frame, (1080, 1920))
                # 旋转帧
                frame = cv2.rotate(frame, cv2.ROTATE_90_CLOCKWISE)
                self.temp_frames.append(frame)
                self.frame_count += 1

                # 每100帧打印一次进度
                if self.frame_count % 100 == 0:
                    print(f"已录制 {self.frame_count} 帧")
        except Exception as e:
            print(f"处理帧时出错: {str(e)}")

    def set_connection(self, websocket):
        self.current_connection = websocket

    def clear_connection(self):
        self.current_connection = None


async def handle_connection(websocket, path, recorder):
    print("新的客户端连接")
    recorder.set_connection(websocket)
    try:
        async for message in websocket:
            if isinstance(message, bytes):
                recorder.process_frame(message)
            elif message == "STOP_RECORDING":
                print("收到停止录制信号")
                recorder.stop_recording()
            else:
                print(f"收到文本消息: {message}")
    except websockets.exceptions.ConnectionClosed:
        print("客户端断开连接")
        recorder.stop_recording()
        recorder.clear_connection()
    except Exception as e:
        print(f"处理连接时出错: {str(e)}")
        recorder.stop_recording()
        recorder.clear_connection()


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
