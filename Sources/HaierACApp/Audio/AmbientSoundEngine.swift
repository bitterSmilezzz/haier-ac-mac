import Foundation
import AVFoundation
import HaierACCore
import os

/// 助眠自然白噪音与晨间音律类型
public enum AmbientSoundType: String, CaseIterable, Identifiable, Codable {
    case springRain = "春夜细雨"
    case oceanWaves = "海风浪涌"
    case forestBreeze = "森林微风"
    case summerNight = "夏夜静谧"
    case morningBirds = "清晨林鸟"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    public var icon: String {
        switch self {
        case .springRain: return "cloud.rain.fill"
        case .oceanWaves: return "water.waves"
        case .forestBreeze: return "wind"
        case .summerNight: return "moon.stars.fill"
        case .morningBirds: return "bird.fill"
        }
    }

    public var subtitle: String {
        switch self {
        case .springRain: return "舒缓粉噪与细雨滴答，助眠宁神"
        case .oceanWaves: return "低频浪潮缓缓起伏，沉浸深邃"
        case .forestBreeze: return "自然微风掠过树梢，呼吸清新"
        case .summerNight: return "夜空底噪与稀疏虫鸣，安睡整夜"
        case .morningBirds: return "清晨林间轻盈啼鸣，柔和唤醒"
        }
    }
}

/// 实时音频渲染线程安全参数容器（采用 os_unfair_lock 纳秒级轻量锁保护原子快照，消除主线程写入与音频回调读取的 TSAN 数据竞争）
private final class AudioRenderParameters: @unchecked Sendable {
    private var lock = os_unfair_lock_s()
    private var _gain: Float = 0.0
    private var _type: AmbientSoundType = .springRain

    func setGain(_ gain: Float) {
        os_unfair_lock_lock(&lock)
        _gain = gain
        os_unfair_lock_unlock(&lock)
    }

    func setType(_ type: AmbientSoundType) {
        os_unfair_lock_lock(&lock)
        _type = type
        os_unfair_lock_unlock(&lock)
    }

    func snapshot() -> (gain: Float, type: AmbientSoundType) {
        os_unfair_lock_lock(&lock)
        let g = _gain
        let t = _type
        os_unfair_lock_unlock(&lock)
        return (g, t)
    }
}

/// 纯算法程序化自然助眠音引擎（零外部音频资产依赖，极度轻量低功耗）
/// 基于 AVAudioEngine 与 AVAudioSourceNode 实时合成春雨、浪涌、微风、夜虫与晨鸟
@MainActor
public final class AmbientSoundEngine: ObservableObject {
    public static let shared = AmbientSoundEngine()

    @Published public private(set) var isPlaying: Bool = false
    @Published public var currentType: AmbientSoundType = .springRain {
        didSet {
            renderParams.setType(currentType)
        }
    }
    @Published public var volume: Float = 0.5 {
        didSet {
            let clamped = min(max(volume, 0.0), 1.0)
            targetVolume = clamped
            if isPlaying, let engine = engine, engine.isRunning {
                smoothGainTransition(to: clamped, duration: 0.2)
            }
        }
    }

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    // 内部实时合成参数与线程安全同步器 (TSAN 加固)
    private let renderParams = AudioRenderParameters()
    private var sampleRate: Double = 44100.0
    private var targetVolume: Float = 0.5
    private var activeGain: Float = 0.0 {
        didSet {
            renderParams.setGain(activeGain)
        }
    }

    // 合成器状态
    private struct SynthesisState {
        // 独立左右声道粉红噪声双极点滤波器状态 (Decorrelated Stereo Pink Noise)
        var b0L: Float = 0.0, b1L: Float = 0.0, b2L: Float = 0.0, b3L: Float = 0.0, b4L: Float = 0.0, b5L: Float = 0.0, b6L: Float = 0.0
        var b0R: Float = 0.0, b1R: Float = 0.0, b2R: Float = 0.0, b3R: Float = 0.0, b4R: Float = 0.0, b5R: Float = 0.0, b6R: Float = 0.0
        var brownL: Float = 0.0, brownR: Float = 0.0

        var phase: Double = 0.0
        var wavePhase: Double = 0.0
        var chirpTimer: Double = 0.0
        var birdTimer: Double = 0.0
        var birdPitch: Double = 3000.0
    }

    private var synthState = SynthesisState()
    private var fadeTimer: Task<Void, Never>?
    private var fadeGeneration: Int = 0

    private init() {
        renderParams.setGain(0.0)
        renderParams.setType(.springRain)
    }

    /// 平滑过渡 activeGain 至目标增益，杜绝音量骤变/拖拽导致的爆音与破音
    private func smoothGainTransition(to target: Float, duration: TimeInterval = 0.25) {
        fadeGeneration &+= 1
        let currentGen = fadeGeneration
        fadeTimer?.cancel()

        let startGain = activeGain
        let diff = target - startGain
        if abs(diff) < 0.005 || duration <= 0.02 {
            activeGain = target
            return
        }

        let steps = 20
        let stepTime = max(0.01, duration / Double(steps))
        let gainStep = diff / Float(steps)

        fadeTimer = Task { @MainActor in
            for _ in 0..<steps {
                try? await Task.sleep(nanoseconds: UInt64(stepTime * 1_000_000_000))
                guard !Task.isCancelled, self.fadeGeneration == currentGen else { return }
                self.activeGain += gainStep
            }
            guard !Task.isCancelled, self.fadeGeneration == currentGen else { return }
            self.activeGain = target
        }
    }

