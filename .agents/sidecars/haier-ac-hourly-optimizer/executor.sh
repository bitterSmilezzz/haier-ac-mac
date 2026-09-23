#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Haier AC 每小时自动化巡检优化与发版调度执行脚本
# ==============================================================================

PROJECT_DIR="/Users/fangshoufanji/workspace/ai-test/haier-ac-mac"
PROJECT_ID="20a02443-a136-49d7-bfda-b9842c61e0ac"
AGENTAPI_BIN="/Users/fangshoufanji/.gemini/antigravity/bin/agentapi"
LOG_DIR="${HOME}/.gemini/antigravity/sidecar_data/haier-ac-hourly-optimizer/logs"

mkdir -p "${LOG_DIR}"
CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
LOG_FILE="${LOG_DIR}/hourly_run_$(date +%Y%m%d).log"

echo "[${CURRENT_TIME}] [SCHEDULED TASK TRIGGERED] Haier AC Hourly Optimizer Starting..." >> "${LOG_FILE}"

export ANTIGRAVITY_PROJECT_ID="${PROJECT_ID}"
export PATH="${HOME}/.gemini/antigravity/bin:${PATH}"

PROMPT_TEXT=$(cat <<'EOF'
【Haier AC 自动化整点巡检优化与发版任务】
工作区：/Users/fangshoufanji/workspace/ai-test/haier-ac-mac

【用户最高优先级全权授权】
用户已全权授权无需通过弹窗让用户选择方案，所有优化决策、方案选择与 Proceed 确认均由 Agent 自主决定并全自动执行，严禁打断等待用户回答！

【任务要求与流水线执行规范】
1. 深入代码巡检：
   - 检查 haier-ac-mac 项目源码、架构、UI 动效与业务能力；
   - 自主选定 1~2 个高价值优化点（如：动画丝滑度、能耗统计持久化/图表、离线降级容错、滤网深度算法、macOS 原生状态栏细节等）；
   - 直接完成代码编写与重构。
2. 本地编译与校验：
   - 使用 SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build 构建验证；
   - 如构建或测试未通过，必须自主分析错误、修复代码，直至 100% 编译成功；
   - 验证无误后运行 ./build_app.sh 打包产物。
3. 自动化发版与远程同步：
   - 获取最新 Git Tag，自动递增小版本号（例如当前为 v1.9.20，新版本为 v1.9.21）；
   - 执行 git add、git commit 并安全推送到 remote main 分支；
   - 创建对应版本 Git Tag 并推送到远程；
   - 使用 gh release create 发布 GitHub Release，附带构建产物压缩包与更新日志。
4. 项目文档同步：
   - 更新 README.md 与 walkthrough.md，清晰记载本次更新的优化内容、验证过程与发版信息。
5. 安全敏感数据脱敏底线：
   - 严禁提交或上传任何个人手机号、真实密码、第三方 Secret Token 等敏感隐私数据。
EOF
)

if [ -x "${AGENTAPI_BIN}" ]; then
    echo "[${CURRENT_TIME}] Launching Antigravity new-conversation via agentapi..." >> "${LOG_FILE}"
    "${AGENTAPI_BIN}" new-conversation --title="Haier AC 每小时自动巡检优化发版" "${PROMPT_TEXT}" >> "${LOG_FILE}" 2>&1 || {
        echo "[${CURRENT_TIME}] [ERROR] agentapi call failed, see details above." >> "${LOG_FILE}"
    }
else
    echo "[${CURRENT_TIME}] [ERROR] agentapi not found at ${AGENTAPI_BIN}" >> "${LOG_FILE}"
    exit 1
fi

echo "[${CURRENT_TIME}] [COMPLETED] Scheduled task dispatch finished." >> "${LOG_FILE}"
