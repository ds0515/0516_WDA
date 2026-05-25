# Mac Codex 迁移交接记录（2026-05-25）

本文用于把当前 iOS/WDA 脱机自动化项目迁移到新 Mac 的 Codex app 继续执行。它是阶段状态与操作边界的交接文档，不是密钥仓库；不得在本文、日志、提交信息或终端输出中记录 GitHub token、Apple ID 密码、p12 私钥内容、p12 密码、完整 mobileprovision 内容或敏感日志。

## 1. 当前目标

在 `D:\2026_soft\0511_Appium_WDA` 中，围绕 iOS/WDA 脱机自动化项目，分阶段推进“主程序 + 代理程序 + WDA 控制链路”的需求细化、技术方案和最小可验证实现。

V1 聚焦手机内闭环：

- 主程序发现/连接代理。
- 代理启动或维持 WDA。
- 主程序通过 WDA 执行截图、节点、点击、滑动、输入、脚本运行。
- PC/Windows 中控端 V1 不实现 UI，只预留协议、日志、设备发现接口。

目标参考 EasyClick iOS 脱机版，但只做功能级对齐，不复制品牌、UI、私有代码、授权体系或规避机制。

## 2. 固定执行规则

新 Mac 上继续时必须保持以下规则：

- 默认中文回复。
- 每次恢复上下文后，先重新读取目标、当前阶段、`git status`、最近变更、`docs/phase2-pitfalls-and-lessons.md`，再继续。
- 每次开始先做 Skill 路由。优先 `mobile-rpa-workflow`；涉及代码变更时使用 `tdd-workflow`；涉及失败时使用 `debug-workflow`；涉及提交时使用 `commit-workflow`。
- 不得跳阶段。每阶段必须先声明：假设、成功标准、验证方式。
- 不做无关重构。每个变更必须能追溯到本目标。
- 仓库若有未提交改动，先报告并保护，不得回滚用户改动。
- 不 push、不提交，除非用户明确要求。
- GitHub token 只在确实需要 GitHub 登录、鉴权、dispatch 或远端写入时读取；不得输出 token。
- 不存储、打印、提交证书密码、账号密码、p12、mobileprovision 私密内容。
- 真机/高风险操作必须要求明确 UDID 或 WDA endpoint，不自动选择设备。
- 出现验证码、风控、异常登录、限制、封禁等页面时，停止运行并保存上下文。
- 不设计或实现 CAPTCHA、风控、封禁、访问控制、平台限制绕过。

## 3. 阶段状态

当前阶段：**Phase 2：代理/WDA 最小闭环**。

历史阶段状态：

- Phase 0 已完成：环境复位与事实确认。
- Phase 1 已完成：需求与边界文档。
- Phase 2 进行中：GitHub 云端 unsigned IPA 构建已跑通，但 signing/runtime acceptance 尚未通过。
- 不得进入 Phase 3，直到 Phase 2 的 WDA `/status`、UI routes、Bonjour 或手动 endpoint 在可接受签名/运行条件下通过。

Phase 2 假设：

- GitHub 可以负责远端编译或托管源码。
- WDA 真机 UI 授权仍受 Apple Development 签名材料、UDID、entitlements 和设备运行时授权约束。
- Distribution-signed native host 可以用于复现已知阻塞，但不能作为 Phase 2 完成证据。

Phase 2 成功标准：

- 代理侧能启动或维持 WDA HTTP 服务。
- `/status` 可作为健康检查。
- Bonjour `_wda._tcp.` 或手动 endpoint 至少一种可用。
- 截图/source 等 UI routes 不再返回 “Not authorized for performing UI testing actions”。

Phase 2 验证方式：

- 静态 smoke test 覆盖关键文件。
- signing readiness 报告确认 native host 与 runner 均满足 Apple Development 条件。
- 有条件时真机验证 `http://<device-ip>:8100/status`。
- UI route 验证至少覆盖 `/screenshot`、`/source`，后续再进入点击、滑动、输入链路。

## 4. 关键仓库与分支

Windows 本地仓库：

- `D:\2026_soft\0511_Appium_WDA`
- 本地分支：`lobster-wda-cloud-resign`
- Windows 本地最新 git commit：`8b5f2819 兼容ARC路由队列`
- Windows 工作区非常脏，包含大量 modified/deleted/untracked 文件；这些改动视为受保护，不要回滚。

目标 GitHub 仓库：