    /// 播放指定环境音（支持平滑淡入与平滑声型切换）
    public func play(type: AmbientSoundType? = nil, fadeInDuration: TimeInterval = 2.0) {
        if let type = type {
            self.currentType = type
        }
        setupEngineIfNeeded()

        guard let engine = engine else { return }

        targetVolume = min(max(volume, 0.0), 1.0)
        isPlaying = true

        if engine.isRunning {
            // 如果已在运行，平滑过渡音量至目标值（双向渐变，防范调小音量时的爆音）
            smoothGainTransition(to: targetVolume, duration: min(1.0, fadeInDuration))
            AppLog.log("助眠音频引擎: 切换音律为「\(currentType.rawValue)」")
            return
        }

        do {
            try engine.start()
            activeGain = 0.0
            smoothGainTransition(to: targetVolume, duration: fadeInDuration)
            AppLog.log("助眠音频引擎: 启动播放「\(currentType.rawValue)」")
        } catch {
            AppLog.log("⚠️ 助眠音频引擎启动失败: \(error.localizedDescription)")
            isPlaying = false
        }
    }

    /// 停止播放（支持平滑淡出）
    public func stop(fadeOutDuration: TimeInterval = 1.5) {
        guard isPlaying || (engine?.isRunning == true) else { return }

        // 立即置 false，保证 UI 语义与按钮响应即时一致
        isPlaying = false

        fadeGeneration &+= 1
        let currentGen = fadeGeneration
        fadeTimer?.cancel()

        if fadeOutDuration <= 0.1 {
            self.activeGain = 0.0
            self.engine?.stop()
            return
        }

        fadeTimer = Task { @MainActor in
            let steps = 30
            let stepTime = max(0.01, fadeOutDuration / Double(steps))
            let current = self.activeGain
            let gainStep = current / Float(steps)

            for _ in 0..<steps {
                try? await Task.sleep(nanoseconds: UInt64(stepTime * 1_000_000_000))
                guard !Task.isCancelled, self.fadeGeneration == currentGen else { return }
                self.activeGain = max(0.0, self.activeGain - gainStep)
            }
            guard !Task.isCancelled, self.fadeGeneration == currentGen else { return }
            self.activeGain = 0.0
            self.engine?.stop()
            AppLog.log("助眠音频引擎: 已平滑淡出停止")
        }
    }

    /// 切换播放/暂停
    public func toggle() {
        if isPlaying {
            stop(fadeOutDuration: 1.0)
        } else {
            play(fadeInDuration: 1.5)
        }
    }

    // MARK: - 音频引擎配置

    private func setupEngineIfNeeded() {
        guard engine == nil else { return }

        let eng = AVAudioEngine()
        let mainMixer = eng.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44100.0

        let nodeFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) ?? outputFormat

        var localState = synthState
        let params = self.renderParams
        let currentSampleRate = sampleRate

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let (masterVol, type) = params.snapshot()
            let sr = currentSampleRate > 0 ? currentSampleRate : 44100.0
            let invSr = 1.0 / sr

            let numBuffers = ablPointer.count
            let isDeinterleaved = numBuffers >= 2
            let bufL = ablPointer[0].mData?.assumingMemoryBound(to: Float.self)
            let bufR = isDeinterleaved ? ablPointer[1].mData?.assumingMemoryBound(to: Float.self) : nil
            let isInterleavedStereo = (!isDeinterleaved && ablPointer[0].mNumberChannels == 2)

