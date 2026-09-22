import Foundation
import Speech
import AVFoundation
import Combine
import HaierACCore

/// 语音控制状态
public enum VoiceControlState: Equatable {
    case idle
    case listening
    case processing
    case success(String)
    case failed(String)
    case permissionDenied(String)
}

/// 语音控制管理单例：负责音频采集、波形电平计算、Speech 转写与静音自提交
@MainActor
public final class VoiceControlManager: ObservableObject {
    public static let shared = VoiceControlManager()

    @Published public private(set) var state: VoiceControlState = .idle
    @Published public private(set) var transcribedText: String = ""
    @Published public private(set) var audioLevel: Float = 0.0 // 0.0 ~ 1.0 用于波形跳动

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 1.2 // 停顿 1.2 秒自动提交
    private var isTapInstalled = false
    private var lastLevelUpdateTime: TimeInterval = 0

    /// 指令执行回调：解析并下发
    public var onCommandRecognized: ((String) -> Void)?

    private init() {
        // 首选简体中文，回退当前系统语言
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
            ?? SFSpeechRecognizer(locale: Locale.current)
    }

    /// 检查并请求麦克风及语音识别权限
    public func requestPermissions() async -> Bool {
        // 1. 语音识别权限
        let speechAuth = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechAuth else {
            state = .permissionDenied("请在「系统设置 - 隐私与安全性 - 语音识别」中允许权限")
            return false
        }

        // 2. 麦克风权限
        let micAuth = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micAuth else {
            state = .permissionDenied("请在「系统设置 - 隐私与安全性 - 麦克风」中允许权限")
            return false
        }

        return true
    }

    /// 开始语音监听
    public func startListening() async {
        stopListening()

        let hasPermission = await requestPermissions()
        guard hasPermission else { return }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            state = .failed("语音识别服务当前不可用")
            return
        }

        do {
            try startAudioEngineAndRecognition(recognizer: recognizer)
            state = .listening
            transcribedText = ""
            audioLevel = 0.0
        } catch {
            state = .failed("无法启动麦克风录音：\(error.localizedDescription)")
            stopListening()
        }
    }

    /// 停止录音并取消
    public func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        audioLevel = 0.0
        if case .listening = state {
            state = .idle
        }
    }

    /// 确认并立即提交当前转写结果
    public func commitCurrentText() {
        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        stopListening()

        guard !text.isEmpty else {
            state = .failed("未听到指令")
            return
        }

        state = .processing
        onCommandRecognized?(text)
    }

    /// 标记执行成功
    public func markSuccess(_ message: String) {
        state = .success(message)
    }

    /// 标记执行失败
    public func markFailed(_ message: String) {
        state = .failed(message)
    }

    /// 重置为初始状态
    public func reset() {
        stopListening()
        state = .idle
        transcribedText = ""
        audioLevel = 0.0
    }

    // MARK: - 内部音频流与识别管理

    private func startAudioEngineAndRecognition(recognizer: SFSpeechRecognizer) throws {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }

        request.shouldReportPartialResults = true
        // 优先在设备端处理（如果设备支持），降低延迟
        if #available(macOS 10.15, *), recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = false // 允许联网提高识别率，同时支持离线
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // 安装音频 Tap，计算实时音量并塞入识别请求（限流 30fps，避免高频 Task 派发卡顿主线程）
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = UInt(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<Int(frameLength) {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            let normalized = min(max(rms * 10.0, 0.0), 1.0)

            let now = ProcessInfo.processInfo.systemUptime
            if now - self.lastLevelUpdateTime >= 0.033 {
                self.lastLevelUpdateTime = now
                Task { @MainActor in
                    self.audioLevel = normalized
                }
            }
        }
        isTapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    let best = result.bestTranscription.formattedString
                    self.transcribedText = best

                    // 重置静音自提交计时器
                    self.resetSilenceTimer()
                }

                if let error {
                    if self.transcribedText.isEmpty && self.state == .listening {
                        AppLog.log("语音识别未获内容或出错: \(error.localizedDescription)")
                        self.state = .failed("未能识别语音，请重试")
                        self.stopListening()
                    } else if !self.transcribedText.isEmpty && self.state == .listening {
                        self.commitCurrentText()
                    }
                } else if result?.isFinal == true {
                    // 如果识别结束且有文字，触发提交
                    if !self.transcribedText.isEmpty && self.state == .listening {
                        self.commitCurrentText()
                    }
                }
            }
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .listening, !self.transcribedText.isEmpty else { return }
                self.commitCurrentText()
            }
        }
    }
}
