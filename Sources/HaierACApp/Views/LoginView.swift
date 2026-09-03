import SwiftUI
import HaierACCore

struct LoginView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            VStack(spacing: Theme.spaceXL) {
                Spacer()

                // 品牌区
                VStack(spacing: Theme.spaceSM) {
                    ZStack {
                        Circle()
                            .fill(Theme.surface2)
                            .frame(width: 72, height: 72)
                            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                        Image(systemName: "snowflake")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    Text("海尔空调控制")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .tracking(-0.4)
                    Text("通过海尔智家云连接您的统帅空调")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSubtle)
                }

                // 表单卡片
                VStack(spacing: Theme.spaceSM) {
                    VStack(spacing: 10) {
                        TextField("手机号", text: $model.phone)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.surface1)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                                    .strokeBorder(Theme.hairline, lineWidth: 1)
                            )
                            .cornerRadius(Theme.radiusMD)

                        SecureField("密码（仅用于登录，不保存）", text: $model.password)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.surface1)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusMD, style: .continuous)
                                    .strokeBorder(Theme.hairline, lineWidth: 1)
                            )
                            .cornerRadius(Theme.radiusMD)
                    }
                }
                .padding(Theme.spaceMD)
                .background(Theme.cardBackground(Theme.surface1))
                .frame(width: 320)

                Button {
                    Task { await model.login() }
                } label: {
                    HStack(spacing: 6) {
                        if model.phase == .connecting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(model.phase == .connecting ? "登录中..." : "登录")
                    }
                    .frame(width: 280)
                }
                .buttonStyle(Theme.primaryButtonStyle())
                .disabled(model.phone.isEmpty || model.password.isEmpty || model.phase == .connecting)

                Text("凭据仅用于获取访问令牌，密码不会保存在本机")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)

                Spacer()
            }
            .padding(Theme.spaceXL)
        }
    }
}