            for frame in 0..<Int(frameCount) {
                // 1. 生成独立的左右声道随机白噪声 (Binaural Decorrelated Seed)
                let whiteL = Float.random(in: -1.0...1.0)
                let whiteR = Float.random(in: -1.0...1.0)

                // 2. 左声道粉红+棕色噪声滤波器更新 (Kellet's Algorithm)
                localState.b0L = 0.99886 * localState.b0L + whiteL * 0.0555179
                localState.b1L = 0.99332 * localState.b1L + whiteL * 0.0750759
                localState.b2L = 0.96900 * localState.b2L + whiteL * 0.1538520
                localState.b3L = 0.86650 * localState.b3L + whiteL * 0.3104856
                localState.b4L = 0.55000 * localState.b4L + whiteL * 0.5329522
                localState.b5L = -0.7616 * localState.b5L - whiteL * 0.0168980
                let pinkL = (localState.b0L + localState.b1L + localState.b2L + localState.b3L + localState.b4L + localState.b5L + localState.b6L + whiteL * 0.5362) * 0.11
                localState.b6L = whiteL * 0.115926
                localState.brownL = (localState.brownL + (0.02 * whiteL)) / 1.02

                // 3. 右声道粉红+棕色噪声滤波器更新
                localState.b0R = 0.99886 * localState.b0R + whiteR * 0.0555179
                localState.b1R = 0.99332 * localState.b1R + whiteR * 0.0750759
                localState.b2R = 0.96900 * localState.b2R + whiteR * 0.1538520
                localState.b3R = 0.86650 * localState.b3R + whiteR * 0.3104856
                localState.b4R = 0.55000 * localState.b4R + whiteR * 0.5329522
                localState.b5R = -0.7616 * localState.b5R - whiteR * 0.0168980
                let pinkR = (localState.b0R + localState.b1R + localState.b2R + localState.b3R + localState.b4R + localState.b5R + localState.b6R + whiteR * 0.5362) * 0.11
                localState.b6R = whiteR * 0.115926
                localState.brownR = (localState.brownR + (0.02 * whiteR)) / 1.02

                var sampleL: Float = 0.0
                var sampleR: Float = 0.0

                switch type {
                case .springRain:
                    // 真实双声道空间粉红细雨底噪 + 随机立体声雨滴下落
                    sampleL = pinkL * 0.65
                    sampleR = pinkR * 0.65
                    if Float.random(in: 0...1) < 0.0009 {
                        let pan = Float.random(in: 0.1...0.9)
                        let drop = Float.random(in: 0.08...0.25)
                        sampleL += drop * (1.0 - pan)
                        sampleR += drop * pan
                    }

                case .oceanWaves:
                    // 基于硬件真实采样率的缓慢潮汐流动，立体声相位差营造波浪由左向右席卷感
                    localState.wavePhase += (2.0 * .pi * 0.085) * invSr
                    let envL = Float(0.35 + 0.35 * sin(localState.wavePhase) + 0.12 * sin(localState.wavePhase * 0.43))
                    let envR = Float(0.35 + 0.35 * sin(localState.wavePhase - 0.28) + 0.12 * sin(localState.wavePhase * 0.43 - 0.12))
                    sampleL = (pinkL * 0.4 + localState.brownL * 0.6) * envL
                    sampleR = (pinkR * 0.4 + localState.brownR * 0.6) * envR

                case .forestBreeze:
                    // 温暖低频立体声森林微风，左右微弱差速起伏
                    localState.wavePhase += (2.0 * .pi * 0.14) * invSr
                    let breezeL = Float(0.5 + 0.32 * sin(localState.wavePhase))
                    let breezeR = Float(0.5 + 0.32 * sin(localState.wavePhase + 0.35))
                    sampleL = localState.brownL * 1.15 * breezeL
                    sampleR = localState.brownR * 1.15 * breezeR

                case .summerNight:
                    // 柔和微夜风 + 随机左右声相蟋蟀鸣叫
                    localState.chirpTimer += invSr
                    var chirp: Float = 0.0
                    if localState.chirpTimer > 2.2 {
                        if localState.chirpTimer < 2.35 {
                            localState.phase += (2.0 * .pi * 4200.0) * invSr
                            let env = Float(sin((localState.chirpTimer - 2.2) / 0.15 * .pi))
                            chirp = Float(sin(localState.phase)) * env * 0.16
                        } else {
                            localState.chirpTimer = Double.random(in: 0.0...0.75)
                        }
                    }
                    sampleL = pinkL * 0.35 + chirp * 0.85
                    sampleR = pinkR * 0.35 + chirp * 0.55

                case .morningBirds:
                    // 柔和清晨双音鸟鸣（精准适配硬件采样率，声学频移与自然空间混响）
                    localState.birdTimer += invSr
                    var birdTone: Float = 0.0
                    if localState.birdTimer > 2.7 {
                        if localState.birdTimer < 3.15 {
                            let prog = (localState.birdTimer - 2.7) / 0.45
                            let freq = 2600.0 + sin(prog * .pi * 3) * 600.0
                            localState.phase += (2.0 * .pi * freq) * invSr
                            let env = Float(sin(prog * .pi))
                            birdTone = Float(sin(localState.phase)) * env * 0.22
                        } else {
                            localState.birdTimer = Double.random(in: 0.0...0.65)
                        }
                    }
                    sampleL = pinkL * 0.15 + birdTone * 0.95
                    sampleR = pinkR * 0.15 + birdTone * 0.70
                }

                // 应用主音量增益
                let outL = sampleL * masterVol
                let outR = sampleR * masterVol

                // 准确写入 CoreAudio 音频通道 (支持 macOS 标准非交错双声道与交错双声道)
                if isDeinterleaved {
                    bufL?[frame] = outL
                    bufR?[frame] = outR
                } else if isInterleavedStereo, let buf = bufL {
                    buf[frame * 2] = outL
                    buf[frame * 2 + 1] = outR
                } else if let buf = bufL {
                    buf[frame] = (outL + outR) * 0.5
                }
            }
            return noErr
        }

        eng.attach(node)
        eng.connect(node, to: mainMixer, format: nodeFormat)

        self.engine = eng
        self.sourceNode = node
    }
}