- `ds0515/0516_WDA`
- URL: `https://github.com/ds0515/0516_WDA`
- 目标分支：`lobster-wda-cloud-resign`
- 2026-05-18 通过 GitHub API 同步过候选源码。
- 最新已验证云构建的远端代码基线 commit：`7440401e570cfc5acaaaffd7a17fc026232c4fe5`
- 本交接文档单独发布到远端后，远端 HEAD 可能晚于上述代码基线；不要仅因 HEAD 晚于 `7440401e...` 就误判为源码不同步。

新 Mac 建议从远端迁移：

```bash
git clone https://github.com/ds0515/0516_WDA.git
cd 0516_WDA
git checkout lobster-wda-cloud-resign
git rev-parse HEAD
```

期望 `git rev-parse HEAD` 至少不早于 `7440401e570cfc5acaaaffd7a17fc026232c4fe5`。如果不同，先不要继续真机操作，先检查远端分支状态。

## 5. 关键本地材料（不要提交）

Windows 上的历史材料位置：

- 主程序 IPA：`D:\2026_soft\0430_WS\0423_iPhone11\release.ipa`
- 代理程序 IPA：`D:\2026_soft\0430_WS\0423_iPhone11\agent-runner.ipa`
- GitHub 凭据来源文件：`D:\2026_soft\0430_WS\0423_iPhone11\github.txt`
- Distribution profile：`D:\2026_soft\0430_WS\0423_iPhone11\cert.mobileprovision`
- p12：`D:\2026_soft\0430_WS\0423_iPhone11\cert.p12`
- 踩坑记录：`D:\2026_soft\0511_Appium_WDA\docs\phase2-pitfalls-and-lessons.md`

迁移到 Mac 时：

- 可把 IPA、`github.txt`、`cert.mobileprovision`、`cert.p12` 放到 Mac 用户目录下的私有目录，例如 `~/secure-wda-materials/`。
- 不要放进 Git 仓库目录。
- 不要把 p12 密码写入仓库、文档或日志。
- 如需 Codex 读取 `github.txt`，只能在 GitHub API/Actions 操作确实需要时读取，不得打印内容。

## 6. 设备与 bundle 信息

目标设备：

- 设备：iPhone 11
- UDID：`00008030-0001598021E2802E`
- 历史 iOS 版本：`18.7.7`
- 历史 Wi-Fi IP：`192.168.0.128`，该地址可能变化，Mac 上必须重新确认。

目标 bundle：

- native host bundle id：`app.honey4212.crystal5671`
- XCTest runner bundle id：`app.honey4212.crystal5671.xctrunner`
- 旧主程序 bundle id：`com.ws.max`
- 旧 agent runner bundle id：`com.ieasyclick.auto.ios.xxx888x2288876289.xctrunner`

重要历史事实：

- 用户曾手动卸载 iPhone 上的 IPA，是为了避免影响；后续如需要可以重新安装。
- Windows 上曾安装过 distribution-signed `Lobster WDA`，USB `/status` 曾可返回 200，但 `/screenshot`、`/source` 返回 UI testing 未授权。
- 后续 readiness 又显示目标 iPhone 不可见；Mac 上不要复用旧设备状态，必须重新连接、解锁、信任电脑后再验证。

## 7. GitHub 云端构建状态

工作流：

- `.github/workflows/wda-ios-unsigned-package.yml`
- 工作流名：`Build unsigned iOS WDA package`
- 支持 `package_kind=native_host`、`runner`、`both`
- GitHub-hosted runner 可用输入：`runner_labels_json=macos-15`
- 默认 self-hosted labels：`["self-hosted","macOS","X64","wda-macos-self-hosted"]`

已成功的 GitHub-hosted 构建：

- Run `26018145454`：成功生成 unsigned native host IPA。
- Run `26018721209`：在远端 commit `7440401e...` 后重新构建成功。
- Windows 下载路径：`D:\2026_soft\0511_Appium_WDA\artifacts\lobster-wda-host\LobsterWDAHost-unsigned-ipa-26018721209\LobsterWDAHost.unsigned.ipa`
- 验证输出：`Native host IPA verified: CFBundleIdentifier=app.honey4212.crystal5671`

注意：

- 工作流 artifact retention 曾设置为 1 天。本文日期是 2026-05-25，2026-05-18 的 artifact 很可能已经过期。新 Mac 上应重新 dispatch 构建或本地构建。
- GitHub 云端构建只证明 unsigned IPA 可构建，不证明签名、安装、WDA UI automation 或无线 endpoint 可用。

