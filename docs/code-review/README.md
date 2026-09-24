# Code Review Reports

此目录用于存放外部 Agent / 工具对本项目代码更新的审查报告（Code Review）。

## 命名与格式建议
- 建议文件命名格式：`YYYYMMDD_review_vX.Y.Z.md` 或 `review_<feature>.md`。
- 定时任务（Scheduled Tasks）在每 2 小时触发巡检时，会扫描此目录下的最新审查报告。
- 若报告中指出问题、坏味道或潜在缺陷，定时任务将自动进行修复并编译验证。
