# 财务快照 · Snapshot Ledger

SwiftUI macOS 本地记账工具：录入账户余额，查看资产变化和期间收支。

- 快照新增与编辑，信用卡额度差额、新币折算。
- 人民币资产、美元资产折合、欠款折线图，支持悬停金额提示。
- 收入/支出柱状图；收入合并工资、公积金及其他收入。
- 本地 JSON 原子保存、CSV 导出、重复日期检查。

## 构建

需要 Apple Silicon Mac、macOS 14+、Xcode 命令行编译工具及 Python 3，无第三方依赖。

```sh
python3 src/macapp/build.py
open build/财务快照.app
```

首次运行为空账本；信用卡额度和换算汇率使用中性占位值，录入前在“额度与汇率”中设置。已有本机记录保存在 `~/Library/Application Support/SnapshotLedger/snapshots.json`，构建不会读取或打包该文件。App 与 Excel 独立维护。

## 验证

```sh
python3 tools/check_privacy.py
build/财务快照.app/Contents/MacOS/SnapshotLedger --self-test
build/财务快照.app/Contents/MacOS/SnapshotLedger --integration-test /tmp/snapshot-ledger-tests
build/财务快照.app/Contents/MacOS/SnapshotLedger --render-qa /tmp/snapshot-ledger-ui
```

测试及渲染仅使用代码生成的虚构数据。渲染需 macOS 图形会话。桌面工具超时，真实鼠标交互尚未完成自动化验证。

## 数据边界

本仓库只保存 App 源码、通用图标和虚构测试。不包含个人流水、账本、实际余额/收入、截图、个人配置或带数据的 App 包。`.gitignore` 默认拒绝非白名单文件，提交前执行隐私检查；私有仓库也不应提交真实财务数据。

期间支出按快照余额差推算，并剔除证券净入金；并非逐笔消费记录。账期采用每月 15 日规则。源码中的测试金额仅验证计算，不能视为任何人的财务状况。