在 Mac 上用 PowerShell 复跑 validate-only 云构建的参考命令：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./Scripts/continue-native-wda-goal.ps1 `
  -Repo 'ds0515/0516_WDA' `
  -Workflow 'wda-ios-unsigned-package.yml' `
  -Ref 'lobster-wda-cloud-resign' `
  -BuildPackageKind 'native_host' `
  -RunnerLabelsJson 'macos-15' `
  -TokenPath '<Mac上github.txt的私有路径>' `
  -DeviceUdid '00008030-0001598021E2802E' `
  -ValidateIpaOnly `
  -SkipRemoteHeadCheck `
  -AllowDirtyCloudBuild `
  -PollSeconds 20 `
  -TimeoutMinutes 60
```

该命令只做 cloud build、artifact 下载和 unsigned IPA 结构验证；不签名、不安装、不启动、不操作真机。

## 8. 当前 Signing gate

Phase 2 仍卡在 Signing gate。

必须补齐：

- `app.honey4212.crystal5671` 的 Apple Development provisioning profile。
- `app.honey4212.crystal5671.xctrunner` 的 Apple Development provisioning profile。
- 两个 profile 都必须：
  - 包含 UDID `00008030-0001598021E2802E`
  - `get-task-allow=true`
  - 未过期
  - 与后续用于签名的 Apple Development certificate/private key 属于同一 team
- 匹配的 Apple Development certificate/private key，或可用 p12，但 p12 和密码不得进入仓库、日志、文档或提交。

已有但不能作为 Phase 2 验收的材料：

- `D:\2026_soft\0430_WS\0423_iPhone11\cert.mobileprovision`
- 该 profile 覆盖 `app.honey4212.crystal5671` 且包含目标 UDID，但属于 distribution，`get-task-allow=false`。
- 它只能作为复现 distribution blocker 的实验材料，不能作为 WDA UI automation 完成证据。

签名材料补齐后，应先跑只读复查，不要直接安装：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./Scripts/report-ios-signing-profiles.ps1 `
  -BundleId 'app.honey4212.crystal5671' `
  -DeviceUdid '00008030-0001598021E2802E' `
  -SearchRoot '<Mac上profile搜索目录>' `
  -NoFail

pwsh -NoProfile -ExecutionPolicy Bypass -File ./Scripts/report-ios-signing-profiles.ps1 `
  -BundleId 'app.honey4212.crystal5671.xctrunner' `
  -DeviceUdid '00008030-0001598021E2802E' `
  -SearchRoot '<Mac上profile搜索目录>' `
  -NoFail

pwsh -NoProfile -ExecutionPolicy Bypass -File ./Scripts/report-phase2-signing-unblock-plan.ps1 `
  -DeviceUdid '00008030-0001598021E2802E' `
  -ProfileSearchRoot '<Mac上profile搜索目录>' `
  -NoFail
