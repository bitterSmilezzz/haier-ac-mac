import SwiftUI
import HaierACCore

/// 操作反馈 toast：显示最近一次操作结果，几秒后自动消失
struct OperationToast: View {
    @EnvironmentObject var model: AppModel
    @State private var visible = false
    /// toast 版本号：每次出现 +1，旧定时器通过比对版本号放弃（防止旧 toast 提前隐藏新 toast）
    @State private var noticeGeneration = 0

    var body: some View {
        Group {
            if let notice = model.operationNotice, visible {
                HStack(spacing: 8) {
                    Image(systemName: notice.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(notice.isError ? Theme.warning : Theme.success)
                    Text(notice.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                        .fill(Theme.surface2)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                                .strokeBorder(notice.isError ? Theme.warning.opacity(0.5) : Theme.success.opacity(0.5), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    let generation = noticeGeneration
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        // 期间有新 toast 出现（generation 已变）则不隐藏当前内容
                        guard generation == noticeGeneration else { return }
                        withAnimation(.easeOut(duration: 0.25)) {
                            visible = false
                        }
                    }
                }
            }
        }
        .onChange(of: model.operationNotice) { _ in
            noticeGeneration += 1
            withAnimation(.spring(duration: 0.3)) {
                visible = model.operationNotice != nil
            }
        }
        .allowsHitTesting(false)
    }
}

/// 新版本提示条：有可用更新时显示在设备列表顶部
struct UpdateBanner: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if let update = model.updateAvailable {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("发现新版本 v\(update.version)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("点击前往 GitHub 下载更新")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSubtle)
                }
                Spacer()
                if let url = update.url as URL? {
                    Link(destination: url) {
                        Text("前往")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous)
                                    .fill(Theme.accent)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.spaceMD)
            .background(Theme.cardBackground(Theme.surface1))
        }
    }
}
