# 新 Mac Codex 新对话启动提示词（2026-05-25）

把下面整段复制到新 Mac 的 Codex app 新对话中使用。

```text
使用 goal 执行以下任务。

目标：
在新 Mac 上继续推进 iOS/WDA 脱机自动化项目“主程序 + 代理程序 + WDA 控制链路”。当前不要从头开始，不要跳阶段；从 Phase 2：代理/WDA 最小闭环 的 Signing gate 继续。

第一步必须做 Skill 路由：
- 优先使用 mobile-rpa-workflow。
- 涉及代码变更时使用 tdd-workflow。
- 涉及失败、报错、真机链路异常时使用 debug-workflow。
- 涉及提交时使用 commit-workflow。

当前仓库：
- GitHub 仓库：https://github.com/ds0515/0516_WDA
- 分支：lobster-wda-cloud-resign
- 已验证云构建代码基线 commit：7440401e570cfc5acaaaffd7a17fc026232c4fe5
- 注意：交接文档可能使远端 HEAD 晚于 7440401e...，不要仅因 HEAD 更晚就误判源码不同步。

新 Mac 开始前先执行：
1. clone 或打开仓库：
   git clone https://github.com/ds0515/0516_WDA.git
   cd 0516_WDA
   git checkout lobster-wda-cloud-resign

2. 先读取以下文件，再继续：
   - docs/mac-codex-handoff-2026-05-25.md
   - docs/phase2-pitfalls-and-lessons.md
   - docs/offline-automation-v1.md

3. 每次恢复上下文后，先执行并报告：
   - git status --short --branch
   - git log -1 --oneline
   - tail -n 120 docs/phase2-pitfalls-and-lessons.md

当前阶段状态：
- Phase 0 已完成：环境复位与事实确认。
- Phase 1 已完成：需求与边界文档。
- Phase 2 进行中。
- GitHub 云端 unsigned IPA 构建已跑通。
- 当前真正阻塞是 Apple Development signing materials 和真机 runtime acceptance。
- 不得进入 Phase 3，直到 Phase 2 的 WDA /status、UI routes、Bonjour 或手动 endpoint 在可接受签名/运行条件下通过。

Phase 2 当前假设：
- GitHub 可以负责远端编译或托管源码。
- WDA 真机 UI 授权仍受 Apple Development 签名材料、UDID、entitlements 和设备运行时授权约束。
- Distribution-signed native host 可以用于复现已知阻塞，但不能作为 Phase 2 完成证据。
- 新 Mac + Xcode 是当前解决 Development signing 与真机 runtime 验证的主要路径。

Phase 2 成功标准：
- 代理侧能启动或维持 WDA HTTP 服务。
- /status 可作为健康检查。
- Bonjour _wda._tcp. 或手动 endpoint 至少一种可用。
- /screenshot 和 /source 不再返回 “Not authorized for performing UI testing actions”。
- 真机验证必须显式指定 UDID 或 WDA endpoint。

目标设备：
- iPhone 11
- UDID：00008030-0001598021E2802E
- 历史 iOS 版本：18.7.7
- 历史 Wi-Fi IP：192.168.0.128，但该 IP 可能变化，Mac 上必须重新确认。

目标 bundle id：
- native host：app.honey4212.crystal5671
- XCTest runner：app.honey4212.crystal5671.xctrunner

Windows 历史材料位置，仅用于理解迁移来源，不要在 Mac 仓库中保存密钥材料：
- 主程序 IPA：D:\2026_soft\0430_WS\0423_iPhone11\release.ipa
- 代理程序 IPA：D:\2026_soft\0430_WS\0423_iPhone11\agent-runner.ipa
- GitHub 凭据来源文件：D:\2026_soft\0430_WS\0423_iPhone11\github.txt
- Distribution profile：D:\2026_soft\0430_WS\0423_iPhone11\cert.mobileprovision
- p12：D:\2026_soft\0430_WS\0423_iPhone11\cert.p12

Mac 上如果需要放置材料，使用仓库外的私有目录，例如：
- ~/secure-wda-materials/

签名材料迁移规则：
- 不要把 cert.p12、任何 .p12、任何 .mobileprovision、p12 密码、Apple ID 密码或 github.txt 上传到 GitHub 仓库。
- 不要通过普通 Git commit、GitHub blob、release asset、issue/comment、wiki、gist 或 Actions artifact 存放这些材料。
- 当前新 Mac 迁移方式是：用户手动把签名材料放到仓库外的私有目录，例如 ~/secure-wda-materials/，Codex 只在明确需要签名或只读检查时引用路径。
- 如果后续明确要求“云端签名”，必须先单独做安全方案评审；只能讨论 GitHub Actions Encrypted Secrets 这类受控入口，不得把 p12/mobileprovision 当作仓库文件上传。

安全硬性约束：
- 默认中文回复。
- 不得存储、打印、提交 GitHub token、Apple ID 密码、p12 私钥内容、p12 密码、完整 mobileprovision 内容或敏感日志。
- github.txt 只允许在确实需要 GitHub API、Actions dispatch 或远端写入时读取；不得输出内容。
- 不把 p12、mobileprovision、密码文件、token 文件放入仓库。
- 不设计或实现 CAPTCHA、风控、封禁、访问控制、平台限制绕过。
- 出现验证码、风控、异常登录、限制、封禁等页面时，停止运行并保存上下文。
- 真机/高风险操作必须要求明确 UDID 或 WDA endpoint，不自动选择设备。
- 不 push、不提交，除非我明确要求。
- 仓库若有未提交改动，先报告并保护，不得回滚用户改动。

当前 Signing gate 要求：
- 需要 Apple Development provisioning profile：app.honey4212.crystal5671
- 需要 Apple Development provisioning profile：app.honey4212.crystal5671.xctrunner
- 两个 profile 都必须：
  - 包含 UDID 00008030-0001598021E2802E
  - get-task-allow=true
  - 未过期
  - 与用于签名的 Apple Development certificate/private key 属于同一 team
- 还需要匹配的 Apple Development certificate/private key 或可用 p12；p12 和密码不得进入仓库、日志或文档。

已有 distribution profile 的边界：
- 历史 cert.mobileprovision 覆盖 app.honey4212.crystal5671 且包含 UDID，但 get-task-allow=false。
- 它只能用于复现 distribution blocker，不能作为 WDA UI automation 或 Phase 2 完成证据。

新 Mac 推荐执行顺序：
1. 读取交接文档和坑点文档。
2. 报告 git 状态和当前阶段。
3. 安装/确认 Xcode。
4. 连接 iPhone，解锁并信任这台 Mac。
5. 用 xcrun xctrace list devices 确认 UDID 00008030-0001598021E2802E 可见。
6. 在 Xcode 中配置 Team，确保 native host 和 runner 的 bundle id 正确。
7. 生成或导入 Apple Development signing materials。
8. 先跑只读 signing 复查，不要直接安装。
9. signing ready 后，再签名、安装、启动 WDA。
10. 验证 /status、/screenshot、/source、Bonjour 或手动 endpoint。

只读 signing 复查命令模板：
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

如果只是重新跑 GitHub 云端 unsigned IPA 构建，只允许使用 validate-only 路径：
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

该 validate-only 命令不签名、不安装、不启动、不操作真机。GitHub 云端构建成功不能代表 Phase 2 完成。

每次阶段结束必须输出：
- 完成内容
- 验证结果
- 遗留风险
- 下一阶段入口

执行过程中实时维护 docs/phase2-pitfalls-and-lessons.md：
- 每遇到一个新坑、失败模式、修复经验、验证顺序或安全边界，都要追加可复用结论。
- 只记录事实、现象、原因、规避方式和验证命令。
- 不记录账号密码、证书内容、token、私钥、完整 mobileprovision 内容或敏感日志。

本次新 Mac 的第一目标：
不要改 GitHub，不要进入 Phase 3。先用 Mac/Xcode 解决 Development signing material 和目标 iPhone 可见性，然后只读复查 signing gate。
```
