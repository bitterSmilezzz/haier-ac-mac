import Foundation
import AVFoundation
import HaierACCore

/// 助眠自然白噪音与晨间音律类型
public enum AmbientSoundType: String, CaseIterable, Identifiable, Codable {
    case springRain = "春夜细雨"
    case oceanWaves = "海风浪涌"
    case forestBreeze = "森林微风"
    case summerNight = "夏夜静谧"
    case morningBirds = "清晨林鸟"

    public var id: String { rawValue }

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

/// 纯算法程序化自然助眠音引擎（零外部音频资产依赖，极度轻量低功耗）
/// 基于 AVAudioEngine 与 AVAudioSourceNode 实时合成春雨、浪涌、微风、夜虫与晨鸟
@MainActor
public final class AmbientSoundEngine: ObservableObject {
    public static let shared = AmbientSoundEngine()

    @Published public private(set) var isPlaying: Bool = false
    @Published public var currentType: AmbientSoundType = .springRain
    @Published public var volume: Float = 0.5 {
        didSet {
            let clamped = min(max(volume, 0.0), 1.0)
            targetVolume = clamped
        }
    }

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    // 内部实时合成参数
    private var sampleRate: Double = 44100.0
    private var targetVolume: Float = 0.5
    private var activeGain: Float = 0.0

    // 合成器状态
    private struct SynthesisState {
        var b0: Float = 0.0
        var b1: Float = 0.0
        var b2: Float = 0.0
        var b3: Float = 0.0
        var b4: Float = 0.0
        var b5: Float = 0.0
        var b6: Float = 0.0
        var brown: Float = 0.0

        var phase: Double = 0.0
        var wavePhase: Double = 0.0
        var chirpTimer: Double = 0.0
        var birdTimer: Double = 0.0
        var birdPitch: Double = 3000.0
    }

    private var synthState = SynthesisState()
    private var fadeTimer: Task<Void, Never>?

    private init() {}

    /// 播放指定环境音（支持平滑淡入）
    public func play(type: AmbientSoundType? = nil, fadeInDuration: TimeInterval = 2.0) {
        if let type = type {
            self.currentType = type
        }
        setupEngineIfNeeded()

        guard let engine = engine, !engine.isRunning else {
            // 如果已在运行，平滑过渡目标类型
            fadeTimer?.cancel()
            targetVolume = min(max(volume, 0.0), 1.0)
            isPlaying = true
            return
        }

        do {
            try engine.start()
            isPlaying = true
            activeGain = 0.0
            targetVolume = min(max(volume, 0.0), 1.0)

            // 平滑淡入
            fadeTimer?.cancel()
            fadeTimer = Task { @MainActor in
                let steps = 40
                let stepTime = max(0.01, fadeInDuration / Double(steps))
                let gainStep = self.targetVolume / Float(steps)
                for _ in 0..<steps {
                    try? await Task.sleep(nanoseconds: UInt64(stepTime * 1_000_000_000))
                    if Task.isCancelled { break }
                    self.activeGain = min(self.targetVolume, self.activeGain + gainStep)
                }
                self.activeGain = self.targetVolume
            }
            AppLog.log("助眠音频引擎: 启动播放「\(currentType.rawValue)」")
        } catch {
            AppLog.log("⚠️ 助眠音频引擎启动失败: \(error.localizedDescription)")
            isPlaying = false
        }
    }