```

只有 native 与 runner signing report 都 ready，且 unblock plan 显示 ready，才允许进入签名、安装、启动、runtime probe。

## 9. Mac 上推荐继续路径

优先路径：使用 Mac + Xcode 解决 Development signing。

1. 安装并打开 Xcode，登录 Apple ID。
2. 连接 iPhone，解锁屏幕并信任这台 Mac。
3. 用以下命令确认设备可见：

```bash
xcrun xctrace list devices
```

4. 确认输出中存在 UDID `00008030-0001598021E2802E`。如果不可见，不要继续签名或安装。
5. 在 Xcode 中配置 Team，并确保目标 bundle id 是：
   - `app.honey4212.crystal5671`
   - `app.honey4212.crystal5671.xctrunner`
6. 若使用 Personal Team 临时验证，要明确它只是临时 development signing 实验，通常有短期有效期；通过后仍不得把结果扩大解释为长期 Phase 2 完成。
7. Xcode/Apple 自动生成 profile 后，先执行上一节的 signing 只读复查命令。
8. 再执行签名、安装、`/status`、UI routes、Bonjour 或手动 endpoint 验证。

可以先本地构建 unsigned native host：

```bash
DERIVED_DATA_PATH=lobster_wda_host_ios \
SCHEME=LobsterWDAHost \
DESTINATION='generic/platform=iOS' \
ZIP_PKG_NAME=LobsterWDAHost.app.zip \
IPA_PKG_NAME=LobsterWDAHost.unsigned.ipa \
EXPECTED_BUNDLE_ID=app.honey4212.crystal5671 \
bash Scripts/ci/build-native-ios-host.sh
```

如果使用 PowerShell 脚本，Mac 上需要安装 PowerShell：

```bash
brew install --cask powershell
pwsh -Version
```

## 10. 真机 runtime 验证顺序

真机操作前提：

- 明确 UDID：`00008030-0001598021E2802E`
- 手机已连接、解锁、信任 Mac。
- 不自动选择设备。
- 不处理验证码、风控、异常登录、封禁或访问限制页面；遇到即停止并保存上下文。

推荐顺序：

1. 设备可见性检查。
2. signing 只读复查。
3. 签名 native host 和 runner。
4. 安装。
5. 启动或由 Xcode/XCTest 启动 WDA。
6. `/status` 健康检查。
7. `/screenshot` 与 `/source` UI route 检查。
8. Bonjour `_wda._tcp.` 或手动 endpoint 检查。
9. 只有 Phase 2 验证完成后，才考虑 Phase 3。

历史上 Windows 的 DVT/DeveloperImage 对 iOS 18.7.7 有限制；Mac + Xcode 应优先使用 Xcode 官方设备支持能力重新验证，不要复用 Windows 的 DeveloperImage 失败结论。

## 11. 已知失败模式摘要

关键失败模式已经沉淀在 `docs/phase2-pitfalls-and-lessons.md`。新 Mac 上重点先看这些结论：

- distribution profile 覆盖 bundle 和 UDID 也不够；`get-task-allow=false` 会阻断 WDA UI automation。
- USB `/status=200` 只能证明 native HTTP 服务运行，不证明 screenshot/source/tap/input 可用。
- `/screenshot` 或 `/source` 返回 “Not authorized for performing UI testing actions” 时，不得判定 Phase 2 完成。
- 手机 UI 显示 `running` 不等于 PC/Mac 能访问 8100；以实际 HTTP probe 为准。
- GitHub-hosted macOS 能构建 unsigned IPA，但不能替代 Apple Development signing 与真机 UI 授权。
- `-ValidateIpaOnly` 用于云端 unsigned IPA 验证，不应要求本地 Development profile。
- GitHub API 生成远端 commit 后，本地 HEAD mismatch 不一定是权限问题；若明确构建当前远端分支，可使用 `-SkipRemoteHeadCheck -AllowDirtyCloudBuild`，但只应用于 validate-only cloud build。

## 12. 新 Mac 恢复时的第一轮命令

在新 Mac Codex app 打开仓库后，先执行：

```bash
git status --short --branch
git log -1 --oneline
tail -n 120 docs/phase2-pitfalls-and-lessons.md
```

如果安装了 PowerShell，再执行只读 readiness：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./Scripts/check-phase2-readiness.ps1 `
  -DeviceUdid '00008030-0001598021E2802E' `
  -TargetRepo 'ds0515/0516_WDA' `
  -ProfileSearchRoot '<Mac上profile和签名材料搜索根目录>' `
  -NoFail
```

随后先声明：

- 当前仍处于 Phase 2。
- 假设：Mac/Xcode 用于补齐 Development signing 与真机 runtime 验证。
- 成功标准：`/status`、UI routes、Bonjour/endpoint 在 Development-signed 条件下通过。
- 验证方式：signing 只读复查、安装、WDA HTTP probe、失败 artifact。

## 13. 禁止事项

不要做以下事情：

- 不要把 `github.txt`、p12、mobileprovision、证书密码、Apple ID 密码放进仓库。
- 不要输出 token、密码、证书私钥或完整 profile 内容。
- 不要用 shared developer certificates、租赁企业证书、越狱、第三方账号托管 sideloading tricks 或任何 signing/entitlement/XCTest authorization bypass。
- 不要把 distribution-signed runtime 的 `/status=200` 当作 Phase 2 完成。
- 不要跳到 Phase 3。
- 不要在未明确 UDID 或 endpoint 的情况下操作真机。

## 14. 当前交接结论

GitHub 云端编译问题已经解决；当前真正阻塞是 Mac/Xcode 侧 Development signing 和真机 runtime acceptance。

新 Mac 的第一目标不是继续改 GitHub，而是：

1. 克隆 `ds0515/0516_WDA@lobster-wda-cloud-resign`。
2. 确认远端 commit 和本交接文档。
3. 用 Xcode 让目标 iPhone 可见。
4. 为 native host 与 runner 生成或导入 Apple Development signing materials。
5. 先跑 signing 只读复查。
6. 再进入安装和 WDA `/status`、`/screenshot`、`/source` 验证。
