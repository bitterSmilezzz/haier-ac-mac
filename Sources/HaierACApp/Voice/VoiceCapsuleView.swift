import SwiftUI
import AppKit

/// 悬浮语音控制胶囊视图
struct VoiceCapsuleView: View {
    @ObservedObject var voiceManager: VoiceControlManager
    let targetDeviceName: String
    let onClose: () -> Void
    let onCommit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏：设备信息与状态指示
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusDotColor.opacity(0.6), radius: 4)

                    Text("语音控制")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkSubtle)
                }

                Spacer()

                Text(targetDeviceName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.surface2.opacity(0.7))
                    .clipShape(Capsule())

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // 中部核心内容区
            HStack(spacing: 16) {
                // 左侧：状态图标 / 动态波形
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )

                    switch voiceManager.state {
                    case .listening:
                        // 动态音频波形
                        HStack(spacing: 3) {
                            ForEach(0..<4) { index in
                                WaveBar(
                                    level: voiceManager.audioLevel,
                                    index: index
                                )
                            }
                        }
                    case .processing:
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(Theme.accent)
                    case .success:
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.success)
                    case .failed, .permissionDenied:
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.warning)
                    case .idle:
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .frame(width: 48, height: 48)

                // 中间：实时文字与反馈
                VStack(alignment: .leading, spacing: 4) {
                    if !voiceManager.transcribedText.isEmpty {
                        Text(voiceManager.transcribedText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2)
                    } else {
                        switch voiceManager.state {
                        case .listening:
                            Text("正在聆听，请说出指令...")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.inkSubtle)
                        case .success(let msg):
                            Text(msg)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.success)
                        case .failed(let msg):
                            Text(msg)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.warning)
                        case .permissionDenied(let msg):
                            Text(msg)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.danger)
                                .lineLimit(2)
                        case .processing:
                            Text("正在解析并下发...")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.inkSubtle)
                        case .idle:
                            Text("点击或按快捷键开始说话")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.inkSubtle)
                        }
                    }

                    // 辅助提示语
                    if case .listening = voiceManager.state {
                        Text("试试说：“打开空调”、“调到26度”、“太热了”、“切换制冷”")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkTertiary)
                            .lineLimit(1)
                    } else if case .success(let msg) = voiceManager.state, !voiceManager.transcribedText.isEmpty {
                        Text(msg)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.success)
                    }
                }

                Spacer()

                // 右侧操作按钮
                if voiceManager.state == .listening && !voiceManager.transcribedText.isEmpty {
                    Button(action: onCommit) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // 底部细条：快捷提示
            HStack {
                Text("按 Esc 退出  •  停顿自动执行")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .frame(width: 440)
        .background(
            ZStack {
                // 毛玻璃背景
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)

                // 细微反光边框
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.hairlineStrong, lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
        .padding(20) // 给窗口阴影留出边距
    }

    private var statusDotColor: Color {
        switch voiceManager.state {
        case .listening: return Theme.accent
        case .processing: return Theme.warning
        case .success: return Theme.success
        case .failed: return Theme.warning
        case .permissionDenied: return Theme.danger
        case .idle: return Theme.inkTertiary
        }
    }

    private var iconBackgroundColor: Color {
        switch voiceManager.state {
        case .listening: return Theme.accent.opacity(0.12)
        case .processing: return Theme.warning.opacity(0.12)
        case .success: return Theme.success.opacity(0.15)
        case .failed, .permissionDenied: return Theme.danger.opacity(0.12)
        case .idle: return Theme.surface2
        }
    }
}

/// 声音跳动小柱子
private struct WaveBar: View {
    let level: Float
    let index: Int

    var body: some View {
        // 根据 index 和 level 产生参差有致的跳动高度
        let factor: CGFloat = [0.8, 1.2, 1.0, 0.7][index % 4]
        let baseHeight: CGFloat = 6
        let dynamicHeight = min(max(baseHeight + CGFloat(level) * 22 * factor, 4), 26)

        RoundedRectangle(cornerRadius: 2)
            .fill(Theme.accent)
            .frame(width: 3, height: dynamicHeight)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.5), value: dynamicHeight)
    }
}