    /// 停止播放（支持平滑淡出）
    public func stop(fadeOutDuration: TimeInterval = 1.5) {
        guard isPlaying else { return }

        fadeTimer?.cancel()
        if fadeOutDuration <= 0.1 {
            self.activeGain = 0.0
            self.engine?.stop()
            self.isPlaying = false
            return
        }

        fadeTimer = Task { @MainActor in
            let steps = 30
            let stepTime = max(0.01, fadeOutDuration / Double(steps))
            let current = self.activeGain
            let gainStep = current / Float(steps)

            for _ in 0..<steps {
                try? await Task.sleep(nanoseconds: UInt64(stepTime * 1_000_000_000))
                if Task.isCancelled { break }
                self.activeGain = max(0.0, self.activeGain - gainStep)
            }
            self.activeGain = 0.0
            self.engine?.stop()
            self.isPlaying = false
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
        let currentTypeProvider = { [weak self] () -> AmbientSoundType in
            self?.currentType ?? .springRain
        }
        let gainProvider = { [weak self] () -> Float in
            self?.activeGain ?? 0.0
        }

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let type = currentTypeProvider()
            let masterVol = gainProvider()

            for frame in 0..<Int(frameCount) {
                // 生成基础高斯/粉红噪声 (Kellet's algorithm)
                let white = Float.random(in: -1.0...1.0)
                localState.b0 = 0.99886 * localState.b0 + white * 0.0555179
                localState.b1 = 0.99332 * localState.b1 + white * 0.0750759
                localState.b2 = 0.96900 * localState.b2 + white * 0.1538520
                localState.b3 = 0.86650 * localState.b3 + white * 0.3104856
                localState.b4 = 0.55000 * localState.b4 + white * 0.5329522
                localState.b5 = -0.7616 * localState.b5 - white * 0.0168980
                let pink = (localState.b0 + localState.b1 + localState.b2 + localState.b3 + localState.b4 + localState.b5 + localState.b6 + white * 0.5362) * 0.11
                localState.b6 = white * 0.115926
                localState.brown = (localState.brown + (0.02 * white)) / 1.02

                var sampleL: Float = 0.0
                var sampleR: Float = 0.0

                switch type {
                case .springRain:
                    // 粉红雨声底噪 + 随机柔和雨滴微瞬态
                    sampleL = pink * 0.65
                    sampleR = (pink + white * 0.05) * 0.65
                    if Float.random(in: 0...1) < 0.0008 {
                        let drop = Float.random(in: 0.1...0.3)
                        sampleL += drop
                        sampleR += drop * 0.8
                    }

                case .oceanWaves:
                    // 慢周期潮汐起伏
                    localState.wavePhase += (2.0 * .pi * 0.09) / 44100.0
                    let envelope = Float(0.35 + 0.35 * sin(localState.wavePhase) + 0.15 * sin(localState.wavePhase * 0.43))
                    let waveNoise = (pink * 0.4 + localState.brown * 0.6) * envelope
                    sampleL = waveNoise
                    sampleR = waveNoise * 0.95

                case .forestBreeze:
                    // 温暖低频微风与轻微晃动
                    localState.wavePhase += (2.0 * .pi * 0.15) / 44100.0
                    let breeze = Float(0.5 + 0.3 * sin(localState.wavePhase))
                    sampleL = localState.brown * 1.2 * breeze
                    sampleR = localState.brown * 1.2 * (1.0 - breeze * 0.2)

                case .summerNight:
                    // 极柔底噪 + 稀疏蟋蟀高频鸣叫
                    localState.chirpTimer += 1.0 / 44100.0
                    var chirp: Float = 0.0
                    if localState.chirpTimer > 2.2 {
                        if localState.chirpTimer < 2.35 {
                            localState.phase += (2.0 * .pi * 4200.0) / 44100.0
                            let env = Float(sin((localState.chirpTimer - 2.2) / 0.15 * .pi))
                            chirp = Float(sin(localState.phase)) * env * 0.15
                        } else {
                            localState.chirpTimer = Double.random(in: 0.0...0.8)
                        }
                    }
                    sampleL = pink * 0.35 + chirp
                    sampleR = pink * 0.35 + chirp * 0.7

                case .morningBirds:
                    // 柔和清晨双音鸟鸣
                    localState.birdTimer += 1.0 / 44100.0
                    var birdTone: Float = 0.0
                    if localState.birdTimer > 2.8 {
                        if localState.birdTimer < 3.2 {
                            let prog = (localState.birdTimer - 2.8) / 0.4
                            let freq = 2600.0 + sin(prog * .pi * 3) * 600.0
                            localState.phase += (2.0 * .pi * freq) / 44100.0
                            let env = Float(sin(prog * .pi))
                            birdTone = Float(sin(localState.phase)) * env * 0.22
                        } else {
                            localState.birdTimer = Double.random(in: 0.0...0.7)
                        }
                    }
                    sampleL = pink * 0.15 + birdTone
                    sampleR = pink * 0.15 + birdTone * 0.85
                }

                // 应用主音量增益
                let outL = sampleL * masterVol
                let outR = sampleR * masterVol

                for buffer in ablPointer {
                    guard let bufPtr = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    if buffer.mNumberChannels == 2 {
                        bufPtr[frame * 2] = outL
                        bufPtr[frame * 2 + 1] = outR
                    } else {
                        bufPtr[frame] = (outL + outR) * 0.5
                    }
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
