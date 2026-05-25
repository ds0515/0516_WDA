# Phase 2 坑点与经验总结

更新时间：2026-05-15

适用范围：iOS/WDA 脱机自动化 Phase 2，也就是“代理侧能启动或维持 WDA HTTP 服务，并且安装后不用 USB 线也能访问健康检查或 WDA 能力”。

当前结论：Phase 2 还没有完成。现有证据只能证明 USB relay 下的部分 WDA 能力可用，不能证明脱机 Wi-Fi 自动化闭环可用。进入 Phase 3 之前，必须先拿到真实无 USB 的 `http://<iPhone-IP>:8100/status` 或 Bonjour 解析出的 endpoint 响应。

## 0. 当前目标输入变更

- 主程序 IPA 已切换为 `D:\2026_soft\0430_WS\0423_iPhone11\release.ipa`。
- 代理程序 IPA 已切换为 `D:\2026_soft\0430_WS\0423_iPhone11\agent-runner.ipa`。
- GitHub 凭据来源已切换为 `D:\2026_soft\0430_WS\0423_iPhone11\github.txt`。
- `github.txt` 只能在确实需要 GitHub 登录、鉴权、提交推送相关操作时读取；读取到的账号密码不得输出、写入日志、写入文档、提交到仓库或长期保存。
- 后续 Phase 0 的 IPA 只读检查必须基于 `release.ipa` 和 `agent-runner.ipa` 重新做，不能沿用旧 IPA 的 Info.plist、bundle id、PlugIns、Frameworks 或端口结论。

## 1. 阶段边界

- Phase 0/Phase 1 的重点是事实确认和边界文档，不能因为已有代码改动就默认 Phase 2 已完成。
- Phase 2 的最低可接受结果不是“能安装”或“USB relay 下 `/status` 返回 200”，而是代理/WDA 在手机端提供可访问的 HTTP 服务。
- Phase 3 的主程序到代理协议必须等 Phase 2 真实成立后再做，否则会把不可用的底层链路包装成更多不可验证的接口。

## 2. IPA 包形态经验

- EC 主程序是普通 native App，形态上更像控制端，不包含 XCTest/WDA runner 的关键结构。
- EC 代理程序是 XCTest runner 形态，包含 `PlugIns/*.xctest`、`WebDriverAgentLib.framework`、`iosauto.framework` 和 `FBWebServer` 等自动化关键组件。
- Appium WDA IPA 也是 XCTest runner 形态，runner bundle id 和测试 bundle id 分离。
- 结论：仅有 `.p12` 或能重签 IPA 不等于能获得 UI 自动化能力。包形态、entitlements、mobileprovision、XCTest runner 启动方式共同决定能不能执行截图、节点、点击等动作。
- Native App 可以承载 HTTP 服务，但不能自动获得 XCTest UI testing 授权。Native host 下 `/status` 可能正常，`/screenshot`、`/source` 仍可能因为未获授权而失败。

## 3. USB Relay 不等于脱机 Wi-Fi

- USB relay 能访问 `127.0.0.1:8100` 只说明电脑通过线缆转发到了手机端端口。
- 脱机目标要求同一 Wi-Fi 下访问 `http://<iPhone-IP>:8100`，这是另一条网络路径。
- 已出现过 USB relay 下 `/status`、`/screenshot`、`/source` 返回成功，但 Wi-Fi `http://192.168.0.128:8100/status` 超时的情况。
- 系统日志里出现过 Wi-Fi 响应方向被丢弃的迹象。Local Network 权限声明和 Info.plist 文案只能解决一类权限提示问题，不能证明当前签名和包形态已经允许外部网络访问 WDA。

## 4. `/status` 不等于自动化可用

- `/status` 只能作为健康检查入口，不能单独证明截图、节点树、点击、滑动、输入可用。
- Native host 里出现过 `/status` 200，但 `/screenshot` 或 `/source` 返回 UI testing 未授权错误的情况。
- Phase 2 验收至少要区分三层：
  - HTTP 服务是否活着：`/status`
  - WDA UI 能力是否可用：`/screenshot`、`/source`
  - 是否脱离 USB 可访问：Wi-Fi endpoint 或 Bonjour endpoint

## 5. Bonjour 只证明发现，不证明可用

- `_wda._tcp.` 能被发现或解析到 `iPhone-11.local.:8100`，只说明服务发布信息存在。
- 如果对解析出的 endpoint 请求 `/status` 仍然超时，Phase 2 仍然不成立。
- Bonjour 可作为 endpoint 发现方式，但最终验收仍要以 HTTP 请求真实返回为准。

## 6. Native Host 和两 App 代理模式的坑

- 单 App native host 的优势是安装和启动路径简单，但当前证据显示它可能卡在 XCTest UI 授权和 iOS 后台保活上。
- 两 App 模式更接近 EC：主程序负责 UI/发现/控制，代理 runner 负责 WDA/XCTest 能力。
- 两 App 模式也不能只看主程序 `/status`。必须确认代理 runner 已就绪，并且主程序代理出来的 `/proxy/status`、`/proxy/screenshot`、`/proxy/source` 不再返回 404 或超时。
- 之前安装过的 native host 产物已经证明可能是旧版本：`/wda/network` 和 `/proxy/*` 返回 404。遇到这种情况要先 rebuild、resign、reinstall 当前产物，再继续判断协议设计是否有效。

## 7. 签名和描述文件

- 描述文件覆盖 bundle id 和 UDID 只是必要条件，不是充分条件。
- 已检查到的描述文件形态偏发布分发，`get-task-allow=false`、生产推送环境等信号不适合作为最终 Phase 2 无线验收依据。
- Phase 2 最终建议使用 Apple Development profile，明确覆盖目标 bundle id 和真机 UDID。
- `-AllowNonDevelopmentProfile` 或类似开关只适合复现已知阻断，不适合作为通过标准。
- 任何脚本都不应打印、缓存或提交证书密码、p12 内容、mobileprovision 内容、账号密码。

## 8. 云端构建和 GitHub Actions

- GitHub-hosted runner 账户级计费限制不会因为删除旧 workflow 或旧 artifact 立即解除。
- 删除旧仓库只能减少干扰，不能恢复已经用掉的 hosted minutes，也不能替代账户计费状态修复。
- 当前更稳的方向是 self-hosted macOS runner，标签必须匹配 `self-hosted`、`macOS`、`X64`、`wda-macos-self-hosted`。
- 云端构建前要先做只读 preflight：确认 workflow active、远端分支包含 native_host workflow 更新、没有不期望的 push trigger、runner 在线。
- 远端 workflow 还没更新时，不要 dispatch。否则失败日志只会证明旧 workflow 不支持当前包类型。

## 9. Git/GitHub 推送环境

- 浏览器已经登录 GitHub，不代表 git CLI 已经具备 push 凭据。
- 当前目标要求 GitHub 账号密码从 `D:\2026_soft\0430_WS\0423_iPhone11\github.txt` 读取；这只解决凭据来源问题，不自动解决 Git Credential Manager、HTTPS、SSH key、2FA、验证码或浏览器登录态问题。
- 读取 `github.txt` 前必须先确认操作确实需要凭据；读取后只能在当前鉴权流程中使用，不允许打印、落盘、写入脚本、写入日志或加入提交。
- 之前遇到过本地 `.git` ACL 限制造成 `index.lock` 或 config lock 失败。这类问题要先识别为本地权限问题，不要误判为代码问题。
- 临时外部 Git database 可以绕过原 `.git` 写入限制完成本地提交，但不能解决 HTTPS、GCM、PAT 或 SSH 凭据问题。
- 推送失败时要分清层次：
  - Git 本地数据库是否可写
  - HTTPS/TLS 凭据是否可用
  - GitHub CLI 是否安装并登录
  - SSH key 是否存在并被 GitHub 接受
- 不要把 GitHub 账号密码、邮箱验证码、PAT、SSH 私钥写入仓库、日志或命令文件。

## 10. 推荐验证顺序

1. 只读确认当前阶段、分支、dirty worktree 和最近提交。
2. 只读确认 `release.ipa`、`agent-runner.ipa`、`github.txt` 存在；不要读取或输出 `github.txt` 内容。
3. 只读检查 IPA 形态、Info.plist、PlugIns、Frameworks、entitlements 和 mobileprovision 覆盖范围。
4. 构建 unsigned IPA，只检查产物结构，不签名、不安装。
5. 使用本地证书重签，检查 bundle id、embedded.mobileprovision、entitlements 是否匹配。
6. 明确 UDID 后安装到真机。
7. USB relay 验证 `/status`、`/screenshot`、`/source`。
8. 拔线或至少不用 relay，验证 Wi-Fi `http://<iPhone-IP>:8100/status`。
9. 如果 Bonjour 可用，再验证解析出的 `_wda._tcp.` endpoint。
10. 只有无 USB endpoint 可用后，才进入主程序到代理协议设计。

## 11. 不再重复踩的红线

- 不自动选择多台设备，真机操作必须显式指定 UDID。
- 不把 `/status` 200 当作 WDA 全能力可用。
- 不把 USB relay 成功当作脱机成功。
- 不把 Bonjour 发现当作 endpoint 可用。
- 不把旧安装包的 404 当作当前代码的结论，先确认设备上安装的是最新产物。
- 不在 GitHub-hosted runner 被账户限制时继续反复 dispatch。
- 不在不需要鉴权的只读阶段读取 `github.txt`。
- 不把证书、描述文件、账号密码、令牌、日志 artifact 混进提交。
- 不设计验证码、风控、封禁、访问控制或平台限制绕过逻辑。

## 12. 经验实时沉淀规则

- 每次执行目标时，如果遇到新的阻断、失败模式、验证误区或有效处理方式，都要追加到本文档。
- 记录格式固定为：坑点、触发条件、现象、根因、处理、验证、下次动作。
- 根因必须来自日志、命令输出、代码或真机现象；不能确认时写“未定”，不要编造。
- 经验条目要能直接帮助后续自动化流程调整检查顺序、减少重复 dispatch、减少重复签名安装、减少无效真机操作。
- 经验文档只记录可复用结论和脱敏证据，不记录账号、密码、token、私钥、证书内容、完整描述文件内容或未脱敏日志。

## 13. 新坑：静态 smoke 断言滞后于目标输入

- 坑点：Phase 0 将当前输入切换为 `release.ipa` 和 `agent-runner.ipa` 后，静态 smoke 测试仍断言旧样例名 `WS 龙虾.ipa`、`WS 智能体.ipa`、`WebDriverAgent.ipa`。
- 触发条件、现象、影响范围：运行 `node test/native-wda-host-smoke.mjs` 时，断言 `docs/offline-automation-v1.md` 必须包含旧 IPA 名称，导致 Phase 2 静态 smoke 在文档事实已更新后失败。影响范围限于静态验证，不涉及真机、签名、GitHub 凭据或 WDA runtime。
- 根因：`test/native-wda-host-smoke.mjs` 的文档断言没有随当前目标输入变更同步更新，仍检查旧阶段的参考 IPA 名称。
- 处理：将 smoke 断言改为检查当前活动输入和关键事实：`release.ipa`、`agent-runner.ipa`、`com.ws.max`、`com.ieasyclick.auto.ios.xxx888x2288876289.xctrunner`、`agent_port.txt` 为 `19999`。
- 验证：先运行 `node test/native-wda-host-smoke.mjs` 复现失败，再修改断言并重新运行同一命令；相邻 Phase 2 PowerShell 测试继续使用 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`.\test\phase2-runtime-probe-tests.ps1`、`.\test\wda-bonjour-probe-tests.ps1`。
- 下次动作：每次 Phase 0 输入 IPA 变化后，优先同步 `docs/offline-automation-v1.md` 和静态 smoke 中的 IPA 名称、bundle id、端口文件断言，避免测试继续验证过期样例。

## 14. 新坑：源码目录不能当作可安装产物

- 坑点：`D:\2026_soft\0511_Appium_WDA_public_build` 名称像 public build，但实际是源码目录，不包含 `LobsterWDAHost` IPA 或 artifact ZIP。
- 触发条件、现象、影响范围：Phase 2 缺可安装 native-host 产物时，扩大搜索到 `D:\2026_soft`；只找到当前仓库 `artifacts` 下的旧 IPA/ZIP，`report-native-host-artifacts.ps1 -SearchRoot D:\2026_soft\0511_Appium_WDA_public_build -ExpectedBundleId app.honey4212.crystal5671 -AsJson -NoFail` 返回 `CandidateCount=0`、`HasReadyCandidate=false`。影响范围限于产物选择和下一步实验入口，不涉及真机操作。
- 根因：基于文件枚举和产物报告，`0511_Appium_WDA_public_build` 只有源码文件和 workflow/script/test，不含可安装 IPA/ZIP。
- 处理：不要从该目录进入签名或安装；继续把 Phase 2 卡在产物生成/下载步骤。
- 验证：`Get-ChildItem -LiteralPath 'D:\2026_soft\0511_Appium_WDA_public_build' -Recurse -File -Include *.ipa,*.zip` 未发现可用产物；产物报告返回 `CandidateCount=0`。
- 下次动作：寻找 native-host 产物时先跑 `report-native-host-artifacts.ps1`，不要凭目录名判断“public_build”就是可安装产物。

## 15. 新坑：Windows 本机不能直接构建 iOS native-host IPA

- 坑点：`Scripts/ci/build-native-ios-host.sh` 是 macOS/Xcode 构建脚本，不是 Windows 本地构建脚本。
- 触发条件、现象、影响范围：Phase 2 缺当前 native-host IPA 时检查本机工具链；Windows 11 下 `xcodebuild`、`xcrun` 不存在，`/usr/libexec/PlistBuddy` 不存在，`bash -lc` 通过 WSL 入口失败并报告 `/bin/bash` 不存在。影响范围是产物生成路径，不涉及签名、安装、真机控制或 GitHub 凭据。
- 根因：构建脚本依赖 `xcodebuild clean build`、iphoneos SDK、macOS PlistBuddy、`zip`、`unzip`、`python3`；当前 Windows 主机不具备这些 macOS/iOS 构建依赖。
- 处理：不要在 Windows 本机反复尝试执行 native-host 构建脚本；应使用 macOS/Xcode 环境，优先是已规划的 self-hosted macOS runner，或提供外部已构建的当前 `LobsterWDAHost.unsigned.ipa`。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-native-host-build-toolchain.ps1 -AsJson -NoFail` 返回 `ReadyForLocalNativeHostBuild=false`、缺少 `xcodebuild`/`xcrun`/`zip`/`unzip`、`PlistBuddyFound=false`、`BashProbeSucceeded=false`；手工复核时 `Get-Command xcodebuild` 和 `Get-Command xcrun` 无输出。
- 下次动作：Phase 2 产物生成前先运行 `report-native-host-build-toolchain.ps1`；Windows 只用于只读检查、签名前验证、文档、下载 artifact 和后续明确 endpoint 验证，不作为 iOS app 编译环境。

## 16. 新坑：真机已卸载 IPA 后旧 runtime 证据只能当历史证据

- 坑点：用户确认 iPhone 上的 IPA 已卸载后，之前依赖已安装 app 的 `/status`、`/proxy/*`、Bonjour 和 runtime 报告不能再代表当前设备状态。
- 触发条件、现象、影响范围：Phase 2 继续验证前收到“iPhone 上的 IPA 已经卸载”的设备状态更新。影响范围是真机 runtime 和 Bonjour 证据；静态 smoke、产物报告和文档检查仍然有效。
- 根因：已安装 app 是 runtime 探测的前置条件；卸载后，历史日志只能解释过去的失败模式，不能证明当前设备上任何 endpoint 存在或可用。
- 处理：把现有 runtime/Bonjour 报告标记为历史证据；后续真机验证必须先明确 UDID 或 endpoint，安装当前通过产物检查的 IPA，再重新生成 runtime/Bonjour 报告。
- 验证：用户人工确认设备已卸载 IPA；未执行自动安装、启动、relay 或 endpoint 请求。
- 下次动作：任何 live Phase 2 probe 前先确认安装状态；如果未安装，先停止在“产物生成/签名/安装准备”阶段，不要复用旧 endpoint 结论。

## 17. 新坑：本机构建工具链报告没有接入 combined readiness 时容易重复走错入口

- 坑点：`report-native-host-build-toolchain.ps1` 可以单独证明 Windows 本机不能构建 iOS native-host IPA，但如果 `check-phase2-readiness.ps1` 不汇总它，续跑时仍可能把“本机构建”当作可尝试入口。
- 触发条件、现象、影响范围：补充 Phase 2 readiness TDD 时，`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 先失败，错误为 `Phase 2 readiness should include the local native-host build toolchain diagnostic report.` 影响范围是 Phase 2 preflight 汇总和下一步选择，不涉及真机、签名、安装或 GitHub 凭据。
- 根因：combined readiness 只汇总 cloud、签名、设备、runtime、Bonjour、repo safety 和 artifact 报告，缺少 `ToolchainReport` 参数、脚本调用和输出字段。
- 处理：`check-phase2-readiness.ps1` 调用 `report-native-host-build-toolchain.ps1 -AsJson -NoFail`，在报告中透出 `ReadyForLocalNativeHostBuild`、`MissingToolchainCommands`、`PlistBuddyFound`、`BashProbeSucceeded`、本机构建 blockers 和 next actions；这些字段只标记本机构建路径，不污染 Phase 2 主 gate blockers，也不阻断 cloud/self-hosted 或外部 artifact 路径。
- 验证：先运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 复现 RED，再实现后同一命令通过；相邻验证 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\native-host-build-toolchain-report-tests.ps1` 和 `node test/native-wda-host-smoke.mjs` 通过；`git diff --check -- Scripts/check-phase2-readiness.ps1 test/phase2-readiness-tests.ps1` 无输出。
- 下次动作：Phase 2 恢复后先看 combined readiness 里的 `ReadyForLocalNativeHostBuild`。如果为 `false`，不要在 Windows 上重复尝试构建；继续使用 self-hosted macOS runner、外部当前 artifact，或只做文档/只读验证。

## 18. 新坑：installed-state 没有接入 combined readiness 时会误用旧设备状态

- 坑点：`report-ios-installed-wda-apps.ps1` 可以单独证明目标 bundle 是否安装，但如果 `check-phase2-readiness.ps1` 不汇总它，用户已卸载 IPA 后，续跑流程仍可能从旧 runtime 或旧 installed-app 文档继续。
- 触发条件、现象、影响范围：补充 Phase 2 readiness TDD 时，`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 先失败，错误为 `Phase 2 readiness should include the installed WDA app state report.` 影响范围是 Phase 2 runtime 前置判断和下一步入口，不涉及自动安装、启动、relay、WDA 请求或 GitHub 凭据。
- 根因：combined readiness 只汇总 cloud、签名、设备、runtime、Bonjour、repo safety、artifact 和本机构建工具链报告，缺少 `InstalledAppsReport` 参数、脚本调用、输出字段和 `InstalledApps` gate。
- 处理：`check-phase2-readiness.ps1` 调用 `report-ios-installed-wda-apps.ps1 -DeviceUdid <explicit-udid> -BundleId <bundle-id> -RunnerBundleId <runner-bundle-id> -AsJson -NoFail`，透出 `InstalledAppsReady`、`NativeHostInstalled`、`RunnerInstalled`、`AnyTargetInstalled`；当 cloud、artifact、signing、device 已满足但目标 app 未安装时，`NextRequiredGate=InstalledApps`，下一步是安装当前通过产物检查的签名 IPA，而不是复用旧 runtime。
- 验证：先运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 复现 RED，再实现后同一命令通过；相邻验证 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-installed-wda-apps-report-tests.ps1`、`.\test\phase2-runtime-probe-tests.ps1`、`.\test\wda-bonjour-probe-tests.ps1` 和 `node test/native-wda-host-smoke.mjs` 通过。
- 下次动作：任何 runtime、Bonjour endpoint 或 proxy probe 前，先看 combined readiness 的 `InstalledAppsReady`。如果为 `false`，停止在安装准备阶段；必须先明确 UDID，安装当前已通过 artifact 检查的 IPA，再重新生成 installed-app、runtime 和 Bonjour 证据。

## 19. 新坑：缺少 installed-state 报告不能默认视为已安装

- 坑点：即使 combined readiness 已支持 `InstalledAppsReport`，函数层如果把缺失报告默认为通过，直接调用 `New-Phase2ReadinessReport` 的测试或后续脚本仍可能绕过安装状态检查。
- 触发条件、现象、影响范围：新增缺报告用例后，`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 失败，提示 `Wireless validation should block when the installed WDA app state report is missing. Expected 'False', got 'True'.` 影响范围是 readiness 函数的安全默认值，不涉及真机操作或 GitHub 凭据。
- 根因：`InstalledAppsReport` 为 `$null` 时，`installedAppsGateReady` 初始值仍为通过，导致 cloud、artifact、signing、device、runtime、Bonjour 都 ready 的 mock 场景可以错误得到 `ReadyForPhase2WirelessValidation=true`。
- 处理：将缺少 installed-state 报告视为证据不足：加入 `Installed apps: Installed WDA app state report was not provided.` blocker，`NextRequiredGate=InstalledApps`，下一步为运行 `report-ios-installed-wda-apps.ps1` 并重新执行 Phase 2 readiness。
- 验证：先复现上述 RED，再实现后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。
- 下次动作：新增任何 readiness 汇总报告时，缺报告默认值要按“证据不足”处理；只有明确的报告字段能放行对应门槛，不能用 `$null` 代表通过。

## 20. 新坑：`-Install` 后不核验 bundle 会把安装成功误当作当前设备可测

- 坑点：`resign-native-wda.ps1 -Install` 过去只检查 `tidevice install` 的退出码，没有确认目标 iPhone 上能列出 native host bundle。用户确认 iPhone 上 IPA 已卸载后，这会让后续 runtime/Bonjour probe 容易复用错误的“已安装”假设。
- 触发条件、现象、影响范围：新增 `test/resign-native-wda-script-tests.ps1` 用例后，先因为 fake `zsign.cmd` 没有生成输出 IPA 得到无效 RED；修正 fake 批处理后，同一测试稳定失败在 `Install flow should verify the native host bundle with the installed-app report after tidevice install.` 影响范围是 Phase 2 签名安装脚本和后续真机 probe 前置门禁，不涉及自动选择设备或访问业务 App。
- 根因：生产脚本在 `tidevice install` 后没有调用 `report-ios-installed-wda-apps.ps1`；测试替身里的批处理还曾在 `if (...)` 块中 `shift` 后读取 `%~1`，导致 `%~1` 解析时机错误，fake 输出文件没有按预期创建。
- 处理：给 `resign-native-wda.ps1` 增加 `InstalledAppsReportScriptPath`，在 `tidevice install` 成功后运行 installed-app report，并要求 `NativeHostInstalled=true`；测试 fake `zsign.cmd` 改为不用 parenthesized `shift` 块读取输出路径。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\resign-native-wda-script-tests.ps1` 先 RED 后 GREEN；相邻验证 `phase2-readiness-tests.ps1`、`ios-installed-wda-apps-report-tests.ps1`、`native-host-artifact-report-tests.ps1` 和 `node test/native-wda-host-smoke.mjs` 均通过。
- 下次动作：任何执行安装的脚本都必须在 install 退出码之后再做 installed-state report；批处理测试替身解析参数时避免在同一个 parenthesized block 中 `shift` 后读取 `%~1`。

## 21. 新坑：device report 和 installed-state report 的 UDID 不一致会误放行别的手机证据

- 坑点：`check-phase2-readiness.ps1` 过去只看 installed-app report 里的 `AnyTargetInstalled=true`，没有确认这份安装态报告和 device readiness report 指向同一个 UDID。
- 触发条件、现象、影响范围：新增 mock 用例后，`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 失败，提示 `Wireless validation should block when installed-state evidence belongs to a different UDID. Expected 'False', got 'True'.` 影响范围是 Phase 2 readiness 合成门禁；不涉及真机安装、启动、HTTP 请求或 GitHub 凭据。
- 根因：`New-Phase2ReadinessReport` 读取了 `InstalledAppsReport.DeviceUdid`，但没有读取并对比 `DeviceReport.DeviceUdid`；当两个报告分别为 ready 时，不一致的 UDID 仍可得到 `ReadyForPhase2WirelessValidation=true`。
- 处理：在 readiness 合成逻辑中读取 device report 的 `DeviceUdid`，当 installed-app report 的 `DeviceUdid` 非同一值时，将 installed-app gate 置为 false，加入 `Installed apps: Installed-app report target UDID ... does not match device readiness target UDID ...` blocker，并提示用 device readiness 的显式 UDID 重跑 installed-app report。
- 验证：先运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 复现 RED；实现后同一命令通过，相邻验证 `ios-installed-wda-apps-report-tests.ps1`、`ios-device-readiness-report-tests.ps1`、`phase2-runtime-probe-tests.ps1` 和 `wda-bonjour-probe-tests.ps1` 通过。
- 下次动作：任何跨报告合成的 Phase 2 证据都要检查目标身份一致性；尤其是 device、installed-state、runtime 和 Bonjour 报告不能只看各自 ready 字段，要确认它们描述的是同一个显式目标。

## 22. 新坑：runtime report 的 UDID 不一致会把旧 endpoint 证据误当作当前闭环

- 坑点：`check-phase2-readiness.ps1` 过去读取 runtime report 的 `Phase2RuntimeReady`、`WirelessReady` 或 `ProxyWirelessReady`，但没有确认 runtime report 的 `DeviceUdid` 和 device readiness report 的 `DeviceUdid` 一致。
- 触发条件、现象、影响范围：新增 mock 用例后，`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 失败，提示 `Phase 2 completion should block when runtime evidence belongs to a different UDID. Expected 'False', got 'True'.` 影响范围是 Phase 2 completion 证据合成；不涉及真机安装、启动、HTTP 请求或 GitHub 凭据。
- 根因：runtime probe 报告本身已经写入 `DeviceUdid`，但 `New-Phase2ReadinessReport` 没有读取并对比 `DeviceReport.DeviceUdid`；当 runtime 报告来自其他设备且 ready 字段为 true 时，Phase 2 completion 可被误判通过。
- 处理：在 readiness 合成逻辑中读取 `RuntimeReport.DeviceUdid`，如果它和 device readiness 目标 UDID 不一致，则将 runtime gate 置为 false，加入 `Runtime: Runtime report target UDID ... does not match device readiness target UDID ...` blocker，并提示用当前显式 UDID 重跑 `probe-phase2-runtime.ps1`。
- 验证：先运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 复现 RED；实现后同一命令通过，相邻验证 `phase2-runtime-probe-tests.ps1`、`wda-bonjour-probe-tests.ps1`、`ios-device-readiness-report-tests.ps1`、`ios-installed-wda-apps-report-tests.ps1` 和 `node test/native-wda-host-smoke.mjs` 通过。
- 下次动作：任何 runtime/endpoint 证据进入 readiness 前，先检查它是否带目标身份；带 `DeviceUdid` 的报告必须和当前 device readiness 的显式 UDID 一致，否则只能作为历史诊断，不能作为当前 Phase 2 completion 证据。

## 23. 新坑：runtime report 缺少 DeviceUdid 会误放行无法归属的 endpoint 证据

- 坑点：runtime report 的 ready 字段为 true，但报告没有 `DeviceUdid` 时，combined readiness 过去无法确认这份 endpoint 证据属于当前显式目标 iPhone。
- 触发条件、现象、影响范围：新增 mock 用例后，`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 失败，提示 `Phase 2 completion should block when runtime evidence has no DeviceUdid. Expected 'False', got 'True'.` 影响范围是 Phase 2 completion 证据合成；不涉及真机安装、启动、HTTP 请求或 GitHub 凭据。
- 根因：`New-Phase2ReadinessReport` 只在 runtime report 带有非空 `DeviceUdid` 且与 device readiness 目标 UDID 不一致时阻断；缺少 `DeviceUdid` 的 ready runtime report 会绕过身份校验。
- 处理：当 device readiness report 有显式 `DeviceUdid`，且 runtime report 自身 ready，但 runtime report 缺少 `DeviceUdid` 时，将 runtime gate 置为 false，加入 `Runtime: Runtime report does not include DeviceUdid...` blocker，并提示使用显式目标 UDID 重跑 `probe-phase2-runtime.ps1`。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`。
- 下次动作：runtime/endpoint 证据必须先证明“来自当前显式目标设备”，再用于 Phase 2 completion；缺 `DeviceUdid` 的历史或旧格式报告只能用于诊断，不能作为验收证据。

## 24. 新坑：Bonjour endpoint 证据缺少或不匹配 DeviceUdid 会误当作当前 no-USB 闭环

- 坑点：Bonjour report 的 `EndpointReady=true` 只能证明某个解析出的 `_wda._tcp` endpoint 对 `/status` 返回 ready，不能天然证明它属于当前 device readiness 的显式目标 UDID。
- 触发条件、现象、影响范围：新增 mock 用例后，`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 失败，提示 `Phase 2 completion should block when Bonjour endpoint evidence has no DeviceUdid. Expected 'False', got 'True'.` 影响范围是 Phase 2 no-USB endpoint 证据合成；不涉及真机安装、启动、HTTP 请求或 GitHub 凭据。
- 根因：`New-Phase2ReadinessReport` 过去将 `$wirelessEndpointReady` 计算为 runtime Wi-Fi ready 或 Bonjour endpoint ready 任一为 true，没有读取 `BonjourReport.DeviceUdid` 并与 `DeviceReport.DeviceUdid` 对比。
- 处理：`probe-wda-bonjour.ps1` 增加 `-DeviceUdid` 并写入 report；readiness 只在 Bonjour report 带同一 `DeviceUdid` 时接受 `EndpointReady=true`，否则加入 `Bonjour: Bonjour report does not include DeviceUdid...` 或 `Bonjour: Bonjour report target UDID ... does not match...` blocker。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\wda-bonjour-probe-tests.ps1`。
- 下次动作：任何 Bonjour endpoint 证据进入 Phase 2 completion 前，都必须用显式 UDID 重新生成报告；缺 UDID 或 UDID 不一致的 Bonjour 报告只能作为发现层诊断，不能作为当前 no-USB endpoint 验收证据。

## 25. 新坑：device readiness 缺少 DeviceUdid 会让所有下游证据失去身份锚点

- 坑点：device readiness report 的 `DeviceReady=true` 只能说明某个检查通过；如果报告没有 `DeviceUdid`，installed-state、runtime 和 Bonjour 报告就没有可对齐的显式目标身份。
- 触发条件、现象、影响范围：新增 mock 用例后，`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 失败，提示 `Wireless validation should block when device readiness evidence has no DeviceUdid. Expected 'False', got 'True'.` 影响范围是 Phase 2 readiness 合成；不涉及真机安装、启动、HTTP 请求或 GitHub 凭据。
- 根因：`New-Phase2ReadinessReport` 过去在 `DeviceReport.DeviceReady=true` 时直接放行 device gate；只有 `DeviceReport.DeviceUdid` 非空时才执行 installed-state、runtime、Bonjour 的同机身份校验。
- 处理：当 device readiness report 自身 ready 但缺少 `DeviceUdid` 时，将 device gate 置为 false，加入 `Device: Device readiness report does not include DeviceUdid...` blocker，并提示使用显式目标 UDID 重跑 `report-ios-device-readiness.ps1`。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`。
- 下次动作：Phase 2 的第一份设备报告必须带显式 `DeviceUdid`；缺少该字段时，不接受任何 installed-state、runtime、Bonjour 或 endpoint 证据。

## 26. 新坑：installed-state 缺少 DeviceUdid 会把旧格式报告误判为普通设备不匹配

- 坑点：installed-state report 的 `AnyTargetInstalled=true` 只能说明报告看到了目标 bundle；如果报告没有 `DeviceUdid`，它不能证明目标 app 安装在当前 device readiness 的显式目标设备上。
- 触发条件、现象、影响范围：新增 mock 用例后，`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 失败，提示 `Missing installed-state UDID should produce a clear installed-app blocker.` 影响范围是 Phase 2 installed-state 证据合成；不涉及真机安装、启动、HTTP 请求或 GitHub 凭据。
- 根因：`New-Phase2ReadinessReport` 过去只用 `installedAppsDeviceUdid -ne deviceReportUdid` 兜底，缺少 `DeviceUdid` 的 installed-state report 会被表达成空 UDID mismatch，而不是明确的旧格式/缺身份报告。
- 处理：当 installed-state report 自身 ready 但缺少 `DeviceUdid` 时，将 installed-app gate 置为 false，加入 `Installed apps: Installed-app report does not include DeviceUdid...` blocker，并提示使用 device readiness 的显式 UDID 重跑 `report-ios-installed-wda-apps.ps1`。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`。
- 下次动作：installed-state 证据必须先有 `DeviceUdid` 且与 device readiness 一致，再允许 runtime、Bonjour 或 no-USB endpoint 证据参与 Phase 2 completion。

## 27. 新坑：Bonjour `-ProbeStatus` 缺少 DeviceUdid 会探测无法归属的网络 endpoint

- 坑点：`probe-wda-bonjour.ps1 -ProbeStatus` 会对解析出的 `_wda._tcp.` endpoint 发起 `/status` HTTP 请求；如果没有显式 `DeviceUdid`，脚本可能探测局域网里任意可见的 WDA 服务，生成无法归属到当前 iPhone 的 endpoint 证据。
- 触发条件、现象、影响范围：新增 `test\wda-bonjour-probe-tests.ps1` 用例后，测试先失败在 `Test-BonjourProbeStatusTargetAllowed` 函数不存在。影响范围是 Bonjour 状态探测入口和 Phase 2 endpoint 证据身份边界；不涉及真机安装、启动、业务 App 操作或 GitHub 凭据。
- 根因：脚本虽然已把 `DeviceUdid` 写入 Bonjour report，但主流程没有在 `-ProbeStatus` 发起 browse/resolve/status 前要求显式目标 UDID。
- 处理：新增 `Test-BonjourProbeStatusTargetAllowed`，当 `-ProbeStatus` 且 `DeviceUdid` 为空时提前生成阻断报告，写入 `DeviceUdid is required when -ProbeStatus is used...`，并停止在 HTTP 探测之前；只做发现/解析的 Bonjour 诊断仍可不带 UDID 运行，但不能作为 Phase 2 completion 证据。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\wda-bonjour-probe-tests.ps1`。
- 下次动作：任何会发起 HTTP endpoint 请求的 Bonjour probe 都必须先指定目标 UDID；如果只是 discovery-only 诊断，报告仍需在进入 readiness 前用同一显式 UDID 重新生成。

## 28. 新坑：CLI smoke 输出目录不要默认假设 `C:\tmp` 可写

- 坑点：运行一次无 UDID 的 Bonjour CLI smoke 时，`-OutputDirectory 'C:\tmp\wda-bonjour-untargeted-probe-test'` 在创建目录阶段返回 `UnauthorizedAccessException`，导致未进入脚本目标逻辑。
- 触发条件、现象、影响范围：执行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\probe-wda-bonjour.ps1 -ProbeStatus -AsJson -NoFail -OutputDirectory 'C:\tmp\wda-bonjour-untargeted-probe-test'` 时失败，错误为 `Access to the path ... is denied`。影响范围是本机 smoke 输出路径选择，不涉及真机、WDA endpoint、GitHub 凭据或脚本业务逻辑。
- 根因：未定；`C:\tmp` 目录存在，但当前执行环境对该子目录创建操作返回拒绝访问。
- 处理：改用仓库内已被 `.gitignore` 忽略的 `logs\bonjour-untargeted-probe-test` 作为临时输出目录，避免污染 git 状态并能完成 CLI 验证。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\probe-wda-bonjour.ps1 -ProbeStatus -AsJson -NoFail -OutputDirectory '.\logs\bonjour-untargeted-probe-test'` 返回 JSON 报告，`StatusProbeAttempted=false`，并包含缺少 `DeviceUdid` 的 blocker。
- 下次动作：Phase 2 本地 CLI smoke 优先使用仓库内已忽略的 `logs\...` 路径；如果必须使用外部临时目录，先用最小 `New-Item` 检查写权限。

## 29. 新坑：live runtime probe 不能默认使用历史 UDID

- 坑点：`probe-phase2-runtime.ps1` 会启动 native host、创建 `tidevice relay`，并发起 USB/Wi-Fi WDA HTTP 请求；如果脚本参数默认填入历史 UDID，后续恢复运行时可能在调用方没有明确目标设备的情况下触发真机操作。
- 触发条件、现象、影响范围：新增 `test\phase2-runtime-probe-tests.ps1` 静态断言后，测试先失败，提示 `Runtime probe should not default to a historical UDID; live checks must require an explicit target device.` 影响范围是 Phase 2 live runtime probe 的设备身份边界；不涉及安装、卸载、业务 App 操作或 GitHub 凭据。
- 根因：脚本已有 `if ([string]::IsNullOrWhiteSpace($DeviceUdid)) { throw ... }` 前置保护，但参数默认值是历史测试 UDID，导致保护不会在省略 `-DeviceUdid` 时触发。
- 处理：将 `probe-phase2-runtime.ps1` 的 `DeviceUdid` 默认值改为空字符串，保留缺 UDID 即抛错的前置保护；文档明确该脚本没有默认 UDID，省略 `-DeviceUdid` 会在 launch、relay 或 HTTP probe 前停止。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-runtime-probe-tests.ps1`。
- 下次动作：任何会启动 app、创建 relay、安装、卸载或请求 WDA endpoint 的 Phase 2 脚本，都必须让调用方显式传入 UDID 或 endpoint；历史 UDID 只能留在示例、mock 和旧证据说明中。

## 30. 新坑：PowerShell 中 `rg` 正则含双引号时要避免外层双引号

- 坑点：在 PowerShell 里用外层双引号包住包含 `\"` 的 `rg` 正则，可能触发 `The string is missing the terminator: ".`，导致搜索命令还没执行就被 PowerShell 解析失败。
- 触发条件、现象、影响范围：执行 `rg -n "00008030-0001598021E2802E|DeviceUdid\s*=\s*\"" ...` 时 PowerShell 报字符串终止符缺失。影响范围是本地只读搜索命令，不涉及代码逻辑、真机、WDA endpoint 或凭据。
- 根因：PowerShell 的字符串解析先于 `rg` 执行；反斜杠不是 PowerShell 双引号字符串里的可靠引号转义方式。
- 处理：改用外层单引号或拆成更简单的搜索命令，例如 `rg -n '00008030' Scripts test docs/offline-automation-v1.md docs/phase2-pitfalls-and-lessons.md`。
- 验证：单引号或简化后的 `rg` 命令能正常返回命中行。
- 下次动作：在 PowerShell 中搜索包含双引号、反斜杠或正则转义的模式时，优先使用单引号；复杂模式失败时先简化搜索，不把解析错误误判为仓库无命中。

## 31. 新坑：签名安装脚本不能默认使用历史 UDID

- 坑点：`resign-native-wda.ps1` 的 `-Install` 路径会调用 `tidevice -u <UDID> install`，签名前也会用 UDID 校验 mobileprovision 是否覆盖目标设备；如果参数默认填入历史 UDID，调用方省略 `-DeviceUdid` 时仍可能继续签名准备或安装到旧目标。
- 触发条件、现象、影响范围：新增 `test\resign-native-wda-script-tests.ps1` 静态断言后，测试先失败，提示 `Signing/install script should not default to a historical UDID...`。影响范围是 Phase 2 签名验证和安装入口的设备身份边界；不涉及真机运行 probe、业务 App 操作或 GitHub 凭据。
- 根因：脚本已有 `-Install` 时缺 UDID 的保护，但参数默认值是历史测试 UDID；同时签名前 profile 校验也依赖该 UDID，默认值会让“未显式确认目标设备”的流程继续向后执行。
- 处理：将 `resign-native-wda.ps1` 的 `DeviceUdid` 默认值改为空字符串，并在脚本开头要求显式 UDID；缺少目标时在密码读取、签名、安装前停止。测试里的有效签名和安装路径全部显式传入测试 UDID，并新增缺 UDID 早停断言。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\resign-native-wda-script-tests.ps1`。
- 下次动作：任何 Phase 2 签名、安装、启动、relay 或 endpoint 探测入口都不能把历史 UDID 作为参数默认值；测试数据可以使用固定 UDID，但生产脚本必须由调用方显式传入。

## 32. 新坑：长流程编排入口不能默认使用历史 UDID

- 坑点：`continue-native-wda-goal.ps1` 会串联云端 artifact、签名、安装、启动、runner/proxy probe 等步骤；如果入口参数默认历史 UDID，调用方省略 `-DeviceUdid` 时会绕过脚本已有的缺目标保护。
- 触发条件、现象、影响范围：新增 `test\native-wda-goal-script-tests.ps1` 和 `node test/native-wda-host-smoke.mjs` 断言后，测试先失败，提示 continuation script 仍使用历史 UDID 默认值。影响范围是 Phase 2 长流程编排的 live 设备身份边界；不涉及 GitHub 凭据读取、真机业务 App 操作或 Phase 3 协议。
- 根因：脚本已有 `DeviceUdid is required unless -SkipInstall is used` 的保护，但参数默认值填入历史测试 UDID，导致默认调用时保护不会触发；同时 `-SkipInstall` 仍会调用签名脚本，而签名 profile 校验也需要明确目标 UDID。
- 处理：将 `continue-native-wda-goal.ps1` 的 `DeviceUdid` 默认值改为空字符串，缺 UDID 时只允许 `-ValidateIpaOnly` 这种纯 IPA 结构检查；编排脚本调用 `resign-native-wda.ps1` 时始终传递显式 `-DeviceUdid`，仅在未 `-SkipInstall` 时额外传 `-Install`。文档示例让自托管 runner dispatch 和 `PreflightOnly` 都显式传入 UDID。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\native-wda-goal-script-tests.ps1`；`node test/native-wda-host-smoke.mjs`。
- 下次动作：所有长流程入口的示例命令必须显式显示 UDID 或明确使用不会触发真机操作的 skip 参数；不要用历史测试 UDID 充当恢复运行时的隐式目标。

## 33. 新坑：只读汇总报告也不能默认使用历史 UDID

- 坑点：`check-phase2-readiness.ps1`、`report-ios-device-readiness.ps1`、`report-ios-installed-wda-apps.ps1`、`report-ios-signing-profiles.ps1` 虽然主要是只读报告，但它们会生成 Phase 2 证据的设备身份锚点；如果参数默认历史 UDID，用户确认 iPhone IPA 已卸载后，恢复运行仍可能把旧手机或旧安装态当作当前目标。
- 触发条件、现象、影响范围：新增静态断言后，`test\phase2-readiness-tests.ps1`、`test\ios-device-readiness-report-tests.ps1`、`test\ios-installed-wda-apps-report-tests.ps1`、`test\ios-signing-profile-report-tests.ps1` 先失败，提示报告脚本仍默认 `00008030-0001598021E2802E`。随后 CLI guard 发现 `Get-IosDeviceReadinessReport -DeviceUdid ""` 和 `Get-IosInstalledWdaAppsReport -DeviceUdid ""` 会被 PowerShell 参数绑定提前拦截，进不了显式 blocker 逻辑。影响范围是 Phase 2 证据身份边界和恢复运行入口；不涉及安装、启动、relay、WDA HTTP 请求或 GitHub 凭据读取。
- 根因：这些脚本的顶层参数或内部函数默认值仍写死历史测试 UDID；同时部分 `Mandatory` 参数缺少 `[AllowEmptyString()]`，导致空默认值不能被业务逻辑处理。
- 处理：将上述报告/汇总脚本的 `DeviceUdid` 默认值改为空字符串；缺 UDID 时生成明确 blocker，不枚举安装态或接受签名 profile 作为无线验收依据；给允许空目标进入 blocker 的函数参数增加 `[AllowEmptyString()]`。历史 UDID 只保留在测试数据、历史日志和显式示例中。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-device-readiness-report-tests.ps1`；`.\test\ios-installed-wda-apps-report-tests.ps1`；`.\test\ios-signing-profile-report-tests.ps1`；`.\test\phase2-readiness-tests.ps1`；`node test/native-wda-host-smoke.mjs`。CLI guard：无 `-DeviceUdid` 运行 device readiness、installed apps、signing profile 三个报告均返回含 `DeviceUdid is required` 的 blocker。
- 下次动作：任何会写入 Phase 2 证据身份的报告脚本，即使只读，也必须默认无目标并要求显式 UDID；恢复上下文时先确认当前设备是否仍安装 IPA，再决定是否进入安装态或 runtime 验证。

## 34. 新坑：combined readiness 默认不应读取 GitHub 凭据

- 坑点：`check-phase2-readiness.ps1` 用于恢复上下文和本地 Phase 2 门禁时，如果默认调用 GitHub scope/account 报告，就会在没有明确 GitHub 鉴权任务时尝试读取 token 文件。
- 触发条件、现象、影响范围：新增 CLI mock 用例后，默认运行 readiness 时，临时 `report-cloud-actions-scope.ps1` 和 `report-github-actions-account-scope.ps1` 被设置为一旦调用就抛错。旧流程会默认调用它们；影响范围是 GitHub 凭据读取边界和恢复检查入口，不涉及真机安装、启动、relay、WDA HTTP 请求或业务 App 操作。
- 根因：combined readiness 同时覆盖本地设备/安装态门禁和 GitHub Actions cloud-build 门禁，但入口没有区分“本地恢复检查”和“显式检查 GitHub Actions 远端状态”。
- 处理：新增 `-IncludeGitHubReports`。默认不调用 GitHub 报告、不读取 token 文件，并用 `Cloud: GitHub scope reports were not run...` 标记 cloud readiness unknown；只有显式传入 `-IncludeGitHubReports` 和 `-TokenPath` 时才检查 GitHub Actions 范围。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`；`node test/native-wda-host-smoke.mjs`。
- 下次动作：恢复上下文、本地 artifact、签名、设备和安装态检查默认不应读取 GitHub 凭据；只有准备 cloud build、远端 workflow scope 或 GitHub account scope 时才显式启用 GitHub 报告。

## 35. 新坑：artifact 报告重复扫描 ZIP entry 会拖慢 combined readiness

- 坑点：`report-native-host-artifacts.ps1` 对同一个 IPA/ZIP entry 分别查找 `/wda/network`、`/proxy/status`、`/proxy/screenshot`、`/proxy/source`，会对候选包里的二进制和 framework 文件重复读取；在当前 `artifacts` 目录有 15 个候选包时，单独 artifact 报告约 39 秒，combined readiness 默认 CLI 容易在 40 秒附近超时。
- 触发条件、现象、影响范围：执行 `Measure-Command { powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-native-host-artifacts.ps1 -AsJson -NoFail | Out-Null }` 返回约 39 秒；随后 `check-phase2-readiness.ps1 -AsJson -NoFail` 在 40 秒超时。影响范围是本地只读报告性能，不涉及真机、WDA endpoint、GitHub 凭据或签名密码。
- 根因：基于代码和计时结果，候选扫描只命中 15 个包，但 route marker 检查对每个 entry 多次打开和读取；第一次尝试用 PowerShell 逐字节多标记匹配时，因为 `pscustomobject` 状态更新开销过高，实仓库命令超过 100 秒仍未完成。
- 处理：新增 `Get-ZipEntryAsciiTextMatches`，每个 entry 只读取一次，用 .NET `MemoryStream.CopyTo` 后转 ASCII 字符串并对多个 route marker 做 `Contains`；`Get-NativeHostArtifactSummary` 用该 helper 一次性更新四个 route 标记。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\native-host-artifact-report-tests.ps1`；优化后 artifact 报告约 1.9 秒，`check-phase2-readiness.ps1 -AsJson -NoFail` 默认本地模式约 5.1 秒并返回 `GitHubReportsIncluded=false`。
- 下次动作：Phase 2 恢复检查如果变慢，先用 `Measure-Command` 分解各子报告；对 ZIP/IPA 内二进制标记检查优先批量读取和批量匹配，不要在 PowerShell 层对大文件做逐字节对象循环。

## 36. 新坑：combined readiness 默认自动加载最新 runtime/Bonjour 会混入历史证据

- 坑点：`check-phase2-readiness.ps1` 默认从 `logs/phase2-runtime-*` 和 Bonjour 日志里自动选择最新报告时，用户确认 iPhone IPA 已卸载后，旧 runtime/Bonjour 报告会混入当前恢复检查。
- 触发条件、现象、影响范围：默认执行 `check-phase2-readiness.ps1 -AsJson -NoFail` 时，报告包含 `RuntimeReportPath=logs\phase2-runtime-20260515-090240\phase2-runtime-report.json` 和旧 Bonjour 路径，并输出旧设备的 proxy/Wi-Fi blockers。影响范围是 Phase 2 证据归属和恢复判断；不涉及真机安装、启动、relay、WDA HTTP 请求或 GitHub 凭据。
- 根因：入口只区分显式 `-RuntimeReportPath`/`-BonjourReportPath` 和“未传路径时找最新”，没有区分当前设备状态是否仍满足旧日志前置条件。
- 处理：新增 `-UseLatestRuntimeReport` 和 `-UseLatestBonjourReport`；默认不自动读取最新日志。需要使用历史日志时，必须显式传报告路径或显式启用 latest 开关。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`；默认 `check-phase2-readiness.ps1 -AsJson -NoFail` 返回空的 `RuntimeReportPath` 和 `BonjourReportPath`。
- 下次动作：恢复上下文时不要默认把 logs 里的最新 runtime/Bonjour 当作当前设备证据；只有在确认安装态仍有效或明确做历史诊断时才显式选择日志。

## 37. 新坑：静态 smoke 断言要跟随证据策略变化同步更新

- 坑点：`test/native-wda-host-smoke.mjs` 仍断言 `docs/offline-automation-v1.md` 会提到默认选择最新 `logs/phase2-runtime-*` 报告，但 Phase 2 策略已经改为默认不自动加载 runtime/Bonjour 历史日志。
- 触发条件、现象、影响范围：运行 `node test/native-wda-host-smoke.mjs` 时，包含 `newest` 与 `logs/phase2-runtime-*/phase2-runtime-report.json` 的旧正则断言失败。影响范围是静态 smoke 验证；不涉及真机安装、启动、relay、WDA HTTP 请求、GitHub 凭据或签名材料。
- 根因：readiness 入口增加 `-UseLatestRuntimeReport` 和 `-UseLatestBonjourReport` 后，文档表达已经从“自动使用最新日志”改为“默认不自动加载，显式开关才使用最新日志”，但 smoke 仍保留旧文案断言。
- 处理：将 smoke 断言改为检查“不默认 auto-load runtime/Bonjour”、`historical evidence`、两个显式 latest 开关，以及“intentionally want the newest matching log under `logs/`”。
- 验证：`node test/native-wda-host-smoke.mjs`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`；默认 `check-phase2-readiness.ps1 -AsJson -NoFail` guard。
- 下次动作：任何 Phase 2 证据接收策略变化，都要同步检查 `docs/offline-automation-v1.md` 和 `test/native-wda-host-smoke.mjs` 的静态文案断言，避免把过期测试当成实现回归。

## 38. 新坑：显式 Bonjour 证据不能只按预运行 gate 返回成功

- 坑点：`check-phase2-readiness.ps1` 在只传入 `-BonjourReportPath`、不传 `-RuntimeReportPath` 时，退出码仍按 `ReadyForPhase2WirelessValidation` 判断，导致显式选择的不可用 Bonjour endpoint 证据没有让 CLI 失败。
- 触发条件、现象、影响范围：所有 cloud、artifact、signing、device、installed-state 前置 mock gate 均通过，传入 `EndpointReady=false` 的 Bonjour 报告后，`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 ... -BonjourReportPath <report> -AsJson` 退出码为 `0`。影响范围是 Phase 2 completion gate 的 CLI 语义；不涉及真机、WDA HTTP 请求、GitHub 凭据或签名材料。
- 根因：CLI 退出码只用 `RuntimeReportPath` 判断是否进入 `ReadyForPhase2Completion`，没有把显式 `BonjourReportPath` 也视为 completion evidence。
- 处理：新增 completion-evidence 判定：显式 runtime 报告或显式 Bonjour 报告任一存在时，CLI 都必须用 `ReadyForPhase2Completion` 作为非 `-NoFail` 的退出条件。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`；`node test/native-wda-host-smoke.mjs`。
- 下次动作：任何显式传入 runtime、Bonjour 或后续 endpoint 证据的 readiness 入口，都应按 Phase 2 completion gate 判定退出码，不能只因为签名/设备/安装等预运行 gate 通过就返回成功。

## 39. 新坑：文档换行会让 smoke 文案断言误判

- 坑点：Phase 2 文档后段仍可能残留“Bonjour latest 自动加载”的旧表述；同时 smoke 正则如果按单行文本匹配，会在 Markdown 自动换行后误判文档缺少“显式 `-BonjourReportPath` 或 `-UseLatestBonjourReport` 才使用最新日志”的新策略。
- 触发条件、现象、影响范围：更新 `docs/offline-automation-v1.md` 后，`node .\test\native-wda-host-smoke.mjs` 对 Bonjour latest 文案的断言需要跨行匹配，否则同一语义被 Markdown 换行拆开时会失败。影响范围是静态 smoke 与文档策略同步；不涉及真机、WDA HTTP 请求、GitHub 凭据、签名材料或 endpoint 探测。
- 根因：文档策略已经变为默认不自动加载 runtime/Bonjour 历史日志，但后段 Bonjour 说明和 smoke 正则初版没有同时覆盖“显式路径”和“显式 latest 开关”；正则也没有允许 Markdown 行内换行。
- 处理：将文档改为 `-BonjourReportPath` 或 `-UseLatestBonjourReport` 才纳入 Bonjour 日志；将 smoke 断言改为允许 `or\s+the newest`、`only when\s+` 这类跨行空白。
- 验证：`node .\test\native-wda-host-smoke.mjs`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-runtime-probe-tests.ps1`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\wda-bonjour-probe-tests.ps1`；默认 `check-phase2-readiness.ps1 -AsJson -NoFail` guard 返回空 `RuntimeReportPath`、空 `BonjourReportPath`、`GitHubReportsIncluded=false`；`git diff --check -- .\Scripts\check-phase2-readiness.ps1 .\test\phase2-readiness-tests.ps1 .\test\native-wda-host-smoke.mjs .\docs\offline-automation-v1.md .\docs\phase2-pitfalls-and-lessons.md` 通过。
- 下次动作：修改 Phase 2 证据策略文档时，先用 `rg` 查找所有 `latest`、`auto-load`、`runtime`、`Bonjour` 表述，再同步 smoke 断言；涉及 Markdown 文案的正则默认使用 `\s+` 覆盖换行。

## 40. 新坑：Windows bash/WSL 探测失败输出会污染 readiness 日志

- 坑点：`report-native-host-build-toolchain.ps1` 在 Windows 上调用 `bash -lc "true"` 失败时，底层 WSL/bash 错误可能包含 NUL 字节和控制字符，直接写入 `BashProbeMessage` 与 `BlockingIssues` 会让 `check-phase2-readiness.ps1` 的人类可读输出出现乱码和多余控制字符。
- 触发条件、现象、影响范围：默认运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -NoFail` 时，`Local native-host build blockers` 中的 `bash probe failed` 后出现带 NUL 分隔的 `Bash/Service/CreateInstance/E_ACCESSDENIED` 类错误。影响范围是本地只读 readiness/report 输出质量；不涉及真机、WDA endpoint、GitHub 凭据、签名密码或证书内容。
- 根因：工具链报告把 `bash` stderr/异常消息原样拼接进报告，没有过滤不可打印控制字符。
- 处理：新增 `ConvertTo-PrintableReportText`，在 `New-NativeHostBuildToolchainReport` 中将 `BashProbeMessage` 清理为单行可打印文本后再写入报告对象和 blocker，移除 NUL、控制字符和替换字符，同时保留可定位的 WSL 失败原因。
- 验证：先运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\native-host-build-toolchain-report-tests.ps1` 复现新增断言失败；修复后同一命令通过。随后用默认 `check-phase2-readiness.ps1 -AsJson -NoFail` 确认 `ToolchainReport.BashProbeMessage` 和 `LocalNativeHostBuildBlockingIssues` 不再携带 NUL、0x02、替换字符或多行 probe message。
- 下次动作：任何会汇总外部工具 stderr 的 Phase 2 报告脚本，都应先清理控制字符再进入 `BlockingIssues`、JSON 或文档摘要；保留错误原因，不保留二进制样式原始输出。

## 41. 新坑：卸载后的 installed 快照不能继续标成 Latest

- 坑点：`docs/offline-automation-v1.md` 中卸载前的 read-only 环境快照仍写作 `Latest read-only Phase 2 environment snapshot`，并列出两个目标 bundle id 已安装；用户确认 iPhone 上 IPA 已卸载后，这种标题容易在恢复上下文时被误读成当前安装态。
- 触发条件、现象、影响范围：恢复 Phase 2 上下文时，文档同一段同时存在“用户后来确认 IPA 已卸载”和“Latest snapshot installed”两类信息。影响范围是文档证据归属和下一步入口选择；不涉及真机、WDA HTTP 请求、GitHub 凭据或签名材料。
- 根因：文档追加了卸载事实，但没有同步降级旧 installed-state 快照的标题和解释文字；静态 smoke 也没有禁止旧快照继续被称为 latest。
- 处理：将该段改为 `Historical read-only Phase 2 environment snapshot (invalidated by later uninstall)`，正文明确它只是旧诊断上下文，安装态必须在安装当前 verified IPA 后重新生成；smoke 增加断言，禁止该旧段继续使用 `Latest read-only Phase 2 environment snapshot`。
- 验证：先运行 `node .\test\native-wda-host-smoke.mjs` 复现新增断言失败；修改文档和跨行正则后，同一命令通过。
- 下次动作：任何设备状态被用户更新后，文档里的旧 installed/runtime/Bonjour 快照标题必须同步标注为 historical 或 invalidated，静态 smoke 要覆盖这种证据降级，避免长期运行时复用旧安装态。

## 42. 新坑：验收表里的旧 runtime/Bonjour 证据不能继续写成 Latest

- 坑点：`docs/offline-automation-v1.md` 的 Phase 2 gate audit 表仍把卸载前的 runtime 和 Bonjour 报告写成 `Latest runtime report`、`Latest Bonjour report`，即使同一文档已经说明当前 iPhone IPA 已卸载。
- 触发条件、现象、影响范围：恢复 Phase 2 时，验收表显示 `StatusReady=true`、`BonjourReady=true` 等字段，但这些字段来自卸载前日志；如果继续称为 latest，后续流程容易把 USB/local `/status` 或 Bonjour discovery 当成当前设备的可用证据。影响范围是文档验收语义和下一步入口选择；不涉及真机、WDA HTTP 请求、GitHub 凭据或签名材料。
- 根因：卸载事实更新后，只处理了 installed 快照标题和 combined readiness 默认加载策略，没有同步降级 gate audit 表中的 runtime/Bonjour 描述。
- 处理：将 gate audit 表中的 runtime 和 Bonjour 证据改为 `Historical runtime report`、`Historical Bonjour report`，并在 gap 中明确这些证据卸载后不可复用；同时把 continuation 小节标题改为 `Historical runtime report (invalidated by later uninstall)` 和 `Historical Bonjour report (invalidated by later uninstall)`。smoke 增加断言，禁止关键验收行和小节标题继续使用 `Latest runtime report` 或 `Latest Bonjour report`。
- 验证：先运行 `node .\test\native-wda-host-smoke.mjs` 复现新增断言失败；修改文档后同一命令通过。
- 下次动作：更新设备状态或安装状态后，不只检查正文段落，也要检查验收表、状态表和下一步表里的 `Latest` 字样；历史 runtime/Bonjour 只能解释过去失败，不能证明当前 no-USB endpoint。

## 43. 新坑：早期真机安装/运行段也要随卸载事实降级

- 坑点：文档前半段仍保留 `Latest verified build and device result`、`Native-host runtime recheck against the already-installed app`、`Latest real-device Phase 2 runtime check` 等标题；这些段落包含已安装 bundle、USB relay 和 Wi-Fi timeout 证据，用户确认卸载后不能再暗示为当前状态。
- 触发条件、现象、影响范围：`rg` 扫描 `Latest .*device|Latest .*runtime|already-installed` 时发现早期 Phase 2 实验段仍使用 latest/installed 语义。影响范围是文档证据归属；不涉及真机、WDA HTTP 请求、GitHub 凭据或签名材料。
- 根因：之前只降级了 continuation 小节、环境快照和 gate audit 表，漏掉了 Phase 2 早期实验记录中的标题。
- 处理：把这些标题改为 `Historical verified build and device result (invalidated by later uninstall)`、`Historical native-host runtime recheck (invalidated by later uninstall)`、`Historical real-device Phase 2 runtime check (invalidated by later uninstall)`；smoke 增加断言，禁止旧标题复现。
- 验证：先运行 `node .\test\native-wda-host-smoke.mjs` 复现新增断言失败；修改文档标题后同一命令通过。
- 下次动作：设备安装状态变化后，优先用 `rg` 扫描 `Latest`、`already-installed`、`Signed IPA installed`、`Installed bundle id`，逐段判断是否应标注 historical/invalidated，避免恢复上下文时把旧真机记录当当前证据。

## 44. 新坑：签名说明文档也会残留旧 runtime 自动加载策略

- 坑点：`docs/resign-wda.md` 仍写着 readiness 默认使用最新 `logs/phase2-runtime-*/phase2-runtime-report.json`，并把 latest runtime report 当作当前 Phase 2 结论；用户确认 iPhone 上 IPA 已卸载后，这会和 combined readiness 的默认安全策略冲突。
- 触发条件、现象、影响范围：运行 `node .\test\native-wda-host-smoke.mjs` 时失败在 `resign-wda.md` 缺少 `does not auto-load the newest runtime report by default` 和 `historical runtime evidence`，并仍命中过期文案。影响范围是文档和静态 smoke，不涉及真机安装、启动、relay、WDA HTTP 请求、GitHub 凭据或签名材料。
- 根因：readiness 脚本已改为只有显式 `-RuntimeReportPath` 或 `-UseLatestRuntimeReport` 才纳入 runtime 日志，但签名/构建说明文档没有同步更新；第一次修正文案时还把 `historical runtime evidence` 拆行，导致静态断言继续失败。
- 处理：将 `resign-wda.md` 改为说明默认不自动加载最新 runtime report；旧日志是 historical runtime evidence；只有显式路径或 `-UseLatestRuntimeReport` 才用于诊断。
- 验证：先运行 `node .\test\native-wda-host-smoke.mjs` 复现失败；修改文档后，同一命令通过。
- 下次动作：Phase 2 证据接收策略变化时，不只检查主 PRD，也要同步扫描 `docs/resign-wda.md`；静态文案断言需要匹配关键短语时，避免把短语拆行。

## 45. 新坑：签名说明的设备验证段也要随卸载事实降级

- 坑点：`docs/resign-wda.md` 的 Phase 2 device verification 段仍保留 `Latest verified cloud build`、`native-host recheck against the installed`、`The latest scripted runtime probe`、`already-installed native host` 等表述。用户确认 iPhone IPA 已卸载后，这些旧记录不能继续暗示为当前设备状态。
- 触发条件、现象、影响范围：新增 `test/native-wda-host-smoke.mjs` 断言后，`node .\test\native-wda-host-smoke.mjs` 失败，提示 `resign-wda.md` 缺少 historical 标题并仍包含 latest/installed 文案。影响范围是文档证据归属和恢复上下文判断；不涉及真机安装、启动、relay、WDA HTTP 请求、GitHub 凭据或签名材料。
- 根因：之前只修正了主 PRD 和 `resign-wda.md` 顶部 readiness 策略段，漏掉了同一签名说明文档后半部分的历史真机运行记录。
- 处理：将云构建、native-host recheck、runtime recheck、read-only runtime/Bonjour probe 标题改为 historical/invalidated；正文把 installed/previous latest 语义改为 then-installed 或 historical。
- 验证：先运行 `node .\test\native-wda-host-smoke.mjs` 复现失败；修改 `docs/resign-wda.md` 后，同一命令通过。
- 下次动作：设备安装状态变化后，扫描所有 Phase 2 文档而不只扫描主 PRD；重点查 `Latest`、`installed`、`already-installed`、`current profile`、`current package`，把卸载前证据标为 historical/invalidated。

## 46. 新坑：历史小节内部的 `Latest report` 也会误导恢复判断

- 坑点：`docs/offline-automation-v1.md` 的小节标题已降级为 historical，但代码块和说明文字里仍有 `Latest report`、`currently installed stale native host`、`already-installed native host` 等内部表述。恢复上下文时只看命中行会把旧 runtime 证据误读成当前状态。
- 触发条件、现象、影响范围：新增 `test/native-wda-host-smoke.mjs` 断言后，`node .\test\native-wda-host-smoke.mjs` 失败，提示主 PRD 缺少 `Historical report: logs/phase2-runtime-...` 和安装当前 verified native host 后再运行 probe 的文案。影响范围是文档证据归属和下一步入口选择；不涉及真机安装、启动、relay、WDA HTTP 请求、GitHub 凭据或签名材料。
- 根因：前几轮只处理了标题、gate audit 和签名说明文档，漏掉了历史小节内部代码块字段和后续操作说明中的 latest/current 语义。
- 处理：将两个 runtime 代码块内的 `Latest report` 改为 `Historical report`；将 current/installed 语义改为 then-installed 或 historical；把后续 probe 命令说明改为“安装当前 verified native host/package 后再运行”。
- 验证：先运行 `node .\test\native-wda-host-smoke.mjs` 复现失败；修改 `docs/offline-automation-v1.md` 和跨行正则后，同一命令通过。
- 下次动作：降级旧证据时不能只改标题；继续用 `rg` 查 `Latest report`、`currently installed`、`already-installed`，并检查代码块内部字段和命令说明是否仍暗示当前设备状态。

## 47. 新坑：local-only readiness 不能把跳过的 GitHub account 检查显示为 True

- 坑点：`check-phase2-readiness.ps1` 默认不运行 GitHub scope/account 报告时，合成的 account report 仍把 `HostedRunnerUsageClean` 和 `ReadyToKeepOnlyTargetRepo` 设为 `true`，导致人类输出和 JSON 看起来像远端账号已经检查通过。
- 触发条件、现象、影响范围：新增 `test\phase2-readiness-tests.ps1` local-only 断言后，测试失败在 `Local-only readiness should not claim hosted-runner usage is clean when GitHub reports were skipped.` 影响范围是恢复上下文和 Cloud/Account gate 判断；不涉及读取 `github.txt`、GitHub API、真机、签名、安装或 WDA HTTP 请求。
- 根因：为了避免默认读取 GitHub 凭据，入口创建了假的 cloud/account 报告；cloud report 正确标记未运行，但 account report 用 `true` 表示“无需 gate”，混淆了“不需要阻断”和“已经检查通过”。
- 处理：默认 local-only 模式下不再创建 account report；`HostedRunnerUsageClean`、`AccountScopeReady`、`KeepOnlyTargetRepoReady` 保持 null。人类输出只在这些字段有实际值时打印。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`；默认 `check-phase2-readiness.ps1 -AsJson -NoFail` 返回 `GitHubReportsIncluded=false`，且 `HostedRunnerUsageClean=null`、`AccountScopeReady=null`、`KeepOnlyTargetRepoReady=null`。
- 下次动作：任何为了避免凭据读取而跳过的远端检查，都应记录为 unknown/null；不要用 `true` 表示“未检查但当前不阻断”。

## 48. 新坑：Codex Windows sandbox ACL 解析失败不能误判为 GitHub 或 readiness 失败

- 坑点：执行 Phase 2 恢复检查时，工具层可能在命令真正产生日志前返回 `windows sandbox: parse deny-read ACL state ...deny_read_acl_state.json`。
- 触发条件、现象、影响范围：并行运行 `check-phase2-readiness.ps1 -AsJson -NoFail` 或相邻只读命令时出现该错误；随后单独重跑默认 readiness 命令成功返回 JSON。影响范围是本地命令调用可靠性和状态判断，不涉及 GitHub API、`github.txt`、真机、签名、安装或 WDA HTTP 请求。
- 根因：未定。现有证据只显示错误来自 Codex/Windows sandbox 的 ACL 状态解析，发生在项目脚本输出之前；项目脚本本身在重跑时能正常完成。
- 处理：遇到该错误时先把命令拆成单独、窄范围重跑，再根据重跑输出判断项目状态；不要把这类工具层错误记录为 GitHub cloud build、账号权限或 readiness 逻辑失败。
- 验证：单独运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -AsJson -NoFail` 成功返回 `NextRequiredGate=Cloud`、`GitHubReportsIncluded=false`、`ReadyNativeHostArtifactCount=0`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\native-host-artifact-report-tests.ps1` 通过。
- 下次动作：恢复上下文时若看到 sandbox ACL parse error，先重跑同一命令或拆分命令确认；只有拿到项目脚本自身的 exit code、JSON、stderr 或测试断言后，才归类为 Phase 2 项目问题。

## 49. 新坑：combined readiness 不能把绝对 TokenPath 再拼到 RepoRoot 下

- 坑点：用户授权读取绝对路径 `github.txt` 后，`check-phase2-readiness.ps1 -IncludeGitHubReports -TokenPath <absolute-path>` 把路径错误转发为 `<repo>\<absolute-path>`。
- 触发条件、现象、影响范围：运行带 GitHub report 的 readiness 时，`report-cloud-actions-scope.ps1` 报告 `GitHub token file not found`，路径形如 `D:\2026_soft\0511_Appium_WDA\D:\2026_soft\0430_WS\0423_iPhone11\github.txt`。影响范围是 Cloud gate 鉴权前置；不涉及 token 内容输出、GitHub API 调用、真机、签名、安装或 WDA HTTP 请求。
- 根因：`check-phase2-readiness.ps1` 无条件使用 `Join-Path $RepoRoot $TokenPath` 转发 token path；下游 `report-cloud-actions-scope.ps1` 本身已经支持绝对路径，但收到的参数已被破坏。
- 处理：在 combined readiness 中先判断 `[System.IO.Path]::IsPathRooted($TokenPath)`；绝对路径原样转发，相对路径才拼到 `RepoRoot`。
- 验证：先运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 复现 fake cloud report 中的绝对路径断言失败；修复后同一命令通过。
- 下次动作：任何从总控脚本转发的文件路径都要区分绝对和相对；尤其是凭据、报告、artifact、profile 路径，不能无条件拼接仓库根目录。

## 50. 新坑：github.txt 不是 GitHub PAT 时不能进入 workflow dispatch

- 坑点：`github.txt` 文件存在且用户授权读取，但里面没有可被脚本识别的 GitHub PAT token；文件存在不等于能调用 GitHub API 或 dispatch workflow。
- 触发条件、现象、影响范围：路径修复后运行 `check-phase2-readiness.ps1 -IncludeGitHubReports -TokenPath <github.txt> -DeviceUdid 00008030-0001598021E2802E -AsJson -NoFail`，下游报告 `GitHub token not found in: <github.txt>`。随后只做安全格式检查，确认非空行存在但没有 `github_pat_...` 或 `ghp_...`/`gho_...`/`ghu_...`/`ghs_...`/`ghr_...` 格式。影响范围是 GitHub REST API 和 workflow dispatch；不涉及输出账号、密码或 token 内容。
- 根因：脚本按 GitHub API 需求读取 PAT；该文件更像账号信息而不是 PAT。GitHub REST workflow dispatch 不能使用普通账号密码替代 PAT。
- 处理：停止 dispatch；不打印文件内容。可选路径是提供可用 PAT，或使用已连接的 GitHub App/connector 在明确授权 commit/push 后把代码发布到可访问目标仓库。
- 验证：安全格式检查只输出布尔和计数；`gh auth status` 显示本机没有 `gh` CLI；`git remote show` 对现有 HTTPS remote 返回 `SEC_E_NO_CREDENTIALS`；GitHub App 可访问 `ds0515/0511_Appium_WDA`，但该仓库为空且没有目标分支或 workflow。
- 下次动作：Cloud gate 前先确认三件事：credential file 是否包含 PAT、目标仓库是否非空且有目标分支/workflow、当前本地变更是否已经被明确授权 commit/push 到该仓库。

## 51. 新坑：PAT 获取步骤不能只留在聊天里

- 坑点：Phase 2 云构建依赖 GitHub PAT，但如果 PAT 创建权限、保存位置和验证命令只存在于一次对话回复里，长期恢复时容易重复读取无效 `github.txt` 或要求用户重新解释。
- 触发条件、现象、影响范围：用户要求协助获取 PAT 后，安全格式检查仍返回 `HasGitHubPat=false`。影响范围是 Cloud gate 可恢复性和用户操作交接；不涉及读取或输出 token 值、GitHub dispatch、真机、签名、安装或 WDA HTTP 请求。
- 根因：当前仓库文档缺少 Phase 2 专用 PAT 获取清单；GitHub token 权限还要同时覆盖 workflow dispatch、workflow 文件、artifact/run 查询，以及自托管 runner 只读查询。
- 处理：在 `docs/offline-automation-v1.md` 中新增 Phase 2 GitHub PAT setup，写明 fine-grained PAT 的目标仓库、最小权限、隐藏输入保存命令、只输出布尔值的 PAT 格式验证命令，以及重新运行 combined readiness 的命令。
- 验证：`rg -n "Phase 2 GitHub PAT setup|HasGitHubPat|Administration: read|Actions: read/write" docs/offline-automation-v1.md`；`git diff --check -- docs/offline-automation-v1.md docs/phase2-pitfalls-and-lessons.md`。
- 下次动作：用户说“PAT 已写入”后，先运行只输出 `HasGitHubPat` 的格式检查；为 true 后再运行 `check-phase2-readiness.ps1 -IncludeGitHubReports -TokenPath <path> -DeviceUdid 00008030-0001598021E2802E -AsJson -NoFail`。

## 快速检查清单

- [ ] 当前分支和 dirty worktree 已记录，未回滚无关改动。
- [ ] `release.ipa` 和 `agent-runner.ipa` 已作为当前 Phase 0 输入重新检查。
- [ ] `github.txt` 仅确认存在，未在不需要鉴权的阶段读取或输出内容。
- [ ] Phase 2 没有被错误标记为完成。
- [ ] device readiness 报告包含当前显式 `DeviceUdid`，否则不接受任何 installed-state、runtime 或 Bonjour 证据。
- [ ] combined readiness 已暴露本机 native-host 构建工具链状态，且未把 Windows 本机构建失败误当作 cloud/self-hosted 路径失败。
- [ ] combined readiness 已暴露当前目标 iPhone 的 installed-state，installed-state 报告带同一 `DeviceUdid`，且未把旧 installed/runtime 日志当作当前状态。
- [ ] 缺少 installed-state 报告时，readiness 必须阻断到 `InstalledApps` gate，不能默认通过。
- [ ] 当前安装包确认是最新构建，不是旧 native host。
- [ ] 签名使用开发型 profile 或明确记录了非开发 profile 仅用于复现阻断。
- [ ] USB relay `/status`、`/screenshot`、`/source` 分别记录结果。
- [ ] Wi-Fi endpoint `/status` 有真实 HTTP 响应。
- [ ] Bonjour endpoint 如果存在，已用同一显式 `DeviceUdid` 生成报告并通过 HTTP 请求验证；`-ProbeStatus` 不允许在缺少 `DeviceUdid` 时运行。
- [ ] 会启动 app、创建 relay 或请求 WDA endpoint 的 live 脚本没有历史 UDID 默认值，必须由调用方显式传入目标。
- [ ] 会生成 device、installed-state、signing 或 combined readiness 证据的只读脚本没有历史 UDID 默认值，缺少 `DeviceUdid` 时返回 blocker。
- [ ] combined readiness 默认不读取 GitHub 凭据；只有显式 `-IncludeGitHubReports` 才调用 GitHub scope/account 报告。
- [ ] artifact 报告没有对同一个 ZIP entry 为多个 route marker 做重复读取；combined readiness 本地默认路径应保持在可交互等待范围内。
- [ ] combined readiness 默认不自动加载最新 runtime/Bonjour 日志；必须显式路径或显式 latest 开关才纳入历史证据。
- [ ] 云端 workflow active，远端分支已包含 native_host 更新。
- [ ] self-hosted macOS runner 在线且标签匹配。
- [ ] 文档、脚本和提交中没有密钥、密码、证书内容或敏感日志。
## 52. 新坑：PAT 已可识别后，Windows PowerShell GitHub API 仍可能卡在 SChannel

- 坑点：触发条件、现象、影响范围：`github.txt` 中已经存在可识别的 GitHub PAT 后，`Invoke-RestMethod https://api.github.com/...` 仍失败，报“基础连接已经关闭: 接收时发生错误”；`curl.exe` 同时出现 `SEC_E_NO_CREDENTIALS`。影响范围是本机 GitHub API preflight，不代表 token 格式错误，也不代表浏览器 GitHub 登录不可用。
- 根因：基于命令输出，Windows PowerShell/curl 走 SChannel 路径时失败；同机 `node fetch('https://api.github.com/rate_limit')` 返回 200，说明 Node/OpenSSL 路径可用。底层 SChannel 凭据状态原因未定。
- 处理：`report-cloud-actions-scope.ps1` 和 `report-github-actions-account-scope.ps1` 在 PowerShell WebCmdlet 失败后使用 Node fallback 只读调用 GitHub API；token 仅通过当前进程环境变量传给 Node，不放到命令行参数，不输出。
- 验证：`node -e "fetch('https://api.github.com/rate_limit',{headers:{'User-Agent':'codex-local-wda-build/1.0'}}).then(r=>console.log(r.status))"` 返回 200；`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\cloud-actions-scope-report-tests.ps1`、`.\test\github-actions-account-scope-report-tests.ps1` 通过。
- 下次动作：遇到 GitHub API “接收时发生错误”时，先区分 PowerShell/SChannel 传输失败和 PAT/权限失败；优先运行 Node 路径的只读 API 探测，不要重复让用户重建 token。

## 53. 新坑：GitHub 云端编译不能编译只存在于本机的源码

- 坑点：触发条件、现象、影响范围：用户明确要求 GitHub 只做云端编译，不把本地项目 push 到 GitHub。只读探测显示 `ds0515/0511_Appium_WDA` 可访问但 size=0，`lobster-wda-cloud-resign` 返回“Git Repository is empty”，workflow_count=0；`gpt0609/WebDriverAgent` 可访问但没有 `lobster-wda-cloud-resign` 分支，目标 workflow 为 disabled 或缺失。影响范围是 Phase 2 云端产物生成入口。
- 根因：GitHub Actions 只能基于 GitHub 仓库中已存在的 ref 和 workflow 执行，不能直接读取当前 Windows 工作区的未推送源码。
- 处理：在“不 push 本地项目”的约束下，只能使用 GitHub 上已经存在且启用的构建源；如果目标仓库为空或缺目标分支/workflow，应报告“云端构建源缺失”，而不是继续 dispatch 或把本地 push 当作默认下一步。
- 验证：Node API 只读探测 `/repos/ds0515/0511_Appium_WDA` 返回 200 且 size=0；`/commits/lobster-wda-cloud-resign` 返回 409；`/actions/workflows` 返回 workflow_count=0；`gpt0609/WebDriverAgent` 的 `lobster-wda-cloud-resign` ref 返回 422。
- 下次动作：Phase 2 云端编译前先确认云端 repo、ref、workflow 三者均存在且 workflow active；如果用户禁止 push，则只能要求用户提供已有云端构建源或允许通过 GitHub UI/API 创建最小构建源，不能默认把本地工作区推上去。

## 54. 新坑：remote-source-only 模式不能把本地 dirty 或本地 workflow 当作云构建阻断

- 坑点：触发条件、现象、影响范围：用户确认 GitHub 只做云端编译且不推送本地项目后，cloud scope 报告仍把本地 working tree dirty、remote ref 与本地 HEAD 不一致、本地 workflow 待发布等列为默认 next action。影响范围是 Phase 2 Cloud gate 的下一步选择；不涉及真机、签名、安装、WDA HTTP 请求或 token 内容。
- 根因：旧 cloud preflight 同时服务“把本地更新发布到云端再构建”和“只使用已有云端源构建”两种模式，默认按前者给出 commit/push 建议。
- 处理：`report-cloud-actions-scope.ps1` 默认改为 remote-source-only：只检查 GitHub 上已经存在的 repo/ref/workflow/runner/artifact 入口；本地 dirty、本地 workflow marker、本地 HEAD 与 remote 的差异不再是默认 blocker。只有显式使用 `-AllowLocalPushRecommendations` 时，才恢复本地发布相关建议。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\cloud-actions-scope-report-tests.ps1`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -DeviceUdid '00008030-0001598021E2802E' -AsJson -NoFail` 的 `NextRequiredAction` 为选择已有 GitHub repo/ref 或提供 unsigned IPA artifact。
- 下次动作：如果用户未明确要求 push 或发布本地代码，Cloud gate 只报告“已有云端源是否可构建”；不要把本地变更状态、workflow 本地修复或 commit/push 作为默认恢复路径。

## 55. 新坑：外部 EasyClick/WDA IPA 不能替代当前自有 native-host Phase 2 产物

- 坑点：触发条件、现象、影响范围：Phase 2 缺 ready native-host artifact 时，只读复核 `D:\2026_soft\0430_WS\0423_iPhone11\release.ipa`、`agent-runner.ipa`、`WebDriverAgent.ipa`。`release.ipa` 是 `com.ws.max` native app，没有 XCTest plug-in 或 `WebDriverAgentLib.framework`；`agent-runner.ipa` 是 EasyClick XCTest runner，含 WDA framework，但 embedded profile 不包含当前目标 UDID；`WebDriverAgent.ipa` 包含目标 UDID，但 profile kind 是 distribution。三者都缺当前自有验收标记 `/wda/network`、`/proxy/status`、`/proxy/screenshot`、`/proxy/source`，也没有 `_wda._tcp` 标记。影响范围是外部 IPA 是否可作为 Phase 2 安装/验证入口；不涉及读取 token、安装、启动或访问业务 App。
- 根因：这些 IPA 的包形态、bundle id、profile 覆盖范围和当前自有 native-host 验收标记不一致；即使个别包含 WDA framework，也只能作为功能形态参考，不能证明当前 LobsterWDAHost 控制链路可用。
- 处理：不要把上述外部 IPA 安装结果作为 Phase 2 完成证据；继续要求一个当前源码构建出的 `LobsterWDAHost` native-host unsigned IPA，且先通过 `report-native-host-artifacts.ps1` 的 `/wda/network`、`/proxy/*` 和 Local Network/Bonjour 检查，再进入签名安装。
- 验证：只读 Python `zipfile` + `plistlib` 摘要检查外部 IPA 的 `Info.plist`、embedded profile 摘要、PlugIns/Frameworks 和路由标记；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-native-host-artifacts.ps1 -SearchRoot 'artifacts' -ExpectedBundleId 'app.honey4212.crystal5671' -AsJson -NoFail` 返回 `ReadyCandidateCount=0`，最新候选缺 `/wda/network` 和 `/proxy/*`。
- 下次动作：外部 IPA 只能进入“参考事实”列表；Phase 2 live install 前必须先拿到当前 native-host artifact report 的 `HasReadyCandidate=true`，否则停止在 artifact gate。

## 56. 新坑：放宽“不上传本地项目”后仍需先确认目标仓库和公开范围

- 坑点：触发条件、现象、影响范围：用户放宽“不上传本地项目”的规定后，重新检查 GitHub 发布路径。`git remote -v` 显示当前 `cloud` remote 指向 `gpt0609/0511_Appium_WDA`，而 Phase 2 cloud 脚本默认目标是 `ds0515/0511_Appium_WDA`；对默认目标运行 `report-cloud-actions-scope.ps1 -AllowLocalPushRecommendations` 后，报告开始给出 commit/push 建议，但目标云端 workflow/ref 仍缺失。对 `gpt0609/0511_Appium_WDA` 的只读 API 探测返回 404。当前仓库文档和测试中还包含本地路径、阶段记录和显式测试 UDID。影响范围是是否把本地分支发布到 GitHub 作为云端构建源；不涉及实际 push 或 workflow dispatch。
- 根因：GitHub Actions 只能编译云端已有 ref；放宽上传规则后，commit/push 可以成为 Cloud gate 的可行路径，但上传目标、仓库可见性、PAT 对目标仓库的权限、以及是否允许发布含本地诊断事实的文档，需要在 push 前确认。
- 处理：先运行 `check-repo-safety.ps1` 排除 artifact、logs、p12、mobileprovision、token 等禁止路径；再用 `report-cloud-actions-scope.ps1 -AllowLocalPushRecommendations` 判断本地 workflow 是否具备 native_host markers。实际 commit/push 前必须明确目标仓库和是否接受发布当前分支内容；不得把 token 写入 remote URL、脚本、日志或提交。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-repo-safety.ps1 -AsJson -NoFail` 返回 `Safe=true`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-cloud-actions-scope.ps1 -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -AllowLocalPushRecommendations -AsJson -NoFail` 返回 `LocalWorkflowFound=true`、`LocalWorkflowSupportsNativeHost=true`，并把本地未提交改动列为需要 commit/push 的 Cloud gate blocker。
- 下次动作：若继续上传路径，先让操作者确认目标 repo（例如 `ds0515/0511_Appium_WDA` 还是另一个 private/public repo）和公开范围；确认后只 stage 与 Phase 2 直接相关的文件，运行测试和 diff review，再使用短中文提交信息提交，并通过不落盘 token 的临时鉴权方式 push。

## 57. 新坑：普通 repo 安全检查通过不等于适合公开发布

- 坑点：触发条件、现象、影响范围：准备把本地 Phase 2 分支上传到 GitHub 云端编译源时，`check-repo-safety.ps1 -AsJson -NoFail` 返回 `Safe=true`，只能说明没有待提交的 token 文件、证书、mobileprovision、artifact、logs 等硬禁止路径；它不能说明文档和测试中没有本地绝对路径、显式 UDID 或 PAT 形态测试字符串。影响范围是 commit/push 前的公开范围判断；不涉及真机、签名、安装、WDA endpoint 或实际 GitHub push。
- 根因：硬安全门禁和公开发布审查是两类问题。前者防止把密钥/产物提交进仓库；后者评估诊断文档、测试样例和本地路径是否适合发布到目标仓库，尤其是 public repo。
- 处理：`check-repo-safety.ps1` 增加可选 `-RequirePublishReviewClean`。默认模式保持原有硬安全检查；上传前审查模式会扫描文本文件里的本地绝对路径、带短横线 iOS UDID 和 PAT-like 字符串，只输出文件、分类和数量，不回显具体 token-like 内容。发现项会让 `Safe=false`，要求先脱敏或确认使用 private target。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\repo-safety-check-tests.ps1` 通过；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-repo-safety.ps1 -AsJson -NoFail` 返回 `Safe=true`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-repo-safety.ps1 -RequirePublishReviewClean -AsJson -NoFail` 返回 `Safe=false` 且列出 `PublishReviewFindings`，不输出具体 PAT-like 值。
- 下次动作：准备 public push 时必须先处理 `-RequirePublishReviewClean` 的发现项；准备 private push 时也要让操作者明确接受这些诊断信息进入 private repo。无论哪种方式，都不能把真实 token、p12、mobileprovision、password 或 artifact 纳入提交。

## 58. 新坑：公开发布不一定要把整套本地诊断文档一起推上云端

- 坑点：触发条件、现象、影响范围：整仓库发布审查会发现 `docs/`、`goal.txt`、部分测试样例中包含本地绝对路径和显式测试 UDID；如果为了 GitHub Actions 云端编译 native-host 而把所有 Phase 2 诊断文档一起推到 public repo，会引入不必要的发布面。影响范围是 Cloud gate 的最小上传范围；不涉及真机、签名、安装、WDA endpoint 或实际 push。
- 根因：GitHub Actions 编译当前 native-host 只需要云端 branch 上有目标 workflow、构建脚本、LobsterWDAHost 源码、WDA 路由改动和必要 plist；本地经验文档、设备报告测试、runtime probe 测试和目标 UDID 示例对云端编译不是必需输入。
- 处理：`check-repo-safety.ps1` 的 `-RequirePublishReviewClean` 支持 `-PublishReviewPath`，可以只扫描准备发布的候选文件集合。当前最小候选集合包括目标 workflow、旧 workflow 删除、`.gitignore`、`LobsterWDAHost/AppDelegate.m`、`LobsterWDAHost/Info.plist`、`Scripts/ci/build-native-ios-host.sh`、`Scripts/ci/build-real-ios-unsigned.sh`、`WebDriverAgentLib/Routing/FBWebServer.m`、`WebDriverAgentRunner/Info.plist`、`WebDriverAgentRunner/UITestingUITests.m`。
- 验证：对上述 17 个候选路径运行 `.\Scripts\check-repo-safety.ps1 -RequirePublishReviewClean -PublishReviewPath <candidate-paths> -AsJson -NoFail`，返回 `Safe=true`、`PublishReviewRequired=false`、`FindingCount=0`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\repo-safety-check-tests.ps1` 通过。
- 下次动作：如果选择 public repo 云端编译，优先只 stage 最小构建候选集合，避免发布本地诊断文档；如果选择 private repo，可以在明确接受后扩大提交范围，但仍必须排除 token、p12、mobileprovision、password、artifacts 和 logs。

## 59. 新坑：手工维护最小发布文件列表容易跑偏

- 坑点：触发条件、现象、影响范围：为了只上传 native-host 云端构建必需文件，手工在命令行拼接 17 个候选路径，容易漏掉目标 workflow、构建脚本、WDA 路由文件，或者误加入本地诊断文档。影响范围是 Cloud gate 的 commit/stage 范围选择；不涉及实际 commit、push、workflow dispatch、真机或签名。
- 根因：最小云端构建发布范围同时包含新增/修改文件和应删除的旧 workflow 文件，单靠临时命令不利于长期恢复后保持一致。
- 处理：新增 `Scripts\report-phase2-cloud-publish-candidate.ps1`，固定输出 Phase 2 native-host 最小候选路径、必须存在的路径、预期删除的旧 workflow 路径、repo safety 发布审查结果、建议 workflow、`package_kind=native_host` 和 `runner_labels_json=macos-15`。该脚本只读运行，不读取 `github.txt`，不 stage、commit、push 或 dispatch。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-cloud-publish-candidate-tests.ps1` 通过；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-cloud-publish-candidate.ps1 -AsJson -NoFail` 返回 `ReadyForMinimalCloudPublish=true`、`CandidatePathCount=17`、`PublishReviewFindingCount=0`。
- 下次动作：进入任何 commit/push 前，先运行该报告；如果 `ReadyForMinimalCloudPublish=false`，不要推送云端构建源；如果为 true，仍需用户明确确认目标 repo/ref 后才能提交或 push。

## 60. 新坑：发布计划脚本只能给建议，不能替操作者执行 git mutation

- 坑点：触发条件、现象、影响范围：最小候选集合 ready 后，还需要判断目标 repo/ref、远端 workflow 状态和下一步是否必须先 publish。直接把这些判断散落在对话里，长期恢复后容易误以为可以直接 dispatch，或把 commit/push 命令当作已执行事实。影响范围是 Cloud gate 的发布计划和操作边界；不涉及实际 commit、push、workflow dispatch、真机或签名。
- 根因：`report-phase2-cloud-publish-candidate.ps1` 只能证明本地候选集合适合最小发布，不能证明云端 ref/workflow 已存在；`report-cloud-actions-scope.ps1` 能读远端状态，但不能给出本地最小 stage 范围。两者需要一个只读汇总层。
- 处理：新增 `Scripts\report-phase2-cloud-publish-plan.ps1`，组合最小候选报告和可选 GitHub cloud scope 报告，输出 `ReadyForMinimalPublish`、`ReadyForDispatch`、`PublishRequiredBeforeDispatch`、`SuggestedStagePaths`、建议 dispatch inputs 和 blocker。脚本默认不读取 `github.txt`；只有显式传 `-IncludeGitHubReports -TokenPath <path>` 时才做 GitHub API 只读检查。脚本输出 `ExecutesGitMutation=false`，不执行 stage、commit、push 或 dispatch。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-cloud-publish-plan-tests.ps1` 通过；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-cloud-publish-plan.ps1 -AsJson -NoFail` 返回 `ReadyForMinimalPublish=true`、`PublishRequiredBeforeDispatch=true`、`ExecutesGitMutation=false`；带 `-IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -RunnerLabelsJson 'macos-15'` 返回 cloud workflow 仍为 `missing`。
- 下次动作：用户确认目标 repo/ref 前，只运行 publish plan；确认后再进入 commit-workflow，stage 仅限 `SuggestedStagePaths`，并继续禁止把 token、p12、mobileprovision、password、artifacts、logs 加入提交。

## 61. 新坑：Cloud target repo 和本地 push remote 不一致会导致误推风险

- 坑点：触发条件、现象、影响范围：准备发布最小 native-host 构建源时，默认 cloud target 是 `ds0515/0511_Appium_WDA`，但 `git remote -v` 中 `cloud` push remote 指向 `gpt0609/0511_Appium_WDA`，`origin` 指向上游 `appium/WebDriverAgent`，`public-build` 指向 `gpt0609/WebDriverAgent`。影响范围是 commit/push 目标选择；不涉及实际 push、workflow dispatch、真机或签名。
- 根因：本地 remote 名称不能等同于 Phase 2 cloud target；脚本默认目标、浏览器登录账号、PAT 权限和 git remote 可以分别指向不同 GitHub repo。
- 处理：新增 `Scripts\report-phase2-cloud-target-remote.ps1`，只读解析 `git remote -v`，把 GitHub remote URL 归一为 `owner/repo`，判断是否存在匹配目标 repo 的 push remote。`report-phase2-cloud-publish-plan.ps1` 现在合并该报告，输出 `ReadyForTargetPush`、`MatchingPushRemoteCount` 和 target-remote blocker，仍保持 `ExecutesGitMutation=false`。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-cloud-target-remote-tests.ps1`、`.\test\phase2-cloud-publish-plan-tests.ps1` 通过；默认目标运行 publish plan 得到 `ReadyForTargetPush=false`、`MatchingPushRemoteCount=0`；以 `-TargetRepo 'gpt0609/0511_Appium_WDA'` 运行得到 `ReadyForTargetPush=true`、`MatchingPushRemoteCount=1`，但 GitHub API cloud scope 对该 repo 仍未 ready。
- 下次动作：commit/push 前必须先确认目标 repo/ref，并保证本地 push remote 与目标一致；不要向 `origin` 或不匹配的 remote 推送 Phase 2 分支。确认后进入 commit-workflow，只 stage `SuggestedStagePaths`。
## 62. 新坑：Git HTTPS SChannel 失败不能直接判定 GitHub repo 不存在

- 坑点：触发条件、现象、影响范围：在 Windows 本机用 `git ls-remote` 只读探测 GitHub 远端时，针对 `ds0515/0511_Appium_WDA`、`gpt0609/0511_Appium_WDA`、`cloud`、`public-build` 都出现 `schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS` 或接收失败。影响范围是 Cloud gate 的远端可读性判断；不涉及源代码正确性、真机安装、WDA endpoint 或 token 内容本身。
- 根因：基于命令输出的最小解释是 Git for Windows 的 HTTPS/SChannel 凭据或 TLS 通道不可用；同一类 GitHub API 检查可通过 Node fallback 得到更明确的 404/409/缺 workflow 等结果，所以不能把 `git ls-remote` 的 SChannel 错误直接解释为 repo 不存在。
- 处理：远端只读判定优先使用已有 Node GitHub API fallback 脚本；真正 push 前单独确认 git credential/GCM/PAT/SSH 通道，不把 PAT 写入 remote URL、脚本、日志或提交信息。
- 验证：`git ls-remote` 对多个 GitHub remote 返回 SChannel 凭据错误；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-cloud-publish-plan.ps1 -TargetRepo 'gpt0609/0511_Appium_WDA' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -RunnerLabelsJson 'macos-15' -AsJson -NoFail` 返回 GitHub API Node fallback 的 404 类结果且不回显 token。
- 下次动作：Cloud gate 遇到 Git HTTPS 失败时，先记录为本机 Git 凭据/传输问题，再用 GitHub API preflight 判断 repo/ref/workflow；只有在目标 repo、remote 和提交推送授权明确后，才进入 commit-workflow 和 push 通道排查。

## 63. 新坑：GitHub API 404 要区分目标 repo 不存在和 PAT 未授权

- 坑点：触发条件、现象、影响范围：对 `gpt0609/0511_Appium_WDA` 运行 Phase 2 云构建 publish plan 时，本地 `cloud` push remote 匹配该 repo，但 GitHub API Node fallback 返回 404。影响范围是 Cloud gate 的目标仓库确认；不涉及 WDA 代码、真机安装、签名、endpoint 或 token 内容本身。
- 根因：GitHub API 对私有仓库、缺失仓库或 fine-grained PAT 未选择该仓库时都可能返回 404；仅凭本地 remote 存在不能证明 token 能读写该 repo。
- 处理：`report-cloud-actions-scope.ps1` 增加 `GitHubApiFailureKind` 和 `GitHubApiFailureHint`，将 404 归类为 `repo_not_found_or_inaccessible`；`report-phase2-cloud-publish-plan.ps1` 透传该分类和 cloud scope 的下一步动作。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\cloud-actions-scope-report-tests.ps1`、`.\test\phase2-cloud-publish-plan-tests.ps1` 通过；真实 preflight 对 `gpt0609/0511_Appium_WDA` 输出 `CloudGitHubApiFailureKind=repo_not_found_or_inaccessible`，并提示确认 repo 存在以及 fine-grained PAT 的仓库访问、Contents read/write 和 Actions 权限。
- 下次动作：遇到 GitHub API 404 时，先确认目标 `owner/repo` 和 PAT repository selection；如果 repo 是私有仓库，更新 fine-grained PAT 授权范围或换成 token 可访问的目标 repo，再考虑提交、推送或 workflow dispatch。

## 64. 新坑：账号 scope 报告不能因 token scope 子查询失败而丢掉 repo inventory

- 坑点：触发条件、现象、影响范围：运行 `report-github-actions-account-scope.ps1 -TokenPath ...` 时，repo inventory 可通过 Node fallback 访问 GitHub API，但 `Get-GitHubTokenScopeSummary` 走 .NET HttpClient 查询 `/user`，在当前 Windows/SChannel 环境下报“发送请求时出错”，导致整份账号 scope 报告降级为 `RepoCount=0` 的 API failure。影响范围是 Cloud gate 的目标仓库判定；不涉及 token 内容、WDA 代码、真机安装或 workflow dispatch。
- 根因：账号 scope 脚本把 repo inventory 和 token scope 查询放在同一个 try/catch 中；其中 token scope 只是辅助判断删除旧 repo 权限，不应阻断非破坏性的仓库可见性诊断。
- 处理：新增 `Get-GitHubTokenScopeSummaryOrFailure`，token scope 查询失败时返回脱敏的 `QuerySucceeded=false` 摘要；`New-GitHubActionsAccountScopeReport` 保留 repo inventory，并仅提示“不能假定 repository DELETE API 权限”。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\github-actions-account-scope-report-tests.ps1` 通过；真实运行账号 scope 现在返回 `RepoCount=1`，可见仓库为 `ds0515/0511_Appium_WDA`，同时 `TokenScopeSummary.QuerySucceeded=false`。
- 下次动作：账号 scope 用于 Phase 2 云构建目标选择时，只把 repo inventory 作为非破坏性事实；token scope 查询失败只能影响删除/清理类建议，不得阻断目标仓库可见性判断。

## 65. 新坑：本地 cloud remote 匹配不等于 PAT 当前可访问目标

- 坑点：触发条件、现象、影响范围：本地 `cloud` remote 指向 `gpt0609/0511_Appium_WDA`，但账号 scope 只列出 `ds0515/0511_Appium_WDA`；对 `gpt0609/0511_Appium_WDA` 的 cloud preflight 返回 404，而 `ds0515/0511_Appium_WDA` 可见但没有 workflow/ref。影响范围是 Cloud gate 的目标 repo 选择和后续是否需要添加匹配 push remote；不涉及实际 push、commit、真机或签名。
- 根因：Git remote 配置、本地浏览器登录账号、fine-grained PAT repository selection 可以指向不同 GitHub 账户或仓库；只有 PAT 可访问的 repo 才能作为当前脚本可靠的云端构建目标。
- 处理：优先将当前 PAT 可见的 `ds0515/0511_Appium_WDA` 作为 cloud target；由于本地没有匹配该 repo 的 push remote，实际发布前仍需用户明确批准添加/选择匹配 remote，并只 stage 最小 17 个 Phase 2 构建文件。
- 验证：`report-github-actions-account-scope.ps1 -KeepRepo 'ds0515/0511_Appium_WDA' -TokenPath ... -AsJson -NoFail` 返回 `RepoCount=1`、`ReadyToKeepOnlyTargetRepo=true`；`report-phase2-cloud-publish-plan.ps1 -TargetRepo 'ds0515/0511_Appium_WDA' -IncludeGitHubReports ...` 返回 `CloudTargetWorkflowState=missing`、`MatchingPushRemoteCount=0`。
- 下次动作：若继续云端构建，下一步应明确授权为 `ds0515/0511_Appium_WDA` 添加或选择匹配 push remote，再按 `SuggestedStagePaths` 提交/推送最小构建源；不要向 `gpt0609/0511_Appium_WDA` 推送，除非 PAT 已更新并重新 preflight 证明可访问。

## 66. 新坑：确认新项目后，本地 `.git/config` 仍可能阻止 remote 切换

- 坑点：触发条件、现象、影响范围：用户确认 `gpt0609/0511_Appium_WDA` 是老项目、当前全部切换到新项目后，尝试把本地 `cloud` remote 改指向 `ds0515/0511_Appium_WDA`，但 `git remote set-url cloud https://github.com/ds0515/0511_Appium_WDA.git` 失败，报 `could not lock config file .git/config: Permission denied`。影响范围是本地 push remote 对齐；不涉及云端 repo 可见性、WDA 代码、真机安装、token 内容或实际 push。
- 根因：本地 `.git/config` 写入权限或锁定状态不可用；这类问题与目标 repo 是否存在、PAT 是否可访问是不同层的问题。
- 处理：不要强行改写 `.git/config`，也不要绕过权限写入包含 token 的 remote URL；`report-phase2-cloud-target-remote.ps1` 增加只读 git config 写入安全检查，显式报告 lock 文件和 `.git`/`.git/config` 上的 DENY 写 ACL，并把“本地 remote 不匹配”和“git config 不可安全更新”保留为 publish 前 blocker。
- 验证：`git remote set-url cloud https://github.com/ds0515/0511_Appium_WDA.git; git remote -v` 输出仍显示 `cloud` 指向 `gpt0609/0511_Appium_WDA.git`，并返回 `.git/config: Permission denied`；`report-phase2-cloud-target-remote.ps1 -TargetRepo 'ds0515/0511_Appium_WDA' -AsJson -NoFail` 返回 `GitConfigMutationReady=false`、`ExplicitDenyWriteRuleCount=2`。
- 下次动作：真正进入 commit/push 前，先解决 `.git/config` 写权限或使用明确批准的临时 git 配置通道；无论哪种方式，都不能把 PAT 写入 remote URL、脚本、日志或提交信息。

## 67. 新坑：确认云端可见还要确认 PAT 对新项目有 push 权限

- 坑点：触发条件、现象、影响范围：`ds0515/0511_Appium_WDA` 已被账号 scope 识别为当前可见新项目，但仅“可见”不等于后续能上传最小构建源。影响范围是 Cloud gate 的发布可行性判断；不涉及实际 commit、push、workflow dispatch、真机或签名。
- 根因：GitHub repo API 的 `permissions` 字段会分别给出 `admin`、`push`、`pull`；fine-grained PAT 可能只能读 repo，不能写 contents。云端构建源发布至少需要目标 repo 对当前 token 呈现 `push=true` 或等价写入能力。
- 处理：`report-github-actions-account-scope.ps1` 增加 `PushPermission` 和 `PullPermission` 输出，人类可读报告也打印 `push_permission`；以账号 scope 的 repo inventory 作为非破坏性写入能力证据。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\github-actions-account-scope-report-tests.ps1` 通过；真实运行 `report-github-actions-account-scope.ps1 -KeepRepo 'ds0515/0511_Appium_WDA' -TokenPath ... -AsJson -NoFail` 返回 `RepoSummaries[0].PushPermission=true`、`PullPermission=true`、`AdminPermission=true`。
- 下次动作：若继续上传最小构建源，优先使用 `ds0515/0511_Appium_WDA`；发布前仍需解决本地 `.git/config` ACL 或采用明确批准的非 `.git/config` 发布路径，并继续禁止把 token 写入 remote URL、脚本、日志或提交信息。

## 68. 新坑：本地 git remote 被 ACL 卡住时，可以先生成 GitHub API dry-run 发布计划

- 坑点：触发条件、现象、影响范围：`ds0515/0511_Appium_WDA` 可见且 `PushPermission=true`，但本地 `.git/config` 因 DENY ACL 不能改 remote，常规 `git push <remote>` 路径暂时不可用。影响范围是 Phase 2 云端构建源发布路径选择；不涉及实际 GitHub 写入、workflow dispatch、真机或签名。
- 根因：云端构建源发布需要把最小构建文件送到 GitHub branch，但这不必然只能通过修改本地 `.git/config` 后再 `git push`；GitHub Git Database API 也能创建 blob、tree、commit 和 ref。该路径仍是远端写入，必须显式批准后才能执行。
- 处理：新增 `report-phase2-github-api-publish-plan.ps1`，只读汇总候选文件、账号 repo 权限和云端 ref 状态，输出 GitHub API 发布步骤、`CreateOrUpdatePaths`、`DeletePaths`、是否可能需要 root commit，并明确 `ExecutesGitHubMutation=false`、`UsesGitConfig=false`。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-github-api-publish-plan-tests.ps1` 通过；真实 dry-run `report-phase2-github-api-publish-plan.ps1 -TargetRepo 'ds0515/0511_Appium_WDA' -IncludeGitHubReports -TokenPath ... -RunnerLabelsJson 'macos-15' -AsJson -NoFail` 返回 `ReadyForGitHubApiPublishPlan=true`、`CreateOrUpdatePathCount=9`、`DeletePathCount=8`、`RootCommitLikelyRequired=true`。
- 下次动作：如果用户明确授权远端写入，可以基于该 dry-run 计划实现或执行受控 GitHub API publication；执行前必须再次跑 repo safety，token 只能放请求头或进程环境，不能写入 remote URL、脚本、日志、文档或提交信息。

## 69. 新坑：旧项目确认废弃后仍需要一个受控远端写入入口，避免恢复后误用旧 remote

- 坑点：触发条件、现象、影响范围：用户确认 `gpt0609/0511_Appium_WDA` 是老项目并要求全部切到新项目后，常规 `git push` 仍会被本地 `.git/config` ACL 和旧 `cloud` remote 影响；同时 Phase 2 需要把最小云构建源写到 `ds0515/0511_Appium_WDA`。影响范围是云端构建源发布入口；不涉及 workflow dispatch、真机安装、WDA endpoint 或证书签名。
- 根因：默认 remote、PAT 可访问仓库和当前云构建目标不是同一个事实源。只靠文档或对话约定，长期恢复后容易再次走到旧 `cloud` remote 或误把 dry-run 当成已写远端。
- 处理：新增 `Scripts\publish-phase2-github-api-source.ps1`，默认只 dry-run，输出 `ExecutesGitHubMutation=false`；执行写入时必须同时满足 `-Execute`、目标 repo 为 `ds0515/0511_Appium_WDA`、ref 为 `lobster-wda-cloud-resign`、确认字符串完全匹配，并且 token 只通过请求头/进程环境使用。带 `TokenPath` 的 dry-run 会输出 `ExecuteCommandPreview` 便于审核下一步命令，但不输出 token 值。root commit 时不带 parent；已有远端 head 时才带 parent，并只删除远端已存在的旧 workflow 路径。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-github-api-publish-source-tests.ps1` 通过；真实 dry-run `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\publish-phase2-github-api-source.ps1 -TargetRepo 'ds0515/0511_Appium_WDA' -Ref 'lobster-wda-cloud-resign' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -AsJson -NoFail` 返回 `ReadyForExecute=true`、`ExecutesGitHubMutation=false`、`CreateOrUpdatePathCount=9`、`DeletePathCount=8`，没有输出 token。
- 下次动作：恢复 Phase 2 云构建时，先运行 source publish dry-run；只有当目标 repo/ref 与确认字符串都匹配且用户明确允许远端写入时，再执行 `-Execute`。执行后必须重新跑 cloud publish plan，确认远端 workflow/ref 存在并 active，再考虑 dispatch。

## 70. 新坑：API 发布返回 commit 之后仍要重新验证远端源状态，不能直接 dispatch

- 坑点：触发条件、现象、影响范围：GitHub API source publication 即使执行成功，也只能证明 GitHub 接受了 blob/tree/commit/ref 请求；如果长期恢复时直接进入 workflow dispatch，可能漏掉远端分支缺文件、旧 workflow 未删除、ref 未创建或 API 写入部分失败。影响范围是 Cloud gate 的发布后验证顺序；不涉及真机、签名、安装或 WDA endpoint。
- 根因：Phase 2 云构建依赖远端 branch 当前状态，而不是本地候选列表或一次 API 返回值。远端是否包含 9 个 create/update 路径、是否缺少 8 个旧 workflow 路径，需要重新通过 GitHub 只读 API 从 branch tree 读取。
- 处理：新增 `Scripts\report-phase2-remote-source-state.ps1`，只做 GitHub GET 检查，不使用 `.git/config`，不执行 dispatch，不创建 commit/ref。它读取最小候选报告，比较远端 tree 中的 required paths 和 expected-deleted paths，输出 `ReadyForRemoteSourceState`、缺失路径、仍存在的旧 workflow 路径和下一步。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-remote-source-state-tests.ps1` 通过；真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-remote-source-state.ps1 -TargetRepo 'ds0515/0511_Appium_WDA' -Ref 'lobster-wda-cloud-resign' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -AsJson -NoFail` 应在尚未发布时返回 `ReadyForRemoteSourceState=false` 和 remote ref 缺失类 blocker，且不输出 token。
- 下次动作：执行 source publication 后，先跑 remote source state report；只有它 ready，再跑 cloud publish plan。仍不得把 remote source state ready 当作 Phase 2 完成证据，它只清除 Cloud source 子门禁。

## 71. 新坑：dispatch 前还要把“远端源 ready”和“workflow dispatch ready”合成同一门禁

- 坑点：触发条件、现象、影响范围：即使 remote source state ready，也还可能存在 workflow disabled、缺 self-hosted runner、hosted runner billing block、workflow 不支持 `package_kind=native_host` 等 cloud dispatch 阻断。反过来，仅看 cloud publish plan 也可能忽略远端源树状态。影响范围是是否可以触发 GitHub Actions 构建；不涉及真机、签名、安装或 WDA endpoint。
- 根因：Phase 2 的 Cloud gate 至少有两个独立事实源：远端 branch tree 是否包含最小构建源，以及目标 workflow 是否可安全 dispatch。二者都必须 ready，才能进入云构建；任何一个 ready 都不能单独证明可以触发 Actions。
- 处理：新增 `Scripts\report-phase2-cloud-dispatch-plan.ps1`，组合 `report-phase2-remote-source-state.ps1` 和 `report-phase2-cloud-publish-plan.ps1`，输出 `ReadyForCloudDispatchPlan`、两侧 blocker、suggested dispatch inputs，并保持 `ExecutesGitHubMutation=false`。它只在两侧都 ready 时输出 `continue-native-wda-goal.ps1 ... -ValidateIpaOnly` 命令预览，避免直接进入签名、安装或 live probe。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-cloud-dispatch-plan-tests.ps1` 通过；真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-cloud-dispatch-plan.ps1 -TargetRepo 'ds0515/0511_Appium_WDA' -Ref 'lobster-wda-cloud-resign' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -RunnerLabelsJson 'macos-15' -AsJson -NoFail` 在当前未发布远端源时应返回 `ReadyForCloudDispatchPlan=false`，且不输出 token。
- 下次动作：执行 source publication 后，依次跑 remote source state、cloud publish plan、cloud dispatch plan。只有 dispatch plan ready，才执行 `continue-native-wda-goal.ps1` 的 validation-only 云构建命令；拿到并验证 unsigned IPA 后，再进入签名/安装前置检查。

## 72. 新坑：repo 可见和 push/admin 不等于 token 或 integration 能写 Git blob/content

- 坑点：触发条件、现象、影响范围：用户授权远端写入后，`publish-phase2-github-api-source.ps1 -Execute` 对 `ds0515/0511_Appium_WDA@lobster-wda-cloud-resign` 写入最小 Phase 2 源时失败。增强脱敏错误后定位为 `POST /repos/ds0515/0511_Appium_WDA/git/blobs` 返回 HTTP 403，message 为 `Resource not accessible by personal access token`。随后用 GitHub 连接器尝试创建 `.gitignore` 到同一目标分支，也返回 HTTP 403，message 为 `Resource not accessible by integration`。影响范围是云端构建源发布，未创建目标分支，未形成可 dispatch workflow；不涉及真机、签名、WDA endpoint 或 token 内容本身。
- 根因：基于 GitHub API 错误和连接器错误的最小解释是：当前 PAT 或 GitHub integration 对目标仓库缺少 contents/git database 写入权限。`report-github-actions-account-scope.ps1` 或 repo metadata 中的 `push/admin=true` 只能证明账号/安装视角具备仓库权限，不能替代 fine-grained PAT 的 `Contents: Read and write` 或 integration contents write 权限。
- 处理：给 `publish-phase2-github-api-source.ps1` 增加脱敏错误格式化，报告 GitHub API method、路径、HTTP status 和 response message，同时继续用 token 正则脱敏；不把 token 写入日志、文档、remote URL 或提交信息。远端源状态复查仍显示 `RemoteRefFound=false`，因此不得 dispatch workflow。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-github-api-publish-source-tests.ps1` 覆盖脱敏错误格式；真实执行写入返回 `GitHub API POST /repos/ds0515/0511_Appium_WDA/git/blobs failed with HTTP 403: Resource not accessible by personal access token`；`report-phase2-remote-source-state.ps1 -TargetRepo 'ds0515/0511_Appium_WDA' -Ref 'lobster-wda-cloud-resign' ... -AsJson -NoFail` 返回 `RemoteRefFound=false`。
- 下次动作：在 GitHub fine-grained PAT 设置里确认目标 repo 仍选中 `ds0515/0511_Appium_WDA`，Repository permissions 至少包含 `Contents: Read and write`，并保留 Actions 相关权限用于后续 workflow dispatch；更新 token 后先跑 source publish dry-run，再执行 `-Execute`，执行后立刻跑 remote source state 和 cloud dispatch plan。

## 73. 新坑：Cloud gate 必须先汇总 source、remote source 和 dispatch，不能让后续门禁掩盖 PublishSource

- 坑点：触发条件、现象、影响范围：远端源尚未发布时，单独运行 dispatch plan 会同时输出 remote source、workflow missing、local dirty、remote 不匹配和 git config ACL 等多类 blocker，长期恢复时容易把下一步误判为修 workflow 或修 remote，而不是先发布最小源。首次实现 cloud gate 时，单测还暴露 PowerShell 的空 `List[string]` 不能绑定到 Mandatory 参数，导致报告函数在还没判断业务门禁前失败。影响范围是 Phase 2 云构建门禁排序；不涉及 GitHub 写入、workflow dispatch、真机、签名或 WDA endpoint。
- 根因：Phase 2 云构建至少有三个顺序事实源：source publish dry-run 是否可执行、远端分支是否含最小源、workflow 是否可 dispatch。缺少顶层汇总时，后置 blocker 会掩盖最前置 blocker。PowerShell 参数绑定方面，空集合被 Mandatory 参数视为无效输入，不适合用于内部累加器 helper。
- 处理：新增只读 `Scripts\report-phase2-cloud-gate.ps1`，组合 `publish-phase2-github-api-source.ps1` dry-run、`report-phase2-remote-source-state.ps1` 和 `report-phase2-cloud-dispatch-plan.ps1`，输出 `ReadyForCloudBuild`、`NextRequiredGate`、`NextRequiredAction`，并固定 `ExecutesGitHubMutation=false`。内部累加器 helper 不使用 Mandatory 空集合绑定。
- 验证：先运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-cloud-gate-tests.ps1` 得到缺脚本 RED；实现后该测试通过。相邻验证 `test\phase2-github-api-publish-source-tests.ps1`、`test\phase2-remote-source-state-tests.ps1`、`test\phase2-cloud-dispatch-plan-tests.ps1` 通过。真实只读运行 `report-phase2-cloud-gate.ps1 -TargetRepo 'ds0515/0511_Appium_WDA' -Ref 'lobster-wda-cloud-resign' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -RunnerLabelsJson 'macos-15' -AsJson -NoFail` 返回 `ReadyForCloudBuild=false`、`NextRequiredGate=PublishSource`、`ExecutesGitHubMutation=false`。
- 下次动作：每次恢复 Phase 2 云构建时，优先跑 cloud gate 汇总；若 `NextRequiredGate=PublishSource`，只允许重跑 source publish dry-run 或在用户授权且 token 权限正确后执行受控 publish，不得直接 dispatch workflow。

## 74. 新坑：受控远端写入失败时也要返回脱敏 JSON，避免恢复流程丢失证据

- 坑点：触发条件、现象、影响范围：`publish-phase2-github-api-source.ps1 -Execute -NoFail` 在 PAT contents 写权限不足时，旧行为会直接抛出异常并中断，调用方只能看到命令失败和 stderr，不能稳定解析 `ExecutionSucceeded=false`、失败 endpoint、是否尝试过 GitHub mutation 等字段。影响范围是 Phase 2 source publish 执行失败后的自动恢复和日志归档；不涉及实际 workflow dispatch、真机、签名或 WDA endpoint。
- 根因：脚本只把 dry-run blocker 做成报告对象，真实执行阶段的 `Read-GitHubToken` 和 `Publish-Phase2GitHubApiSource` 异常没有进入 report 模型；`-NoFail` 只能绕过 preflight blocker 的非零退出，不能处理执行期异常。
- 处理：新增 `Add-Phase2GitHubApiSourcePublishExecutionFailure`，执行失败时把脱敏错误写入 `ExecutionResult`、`BlockingIssues` 和 `NextActions`。读取 token 失败标记 `AttemptedGitHubMutation=false`；GitHub API 发布失败标记 `AttemptedGitHubMutation=true`。无 `-NoFail` 时仍以非零退出保留严格失败语义。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-github-api-publish-source-tests.ps1` 覆盖失败报告和 token-like 文本脱敏。真实执行 `publish-phase2-github-api-source.ps1 -TargetRepo 'ds0515/0511_Appium_WDA' -Ref 'lobster-wda-cloud-resign' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -Execute -ConfirmPublish 'publish ds0515/0511_Appium_WDA lobster-wda-cloud-resign' -AsJson -NoFail` 返回 exit 0 的 JSON，其中 `ExecutionResult.ExecutionSucceeded=false`，错误为 `POST /repos/ds0515/0511_Appium_WDA/git/blobs` 的 403，未输出 token。随后 `report-phase2-remote-source-state.ps1 ... -AsJson -NoFail` 仍返回 `RemoteRefFound=false`。
- 下次动作：如果受控 publish 失败，优先解析 JSON 中的 `ExecutionResult`，再跑 remote source state 确认是否产生远端半成品；不要仅凭进程退出码或裸 stderr 判断是否可以继续 dispatch。

## 75. 新坑：手动更新 PAT 权限后必须用实际写入验证，不能只看 repo push/admin

- 坑点：触发条件、现象、影响范围：用户在 GitHub 页面表示已更新权限后，重新执行 `publish-phase2-github-api-source.ps1 -Execute -NoFail`，仍在 `POST /repos/ds0515/0511_Appium_WDA/git/blobs` 返回 HTTP 403，message 为 `Resource not accessible by personal access token`。脱敏检查 `github.txt` 只识别到 1 个 fine-grained PAT，排除了“脚本读到旧 token”的常见原因。影响范围仍是 Phase 2 云端最小源发布；未创建 `lobster-wda-cloud-resign` 远端分支，不能 dispatch workflow。
- 根因：未定。当前证据说明 repo inventory 里的 `push/admin=true` 不是 Git database 写入权限的充分证明；fine-grained PAT 的 repository selection 或 `Contents: Read and write` 很可能仍未对当前 token 生效。Codex in-app browser 插件本次连接 GitHub 页面时在 runtime setup 阶段超时，无法可靠代替用户完成页面操作。
- 处理：继续以真实 GitHub API 写入结果作为唯一放行证据；失败时保留结构化 JSON。不要因为账号 scope 能看到 repo 就跳过 source publish，也不要直接进入 dispatch。
- 验证：`github.txt` 脱敏统计显示 1 个 fine-grained PAT；`report-github-actions-account-scope.ps1 -KeepRepo 'ds0515/0511_Appium_WDA' -TokenPath ... -AsJson -NoFail` 返回 repo 可见且 `PushPermission=true`、`AdminPermission=true`；真实 source publish 仍返回 `ExecutionResult.ExecutionSucceeded=false` 和 Git blob 403；`report-phase2-remote-source-state.ps1 ... -AsJson -NoFail` 返回 `RemoteRefFound=false`。
- 下次动作：在 GitHub token 编辑页重新确认目标 token 的 Repository access 包含 `ds0515/0511_Appium_WDA`，Repository permissions 中 `Contents` 为 `Read and write`，`Workflows` 为 `Read and write`，`Actions` 为 `Read and write`，最后点击页面底部保存/更新按钮；保存后先重跑受控 publish，再跑 remote source state。

## 76. 新坑：切换到新仓库时，受控发布确认串不能写死旧 repo，否则会掩盖真实的 404/权限阻断

- 坑点：触发条件、现象、影响范围：用户把 Phase 2 云端目标从 `ds0515/0511_Appium_WDA` 切到 `0516_WDA` 后，`report-phase2-cloud-gate.ps1 -TargetRepo 'ds0515/0516_WDA' ...` 的 source publish 子报告仍出现旧仓库硬编码 blocker：`TargetRepo must exactly equal ds0515/0511_Appium_WDA for Phase 2 source publication.`，同时 `ExpectedConfirmPublish` 也仍是旧仓库确认串。这样会把真正的远端问题掩盖掉。影响范围是 Phase 2 源发布门禁排序和恢复判断；不涉及真机、签名、WDA endpoint 或 token 内容本身。
- 根因：`publish-phase2-github-api-source.ps1` 的 `New-Phase2GitHubApiSourcePublishReport` 把 `ExpectedConfirmPublish` 和 repo 保护条件写死为旧仓库名，而不是根据显式传入的 `TargetRepo` 生成。结果是仓库切换后，脚本先被本地硬编码阻断，无法准确暴露 GitHub 侧的真实状态。
- 处理：将受控确认串改为跟随 `TargetRepo` 和 `Ref` 动态生成，只保留 `Ref` 的固定门禁；移除“必须等于旧仓库”这一条本地 blocker。这样在切换到新仓库时，source publish 报告可以继续保留显式确认保护，同时把真实的 repo 可见性或权限问题暴露出来。
- 验证：先在 `test\phase2-github-api-publish-source-tests.ps1` 新增 `ds0515/0516_WDA` 场景，复现 `ExpectedConfirmPublish` 仍返回旧仓库的 RED；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-github-api-publish-source-tests.ps1`、`.\test\phase2-cloud-gate-tests.ps1`、`.\test\phase2-cloud-dispatch-plan-tests.ps1` 均通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-cloud-gate.ps1 -TargetRepo 'ds0515/0516_WDA' -Ref 'lobster-wda-cloud-resign' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -RunnerLabelsJson 'macos-15' -AsJson -NoFail` 后，source publish 不再报旧仓库硬编码 blocker，而是准确暴露 `Target repo is not visible to the current GitHub token: ds0515/0516_WDA` 和 404 类远端阻断。
- 下次动作：切换云端目标仓库时，先跑 source publish dry-run，确认 `ExpectedConfirmPublish` 与目标 repo 一致；若随后出现 404 或 token 可见性问题，优先处理仓库存在性和 PAT repository selection，而不是回头误修本地确认串。

## 77. 新坑：切换默认目标仓库时，cleanup 的默认保护仓库也要一起切，否则会把“保留仓库”保护在旧 repo 上

- 坑点：触发条件、现象、影响范围：把 Phase 2 默认目标仓库从 `ds0515/0511_Appium_WDA` 切到 `ds0515/0516_WDA` 后，`cleanup-github-actions-account-scope.ps1` 已改为保护新仓库，但相邻测试仍把旧仓库当作“默认保留仓库”。结果 `github-actions-cleanup-tests.ps1` 在 protected-repo 断言上失败，暴露出“目标仓库切换了，但 destructive cleanup 保护对象还停留在旧仓库”的风险。影响范围是 GitHub Actions cleanup 的误删保护；不涉及真机、签名、WDA endpoint 或 token 内容本身。
- 根因：默认目标仓库涉及两类语义：一类是 cloud build/report 的 `TargetRepo`，另一类是 cleanup 的 `ProtectedRepo`/`KeepRepo`。如果只改前者，不同步后者和对应测试，恢复时会继续把旧仓库作为默认保护对象，和当前“保留新仓库”的目标不一致。
- 处理：把 `cleanup-github-actions-account-scope.ps1`、`cleanup-github-actions-legacy-repos.ps1`、`report-github-actions-account-scope.ps1` 等脚本的默认保留/保护仓库切到 `ds0515/0516_WDA`，并同步更新 `github-actions-cleanup-tests.ps1` 的 protected-repo 测试数据。
- 验证：先新增 `test\phase2-default-target-repo-tests.ps1`，确认一组 Phase 2 关键脚本默认仓库应为 `ds0515/0516_WDA`，初次运行在 `check-phase2-readiness.ps1` 处 RED；批量修复默认值后，`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-default-target-repo-tests.ps1` 通过。相邻验证 `.\test\github-actions-cleanup-tests.ps1`、`.\test\github-actions-legacy-cleanup-tests.ps1`、`.\test\phase2-cloud-gate-tests.ps1`、`.\test\phase2-github-api-publish-plan-tests.ps1`、`.\test\phase2-readiness-tests.ps1`、`.\test\native-wda-goal-script-tests.ps1` 通过。
- 下次动作：以后只要切换“当前保留/目标仓库”，先同时检查三类默认值是否一致：`TargetRepo`、`KeepRepo/ProtectedRepo`、`continue-native-wda-goal.ps1` 的默认 `Repo`；再跑默认值回归测试，避免云端目标、cleanup 保护和后续命令预览各自指向不同仓库。

## 78. 新坑：新仓库 404 时，cloud gate 不能只说“确认 repo 存在”，还要给出直接仓库 URL 和建仓 URL

- 坑点：触发条件、现象、影响范围：当 Phase 2 目标切到 `ds0515/0516_WDA` 且当前 PAT 仍返回 404/不可访问时，旧版 `report-cloud-actions-scope.ps1` 只给出抽象提示：确认 repo 存在并检查 fine-grained PAT 权限。长期恢复时，操作者还要自己再拼仓库 URL、再找新建仓库页面，来回试错成本高。影响范围是 Phase 2 Cloud gate 的人工排障入口；不涉及真机、签名、WDA endpoint 或 token 内容本身。
- 根因：404 分类 `repo_not_found_or_inaccessible` 只输出概念性 remediation hint，没有把“查看目标仓库页面”和“如果仓库未创建则进入新建仓库页面”这两个下一步动作结构化带出来。
- 处理：在 `report-cloud-actions-scope.ps1` 的 404 分类中，追加 `Target repo URL: https://github.com/<owner>/<repo>` 和 `If <owner>/<repo> has not been created yet, create it first: https://github.com/new?name=<repo>` 两条 next action；保留原有 PAT repository selection / private repo 权限提示。
- 验证：先在 `test\cloud-actions-scope-report-tests.ps1` 为 404 场景新增 direct repo URL 和 create-repository URL 断言，得到 RED；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\cloud-actions-scope-report-tests.ps1`、`.\test\phase2-cloud-publish-plan-tests.ps1`、`.\test\phase2-cloud-gate-tests.ps1` 通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-cloud-actions-scope.ps1 -TargetRepo 'ds0515/0516_WDA' -Ref 'lobster-wda-cloud-resign' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -RunnerLabelsJson 'macos-15' -AsJson -NoFail` 后，`NextActions` 现在明确包含 `https://github.com/ds0515/0516_WDA` 和 `https://github.com/new?name=0516_WDA`。
- 下次动作：只要 Cloud gate 对新目标 repo 返回 404，先按报告里的 direct repo URL 验证仓库是否真实存在；若不存在，直接用 create-repository URL 创建同名仓库，再回到 PAT repository selection 和 source publish dry-run。

## 79. 新坑：repo 404 的具体 remediation 不能停在 cloud scope 子报告，顶层 cloud gate 也要优先透传

- 坑点：触发条件、现象、影响范围：即使 `report-cloud-actions-scope.ps1` 已经在 404 场景输出了目标仓库 URL 和建仓 URL，真实 `report-phase2-cloud-gate.ps1 -TargetRepo 'ds0515/0516_WDA' ... -AsJson -NoFail` 的顶层 `NextRequiredAction` 仍可能停在泛化文本，例如 “Resolve the blockers before using any GitHub API publication path.” 或 “Confirm the target repository and remote name, then publish only SuggestedStagePaths.”。这会把当前最前置的“仓库不存在 / PAT 未授权”问题重新埋回 publish/remote 方向。影响范围是 Phase 2 顶层门禁的下一步动作排序；不涉及真机、签名、WDA endpoint 或 token 内容本身。
- 根因：中间两层报告各自吞掉了更具体的下游 next actions。`report-phase2-github-api-publish-plan.ps1` 在 blocked 场景默认只给泛化的 “Resolve the blockers...”；`report-phase2-cloud-publish-plan.ps1` 即使拿到了 cloud scope 的 404 remediation，也会先把“确认 remote / publish SuggestedStagePaths”放到前面。最终顶层 cloud gate 拿到的第一条动作仍然不是 repo/PAT 事实确认。
- 处理：先让 `report-phase2-github-api-publish-plan.ps1` 在 blocked 场景优先保留下游 `CloudPublishPlanReport.NextActions`；再让 `report-phase2-cloud-publish-plan.ps1` 在 `GitHubApiFailureKind=repo_not_found_or_inaccessible` 时，把 cloud scope 的 repo/PAT remediation 排到本地 push/remote 建议前面；`publish-phase2-github-api-source.ps1` 和 `report-phase2-cloud-gate.ps1` 继续优先透传上游最具体的 next action。
- 验证：先在 `test\phase2-github-api-publish-plan-tests.ps1`、`test\phase2-github-api-publish-source-tests.ps1`、`test\phase2-cloud-gate-tests.ps1`、`test\phase2-cloud-publish-plan-tests.ps1` 中新增对 repo URL / create-repository URL 和 next-action 排序的断言，分别得到 RED；修复后重跑上述四个测试全部通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-cloud-gate.ps1 -TargetRepo 'ds0515/0516_WDA' -Ref 'lobster-wda-cloud-resign' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -RunnerLabelsJson 'macos-15' -AsJson -NoFail` 后，顶层 `NextRequiredAction` 现已直接变为 `Confirm that ds0515/0516_WDA exists under the intended GitHub owner, and that the fine-grained PAT includes this repository with Contents read/write and Actions access.`。
- 下次动作：当顶层 cloud gate 首先指出 repo/PAT 404 问题时，先解决仓库存在性和 PAT repository selection；在 `NextRequiredAction` 不再指向 repo/PAT 之前，不要切回 remote、publish 或 dispatch 排障。

## 80. 新坑：把 workflow 只发布到非默认分支，并不能让 GitHub `workflow_dispatch` 变为可调度

- 坑点：触发条件、现象、影响范围：对新仓库 `ds0515/0516_WDA` 执行 `publish-phase2-github-api-source.ps1 -Execute` 后，`report-phase2-remote-source-state.ps1` 已确认 `lobster-wda-cloud-resign` 分支具备最小 Phase 2 源集，且 `.github/workflows/wda-ios-unsigned-package.yml` 在该 ref 上可读、包含 `workflow_dispatch`、支持 `native_host`。但 `report-cloud-actions-scope.ps1` 仍返回 `TargetWorkflowState=missing`、`WorkflowCount=0`，顶层 cloud gate 继续阻塞 dispatch。影响范围是新建 GitHub 仓库上的 Phase 2 云端编译入口判断；不涉及真机、签名、安装、WDA endpoint 或敏感凭据输出。
- 根因：基于 GitHub 官方文档和当前仓库实测的最小解释是：`workflow_dispatch` 要可手动触发，workflow 文件必须位于仓库默认分支；仅存在于 `lobster-wda-cloud-resign` 这类非默认分支时，仓库级 workflow 列表不会把它注册为可调度 workflow。当前证据包括：远端 ref 级别读取成功、仓库级 workflow summary 仍为空，以及 GitHub Docs《Manually running a workflow》《Triggering a workflow》都说明 `workflow_dispatch` 只在 workflow 文件位于默认分支时可触发。
- 处理：保留现有安全 gate，不放松成“只要远端 ref 上有 workflow 文件就允许 dispatch”。改为在 `report-cloud-actions-scope.ps1` 中，当仓库级 workflow 缺失但目标 ref 上 workflow 文件已存在时，优先提示“先把 `.github/workflows/wda-ios-unsigned-package.yml` 放到默认分支”；同时让 `report-phase2-cloud-dispatch-plan.ps1` 和 `report-phase2-cloud-gate.ps1` 把这条具体 remediation 排到最前面，避免被泛化的 rerun 提示掩盖。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\publish-phase2-github-api-source.ps1 -TargetRepo 'ds0515/0516_WDA' -Ref 'lobster-wda-cloud-resign' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -Execute -ConfirmPublish 'publish ds0515/0516_WDA lobster-wda-cloud-resign' -AsJson -NoFail` 返回 `BootstrappedEmptyRepository=true`、`RemoteHeadSha=39e41a465e64857068fd67dc494d300c59a079f8`。随后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-remote-source-state.ps1 -TargetRepo 'ds0515/0516_WDA' -Ref 'lobster-wda-cloud-resign' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -AsJson -NoFail` 返回 `ReadyForRemoteSourceState=true`。再运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-cloud-actions-scope.ps1 -TargetRepo 'ds0515/0516_WDA' -Ref 'lobster-wda-cloud-resign' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -RunnerLabelsJson 'macos-15' -AsJson -NoFail` 仍返回 `TargetWorkflowState=missing`，但 `NextActions[0]` 已明确指向“放到默认分支”。相关回归测试：`test\cloud-actions-scope-report-tests.ps1`、`test\phase2-cloud-dispatch-plan-tests.ps1`、`test\phase2-cloud-gate-tests.ps1`、`test\phase2-cloud-publish-plan-tests.ps1` 通过。
- 下次动作：只要看到“远端 ref 上 workflow 已存在，但仓库级 `TargetWorkflowState=missing`”的组合，先检查默认分支上是否存在同名 workflow 文件，再考虑 dispatch；不要把这类问题误归因为 PAT、remote 404 或 workflow 文本本身缺少 `workflow_dispatch`。
## 81. 新坑：workflow 已注册且可 dispatch，但最小远端源码集仍可能完全不可编译
- 坑点：触发条件、现象、影响范围：在 `ds0515/0516_WDA` 上通过 `continue-native-wda-goal.ps1` 成功发起 validation-only 云构建后，run `25955258479` 的 job `76300645433` 在 `Build unsigned native WDA host app and IPA` 步骤失败，日志关键句是 `xcodebuild: error: 'WebDriverAgent.xcodeproj' does not exist.`。影响范围是 Phase 2 云端 unsigned native host 构建；不涉及真机安装、签名密钥或账号内容。
- 根因：此前发布到远端的最小源码集只够通过 repo 可见性、workflow 注册和 dispatch 检查，但不包含 `WebDriverAgent.xcodeproj`、`Configurations`、`PrivateHeaders`、`WebDriverAgentLib`、`WebDriverAgentRunner`、`WebDriverAgentTests/IntegrationApp` 等真实编译依赖。
- 处理：将 `report-phase2-cloud-publish-candidate.ps1` 从手写 17 路径改为基于允许根目录的 tracked 文件枚举，形成 425 个 create/update 路径和 7 个 delete 路径；再通过 `publish-phase2-github-api-source.ps1` 重发到 `ds0515/0516_WDA@lobster-wda-cloud-resign`。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-cloud-publish-candidate-tests.ps1`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-remote-source-state.ps1 -TargetRepo 'ds0515/0516_WDA' -Ref 'lobster-wda-cloud-resign' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -AsJson -NoFail`；远端最终 `RemotePathCount=425`、`RemoteRequiredPresentCount=425`、`MissingRequiredPaths=[]`。
- 下次动作：只要云端失败出现“缺 project / 缺 scheme / 缺头文件 / 缺 xcconfig”这类编译前错误，优先检查 candidate/source publish 文件集，而不是回头重复排 PAT、repo、workflow 注册。

## 82. 新坑：大体积 GitHub API 请求体不能通过 Windows 进程环境变量内联传给 Node fallback
- 坑点：触发条件、现象、影响范围：当 Phase 2 远端源码集扩到 425 个 create/update 路径后，`publish-phase2-github-api-source.ps1 -Execute` 在本地报错 `Exception calling "SetEnvironmentVariable" with "3" argument(s): "Environment variable name or value is too long."`。影响范围是 GitHub Git Database API 发布链路；不涉及 token 权限本身。
- 根因：`Invoke-GitHubJson` 把 blob/tree/commit 请求体 JSON 直接写入 `CODEX_GITHUB_API_BODY` 进程环境变量；较大的 base64 内容会超过 Windows 环境变量长度限制。
- 处理：把 Node fallback 的请求体传输改为临时文件 `CODEX_GITHUB_API_BODY_FILE`，Node 侧从文件读取 JSON；执行结束后删除临时文件，避免残留。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-github-api-publish-source-tests.ps1`；随后重新执行 `publish-phase2-github-api-source.ps1 -Execute ...` 成功生成远端提交 `1fd57b5cdfc9fb4dd99437f87726ec31d1492924`。
- 下次动作：只要 GitHub API fallback 需要传大 JSON 或 base64，默认不要走环境变量内联；优先用临时文件或 stdin 传输。

## 83. 新坑：GitHub Actions artifact 下载在 Windows PowerShell HTTPS 接收阶段也可能失败
- 坑点：触发条件、现象、影响范围：run `25955676174` 云构建已经 `conclusion=success`，但 `continue-native-wda-goal.ps1` 在下载 artifact 时失败，错误为 `Invoke-WebRequest : 基础连接已经关闭: 接收时发生错误。`。影响范围是 validation-only 对 unsigned IPA 的回收和本地校验；不影响 GitHub 端构建本身。
- 根因：`Download-Artifact` 仍然直接依赖 `Invoke-WebRequest` 下载 `archive_download_url`，没有像 GitHub JSON API 那样提供 Node fallback；Windows PowerShell HTTPS/SChannel 在接收 artifact ZIP 时不稳定。
- 处理：为 artifact 下载新增 `Invoke-GitHubDownloadToFile` / `Invoke-GitHubDownloadToFileViaNode`；当 `Invoke-WebRequest` 失败时，自动回退到 Node `fetch` 下载 ZIP，再继续 `Expand-Archive` 和 IPA 选择。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\native-wda-goal-script-tests.ps1`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\continue-native-wda-goal.ps1 -Repo 'ds0515/0516_WDA' -Workflow 'wda-ios-unsigned-package.yml' -Ref 'lobster-wda-cloud-resign' -BuildPackageKind 'native_host' -RunnerLabelsJson 'macos-15' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -ValidateIpaOnly -SkipRemoteHeadCheck -AllowDirtyCloudBuild`；最终 run `25955753277` 成功，输出 `Unsigned IPA: ...\LobsterWDAHost.unsigned.ipa` 和 `Native host IPA verified: CFBundleIdentifier=app.honey4212.crystal5671`。
- 下次动作：如果 cloud run 已成功但本地回收 artifact 失败，不要误判为构建失败；先区分是 run 失败还是 artifact 下载失败，再决定修复脚本还是重发 workflow。

## 84. 新坑：已有 ready artifact 时，Phase 2 readiness 不能继续把 self-hosted cloud gate 当作当前首要阻塞
- 坑点：触发条件、现象、影响范围：当 `report-native-host-artifacts.ps1` 已确认存在可用的 native-host IPA，而 `check-phase2-readiness.ps1` 仍以默认 self-hosted runner 标签读取 cloud scope 时，顶层 `NextRequiredGate` 继续返回 `Cloud`，`NextRequiredAction` 指向“Register or start a self-hosted macOS runner...”，掩盖了当前更直接的签名和安装阻塞。影响范围是 Phase 2 顶层推进顺序和恢复上下文后的下一步动作判断；不涉及 GitHub token 内容、真机写操作或签名私密材料输出。
- 根因：readiness 逻辑把 cloud/account/repo-safety build-dispatch gate 无条件排在 artifact、signing、installed-state 之前；即使已经有 `ArtifactReady=true` 的现成构建产物，也仍把“重新具备 dispatch 能力”当作 Phase 2 当前必经门槛。
- 处理：在 `check-phase2-readiness.ps1` 中新增“artifact evidence already ready”分支：当 `ArtifactReady=true` 时，保留 cloud/self-hosted 状态字段，但不再把 cloud/account/repo-safety 作为当前 Phase 2 blocker 和 `NextRequiredGate`；`ReadyForPhase2WirelessValidation` 改为允许“ready artifact 或当前 cloud dispatch 就绪”二选一满足 build-input 条件。
- 验证：先新增 `test\phase2-readiness-tests.ps1` 用例，覆盖“self-hosted runner 不可用但 ready artifact 已存在”场景，得到 RED：`Expected 'Signing', got 'Cloud'`；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -AsJson -NoFail` 后，顶层结果从 `NextRequiredGate=Cloud` 改为 `NextRequiredGate=Signing`，`BlockingIssues` 只保留 installed/signing 阻塞。
- 下次动作：只要 `ArtifactReady=true` 且已有现成 IPA 可继续签名/安装，就优先处理 signing、installed-state、runtime、wireless endpoint；不要因为 self-hosted runner 当前离线就回退成 cloud gate 优先。

## 85. 新坑：`NextRequiredGate` 已切到当前阻塞后，`NextActions` 顺序也必须同步，否则会继续误导人工下一步
- 坑点：触发条件、现象、影响范围：在 #84 修复后，真实 `check-phase2-readiness.ps1` 已把顶层 gate 改成 `Signing`，但 `NextActions[0]` 仍然保留为 “Install the signed native host or runner package...”，只有第二条才是提供 Apple Development profile。这会让恢复上下文后的操作者先去做尚不可执行的安装动作。影响范围是 Phase 2 顶层协作顺序和人工执行入口；不涉及 token、证书内容、真机写操作或云端构建本身。
- 根因：`NextRequiredGate` / `NextRequiredAction` 在函数末尾按 gate 顺序计算，但 `NextActions` 仍按各子报告原始收集顺序输出，没有把当前首要 gate 的动作前置。
- 处理：在 `check-phase2-readiness.ps1` 中新增 `Move-PreferredReadinessItemToFront`，在返回结果前把 `NextRequiredAction` 移到 `NextActions[0]`，其余动作保持去重后的原相对顺序。
- 验证：先在 `test\phase2-readiness-tests.ps1` 为 “artifact ready + self-hosted unavailable + signing blocked” 和 “artifact ready + signing ready + installed blocked” 两个场景新增断言，确认 `NextActions[0] == NextRequiredAction`，得到 RED；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -AsJson -NoFail` 后，`NextActions[0]` 现已与 `NextRequiredAction` 一致，先提示提供 development profile，再提示后续安装。
- 下次动作：凡是修改 Phase 2 gate 排序或 blocker 前后关系时，同时检查 `NextActions` 的首项是否仍与 `NextRequiredGate` 对齐；不要只修标题，不修动作列表。

## 86. 新坑：扩大 signing 搜索根时，同一份 distribution profile 的解包拷贝会制造噪声，但不代表漏掉了 development profile
- 坑点：触发条件、现象、影响范围：为确认“是不是默认搜索根漏掉了 development profile”，把 `report-ios-signing-profiles.ps1` 的 `-SearchRoot` 扩到 `D:\2026_soft` 后，报告扫描到 16 份 `mobileprovision`，其中大量来自 IPA 解包目录里的 `embedded.mobileprovision`。旧版 summary 会把同一份 distribution profile 的相同失败原因重复输出很多次，容易让人误以为有更多不同候选未排查。影响范围是 Phase 2 签名阻塞诊断质量；不涉及 token、证书内容输出、真机写操作或云端构建。
- 根因：脚本会按文件逐个解析 profile，但 `ProfileFailureSummaries` 和聚合 blocker 没有按 `Summary` 去重；当同一个 UUID/Name 的 distribution profile 被复制到多个解包目录时，会重复堆叠同一失败说明。
- 处理：在 `report-ios-signing-profiles.ps1` 中保留逐文件 `Profiles` 明细，但对 `ProfileFailureSummaries` 按 `Summary` 去重，再生成聚合 `BlockingIssues`。这样既不丢路径证据，也不让总览被重复噪声淹没。
- 验证：先在 `test\ios-signing-profile-report-tests.ps1` 新增“同一个 non-ready profile 被发现两次”场景，断言 `ProfileFailureSummaries` 去重且聚合 blocker 里同一 summary 只出现一次，得到 RED；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-signing-profile-report-tests.ps1` 通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-signing-profiles.ps1 -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -SearchRoot 'D:\2026_soft' -AsJson -NoFail` 后，16 个 profile 仍全部可见，但 summary 只剩两类失败：目标 bundle/UDID 的 distribution profile，以及 `CycommGroupAppProfile` 的 bundle 不匹配 distribution profile。
- 下次动作：当怀疑默认搜索根漏掉 profile 时，可以临时把 `-SearchRoot` 扩到更大目录做只读排查；如果扩大后 summary 仍只剩 distribution 类失败，就不要继续把问题归因为“脚本没搜到”，而应直接回到“缺 Apple Development profile”的真实阻塞。

## 87. 新坑：默认 `MobileProvisionPath` 指向旧 distribution profile 时，需要显式开启自动解析，否则后续链路会一直咬住旧文件
- 坑点：触发条件、现象、影响范围：`continue-native-wda-goal.ps1` 原先默认把 `MobileProvisionPath` 固定到 `D:\2026_soft\0430_WS\0423_iPhone11\cert.mobileprovision`。即使后续把新的 development profile 放进 Apple 默认目录或其他搜索目录，脚本如果仍只使用这个固定路径，就会继续预检失败在旧 distribution profile 上。影响范围是 Phase 2 的 preflight、签名和安装入口；不涉及 token、密码、p12 内容或真机高风险自动选择。
- 根因：脚本原先没有“从候选目录中自动选择唯一 Phase 2-ready profile”的能力，只会验证调用者传入的单一路径。
- 处理：在 `continue-native-wda-goal.ps1` 中新增 `-AutoResolveMobileProvisionPath` 和 `-ProfileSearchRoot`。开启后，脚本会扫描显式 `MobileProvisionPath` 与搜索根中的 `*.mobileprovision`/`*.provisionprofile`，自动选择唯一的 Phase 2-ready development profile；如果 0 个或多个都满足条件，则明确报错，不静默乱选。
- 验证：先在 `test\native-wda-goal-script-tests.ps1` 新增三类断言，覆盖“唯一 ready profile 自动选中”“0 个 ready profile 明确报错”“多个 ready profile 拒绝猜测”，得到 RED；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\native-wda-goal-script-tests.ps1` 通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\continue-native-wda-goal.ps1 -Repo 'ds0515/0516_WDA' -Workflow 'wda-ios-unsigned-package.yml' -Ref 'lobster-wda-cloud-resign' -BuildPackageKind 'native_host' -RunnerLabelsJson 'macos-15' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -DeviceUdid '00008030-0001598021E2802E' -ProfileSearchRoot 'D:\2026_soft' -AutoResolveMobileProvisionPath -PreflightOnly -SkipRemoteHeadCheck -AllowDirtyCloudBuild` 后，当前环境会直接报 `No Phase 2-ready Apple Development profile found...`，不再继续把旧 distribution profile 当作唯一候选。
- 下次动作：一旦 development profile 被导入到 Apple 默认目录或某个显式搜索根，优先用 `-AutoResolveMobileProvisionPath` 跑一次只读 preflight；如果提示 0 个 ready profile，说明材料本身不满足 Phase 2；如果提示多个 ready profile，再回到显式 `-MobileProvisionPath` 缩小歧义。

## 88. 新坑：指定 UDID 不在线时，Phase 2 应停在显式设备阻塞，不要误判成仓库、token 或 WDA 安装问题
- 坑点：触发条件、现象、影响范围：在 `ds0515/0516_WDA` 远端源已经 ready、顶层 readiness 仍停在 Phase 2 的情况下，重新运行只读检查后发现显式目标 UDID `00008030-0001598021E2802E` 不在当前设备列表中；`pymobiledevice3` 只看到另一台 `923c14b2a1ac17c78a0ef1720bbeaf921b40a981` 的 iPhone（同一设备同时有 USB/Network 两条记录）。这时 `check-phase2-readiness.ps1` 仍会同时列出签名、未安装 app 和设备不可见三类 blocker。影响范围是 Phase 2 真机入口判断；不涉及 token 内容、远端源发布、签名材料内容或自动切换到其他设备。
- 根因：Phase 2 明确要求高风险操作只能使用显式 UDID；当用户手动更换了连接设备、目标设备断开，或当前连上的不是目标手机时，设备发现脚本会按规则拒绝把别的可见设备当作候选继续执行。
- 处理：保持显式 UDID 约束，不自动改用 `923c14...`。同时把 `report-ios-device-readiness.ps1` 的 missing-device 提示补全为“当前可见 UDID 列表 + 重新连接目标机或明确提供新 UDID”，避免恢复上下文后继续把问题误判成 repo、token 或 WDA 安装故障。
- 验证：先在 `test\ios-device-readiness-report-tests.ps1` 为“目标 UDID 不在线但当前有其他设备在线”新增 RED 断言，要求 `NextActions` 同时包含 `currently visible UDIDs` 和 `provide a new explicit target UDID`；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-device-readiness-report-tests.ps1` 通过，相邻 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-device-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -AsJson -NoFail` 返回 `DeviceReady=false`、`MatchingDeviceCount=0`，且 `NextActions` 现已明确列出当前可见 UDID `923c14b2a1ac17c78a0ef1720bbeaf921b40a981`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -AsJson -NoFail` 仍返回 `NextRequiredGate=Signing`，同时 `BlockingIssues` 中包含 `Device: Target iPhone is not visible...`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-installed-wda-apps.ps1 -DeviceUdid '00008030-0001598021E2802E' -AsJson -NoFail` 仍返回 `AnyTargetInstalled=false`。
- 下次动作：每次准备做签名、安装或 `/status` 验证前，先跑显式 UDID 的 device readiness；如果 `MatchingDeviceCount=0`，立即停下，不要继续尝试安装、启动或把当前可见的其他设备当作目标机。

## 89. 新坑：当显式目标 UDID 不在线但当前有其他 iPhone 可见时，顶层 gate 不能继续优先做签名
- 坑点：触发条件、现象、影响范围：在 ready artifact 已存在、远端源也已 ready 的情况下，如果 `report-ios-device-readiness.ps1` 明确显示“目标 UDID 不在线，但当前还有其他 iPhone 可见”，旧版 `check-phase2-readiness.ps1` 仍会因为签名 profile 尚未准备好而把 `NextRequiredGate` 保持在 `Signing`。这样恢复上下文后，操作者会继续围绕旧 UDID 做 development profile 判断，而不是先确认当前到底要操作哪台手机。影响范围是 Phase 2 顶层入口排序；不涉及 token、签名内容输出、自动改用其他设备或真机写操作。
- 根因：旧的 gate 顺序固定为 `Artifact -> Signing -> Device -> InstalledApps`，没有区分“目标机离线但别的 iPhone 在线”的设备歧义场景；而签名检查本身又依赖显式 UDID，因此在设备身份未确认前继续把签名放在前面会放大误导。
- 处理：在 `check-phase2-readiness.ps1` 中增加窄条件：当 `DeviceReady=false`、`MatchingDeviceCount=0` 且 `DeviceCount>0` 时，先把 `NextRequiredGate` 切到 `Device`，要求先重连目标机或明确给出新的显式 UDID；只有设备身份重新确认后，才继续把签名作为下一关。
- 验证：先在 `test\phase2-readiness-tests.ps1` 新增 RED 场景，覆盖“cloud ready + signing blocked + 目标 UDID 不在线但其他设备在线”，断言 `NextRequiredGate='Device'`，得到 `Expected 'Device', got 'Signing'`；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -AsJson -NoFail` 后，顶层结果现已变为 `NextRequiredGate=Device`、`NextRequiredAction=Connect the target iPhone...`，同时 `NextActions` 第一项也与之对齐，并保留后续签名与安装动作。
- 下次动作：只要 `MatchingDeviceCount=0` 且 `DeviceCount>0`，先确认目标设备身份，不要继续为旧 UDID 申请或筛选 development profile；确认完 UDID 后，再回到 signing / install / runtime 顺序。

## 90. 新坑：当目标设备身份都还没确认时，不应把 “未安装 app” 继续作为顶层 blocker 噪声
- 坑点：触发条件、现象、影响范围：在 `NextRequiredGate` 已经切到 `Device` 之后，旧版 `check-phase2-readiness.ps1` 仍会把 `Installed apps: Neither target WDA bundle is installed...` 混进顶层 `BlockingIssues`，同时把安装动作混进 `NextActions`。如果目标 UDID 当前根本不在线，这种“未安装”结论并不可靠，只会让恢复上下文后的操作者在设备身份未确认前继续想当然地推进安装。影响范围是 Phase 2 顶层阻塞汇总质量；不涉及 installed-app 明细报告本身、签名内容、token 或真机写操作。
- 根因：`InstalledAppsReport` 的顶层 blocker 汇总只看 `InstalledAppsGateReady`，没有同时要求 `DeviceReady=true`；而 installed-app 报告本身在设备缺席时通常只能给出“没查到 app”而不是可信的设备在场结论。
- 处理：在 `check-phase2-readiness.ps1` 中把 installed-app 顶层 blocker/next-action 的加入条件收紧为 `DeviceReady=true` 且 `InstalledAppsGateReady=false`。这样设备缺席时，installed-app 仍保留在 `InstalledAppBlockingIssues` / `InstalledAppNextActions` 明细字段里，但不会污染当前最前置的顶层阻塞。
- 验证：先在 `test\phase2-readiness-tests.ps1` 把 blocked 场景改成 RED：当 `Device` 不可见时，断言顶层 `BlockingIssues` 和 `NextActions` 不再包含 installed-app 结论；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -AsJson -NoFail` 后，顶层 `BlockingIssues` 现在只剩 `Device` 和 `Signing`，而 `InstalledAppBlockingIssues` / `InstalledAppNextActions` 仍保留在结构化字段中供后续阶段使用。
- 下次动作：如果 `DeviceReady=false`，先只修设备身份，不要根据 installed-app 顶层摘要继续做安装判断；等目标 UDID 在线后，再重新读取 installed-app gate 并决定是否需要安装当前签名包。

## 91. 新坑：仅把 `NextRequiredAction` 挪到首位还不够，当前 gate 的整组动作都要完整前置且保持去重
- 坑点：触发条件、现象、影响范围：在 #89、#90 之后，顶层 `NextRequiredGate` 已正确切到 `Device`，但旧版排序只会把单个 `NextRequiredAction` 移到 `NextActions[0]`。结果“当前可见 UDID 列表”和 `tidevice` 失败提示仍排在 signing 动作后面，恢复上下文后人工会先看到签名，再看到完整设备细节；第一次扩展整组前置后，还出现了 `Connect the target iPhone...` 被重复两次的问题。影响范围是 Phase 2 顶层协作入口；不涉及真机写操作、签名材料内容或 token。
- 根因：原来的前置逻辑只支持单条动作；把“当前 gate 的整组动作”与 `NextRequiredAction` 简单拼接后，又会因为首条动作重复而产生重复项。
- 处理：把排序逻辑扩展为按当前 `NextRequiredGate` 取整组 `NextActions` 并统一前置，同时对首选动作集合先做去重。这样 `Device` gate 会先完整给出“重连目标机 -> 当前可见 UDID -> 工具失败提示”，再进入 signing 动作，而且不会重复首条设备动作。
- 验证：先在 `test\phase2-readiness-tests.ps1` 为 device-first 场景新增 RED 断言，要求 `currently visible UDIDs` 出现在 signing 动作前，并且 `Connect the target iPhone...` 只出现一次；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -AsJson -NoFail` 后，顶层 `NextActions` 现已按 `Device` 整组前置，顺序为“Connect... -> currently visible UDIDs... -> tidevice device list failed... -> signing actions”，且没有重复的 `Connect...`。
- 下次动作：只要切换 `NextRequiredGate` 的优先级，除了校验 `NextActions[0]` 外，还要检查当前 gate 的整组动作是否完整前置、顺序是否仍然合理、是否引入了重复项。

## 92. 新坑：结构化 readiness 已切到 Device gate 时，人类可读摘要也必须同步压制 installed-app 细节噪声
- 坑点：触发条件、现象、影响范围：当 `check-phase2-readiness.ps1` 的结构化结果已经把顶层 gate 切到 `Device`，且 `DeviceReady=false`、显式目标 UDID 当前不在线时，终端摘要仍会提前打印 `Native host installed`、`Runner installed`、`Installed app blockers`、`Installed app next actions`。这会把“设备身份未确认”误读成“安装状态已确认但缺 app”，影响 Phase 2 长期恢复后的人工下一步判断。
- 根因：顶层 JSON 聚合已经对 installed-app blocker 做了 `DeviceReady=true` 的收紧，但 `Write-Phase2ReadinessReport` 仍无条件展开 installed-app 细节，导致摘要层和结构化 gate 脱节。
- 处理：只在 `DeviceReady=true` 时打印 installed-app 的细节字段；设备未就绪时仍保留 `Installed apps ready` 这个摘要布尔值，但不展开 `Installed apps target UDID`、`Native host installed`、`Runner installed`、`Any target installed`、`Installed target app count`、`Installed app blockers`、`Installed app next actions`。
- 验证：先在 `test\phase2-readiness-tests.ps1` 新增 RED 断言，要求 blocked rendered report 不再包含 `Native host installed: False`、`Runner installed: False`、`Installed app blockers:`、`Installed app next actions:`；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -TargetRepo 'ds0515/0516_WDA' -NoFail` 后，摘要里仍显示 `Installed apps ready: False`，但不再提前打印 installed-app 细节噪声。
- 下次动作：凡是修改 `NextRequiredGate`、顶层 blocker 汇总或 installed-app gate 条件时，同时检查 `Write-Phase2ReadinessReport` 的展示是否仍与当前 gate 一致；不要只修 JSON，不修人类可读摘要。

## 93. 新坑：artifact 已 ready 时，人类可读摘要也不应继续提前展开本地 native-host 构建工具链细节
- 坑点：触发条件、现象、影响范围：当 `ArtifactReady=true`，且 Phase 2 当前 gate 已经落在 `Device`、`Signing`、`InstalledApps` 或 `Complete` 时，终端摘要仍会提前打印 `Missing toolchain commands`、`PlistBuddy found`、`bash probe succeeded`、`Local native-host build blockers`、`Local native-host build next actions`。这会把“已有现成 IPA 可继续签名/安装/验证”的场景误读成“当前仍卡在 Windows 本地构建环境”，影响恢复上下文后的下一步动作判断。
- 根因：结构化 readiness 已经把 local build toolchain 仅保留为辅助状态，不再作为 artifact-ready 场景的顶层 blocker；但 `Write-Phase2ReadinessReport` 仍无条件展开本地构建工具链细节，导致摘要层和当前 gate 脱节。
- 处理：当 `ArtifactReady=true` 时，摘要层仍保留 `Ready for local native-host build` 这个状态位，但不再展开 `Missing toolchain commands`、`PlistBuddy found`、`bash probe succeeded`、`Local native-host build script ready`、`Local native-host build blockers`、`Local native-host build next actions`；只有在 `ArtifactReady=false` 时才打印这些细节，避免抢占当前 Phase 2 入口。
- 验证：先在 `test\phase2-readiness-tests.ps1` 的 “artifact ready + toolchain blocked” 场景新增 RED 断言，要求 rendered report 保留 `Ready for local native-host build: False`，但不再包含 `Missing toolchain commands:`、`Local native-host build blockers:`、`Local native-host build next actions:`；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -TargetRepo 'ds0515/0516_WDA' -NoFail` 后，摘要里仍显示 `Ready for local native-host build: False`，但不再提前展开本地构建工具链噪声。
- 下次动作：凡是修改 `ArtifactReady`、local build toolchain gate 或摘要输出时，同时检查 `Write-Phase2ReadinessReport` 是否仍把“已有可用 IPA”场景和“必须依赖本地构建”场景区分开；不要让辅助诊断细节重新盖过当前 Phase 2 gate。

## 94. 新坑：当前 gate 已经前移到 Signing 时，installed-app 仍应保留为结构化后续事实，但不应继续占用顶层 blocker 和摘要细节
- 坑点：触发条件、现象、影响范围：当目标设备已经在线、`ArtifactReady=true`，但 `SigningReady=false` 时，旧版 `check-phase2-readiness.ps1` 会同时把 `Installed apps: Neither target WDA bundle is installed...` 继续挂在顶层 `BlockingIssues`，并在摘要里提前展开 `Installed apps target UDID`、`Native host installed`、`Runner installed`、`Installed app blockers`、`Installed app next actions`。这会把“当前还卡在 development profile”误读成“签名和安装两个 gate 同时都要立刻处理”，影响 Phase 2 恢复后的下一步判断。
- 根因：installed-app 顶层 blocker 和摘要细节此前只收紧到了 `DeviceReady=true`，还没有继续对齐到 `SigningReady=true`。因此一旦设备恢复在线，installed-app 就会在 signing 尚未通过时重新提早冒出来，导致结构化当前 gate 与摘要层、顶层 blocker 再次脱节。
- 处理：把 installed-app 顶层 blocker/next-action 的加入条件继续收紧为 `DeviceReady=true` 且 `SigningReady=true` 且 `InstalledAppsGateReady=false`；同时 `Write-Phase2ReadinessReport` 只在 `DeviceReady=true` 且 `SigningReady=true` 时展开 installed-app 细节。`InstalledAppBlockingIssues` 和 `InstalledAppNextActions` 仍保留在结构化字段里，供 signing 通过后的下一阶段继续使用。
- 验证：先在 `test\phase2-readiness-tests.ps1` 的 “artifact ready + signing blocked + installed blocked” 场景新增 RED 断言，要求顶层 `BlockingIssues` 不再包含 `Installed apps:`，顶层 `NextActions` 不再包含安装动作，rendered report 只保留 `Installed apps ready: False`，但不再包含 `Installed app blockers:` 和 `Installed app next actions:`；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -TargetRepo 'ds0515/0516_WDA' -AsJson -NoFail` 后，当前结果已变为 `DeviceReady=true`、`NextRequiredGate=Signing`，顶层 `BlockingIssues` 只剩 signing，两条 `NextActions` 也只剩 signing；与此同时 `InstalledAppBlockingIssues` / `InstalledAppNextActions` 仍保留在结构化字段中。
- 下次动作：凡是当前 `NextRequiredGate` 仍早于 `InstalledApps` 时，都要同时检查顶层 blocker、顶层 next actions 和摘要细节有没有提前暴露 installed-app 噪声；不要只看 `InstalledAppsReady=false` 就把安装问题重新抬到当前 gate 前面。

## 95. 新坑：fallback 工具已经成功给出事实时，前一个工具失败应保留为诊断，不应继续占用 `NextActions`
- 坑点：触发条件、现象、影响范围：当前 Windows 环境下，`tidevice` 常出现 `device list failed with exit code 1` 或 `app list failed with exit code 1`，但随后 `pymobiledevice3` 已能成功返回目标设备或已安装 app 的事实。旧版只读报告仍会把这些 `tidevice` 失败直接塞进 `NextActions`，导致设备已 ready、或 app 缺失已被可靠证明时，动作列表里还混着与当前结论无关的次级工具失败噪声。影响范围是 `report-ios-device-readiness.ps1`、`report-ios-installed-wda-apps.ps1` 以及依赖它们的 Phase 2 顶层 readiness 排序。
- 根因：报告构造函数会无条件把 `ToolWarnings` 追加到 `NextActions`；一旦 fallback 成功，旧 warning 也会跟着成功报告一起返回，和真正当前该做的动作混在一起。
- 处理：为两个只读报告保留独立的 `ToolWarnings` 结构化字段；只有在完全拿不到可用事实时，才把这些 tool failures 继续放进 `NextActions`。如果后续 fallback 工具已经成功返回设备或 app 事实，则 `NextActions` 只保留当前真正需要执行的动作，不再混入前一个工具失败。
- 验证：先在 `test\ios-device-readiness-report-tests.ps1` 和 `test\ios-installed-wda-apps-report-tests.ps1` 分别新增 RED 断言，覆盖“tidevice 失败后 pymobiledevice3 成功”的场景，要求 `NextActions` 不再包含 `tidevice ... failed with exit code 1`；修复后重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-device-readiness-report-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-installed-wda-apps-report-tests.ps1` 和相邻 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 均通过。真实只读运行后，`report-ios-device-readiness.ps1` 现返回 `ToolWarnings=["tidevice device list failed with exit code 1."]` 且 `NextActions=[]`；`report-ios-installed-wda-apps.ps1` 现返回 `ToolWarnings=["tidevice app list failed with exit code 1."]` 且 `NextActions` 只剩安装动作。
- 下次动作：凡是多工具串联的 Phase 2 只读报告，都要区分“当前事实是否已可靠成立”和“前序工具是否失败”。如果 fallback 已成功，就把前序失败降级为诊断字段，不要继续放在 `NextActions` 里抢动作位。

## 96. 新坑：`ToolWarnings` 只存在 JSON 里还不够，人类可读只读报告也要能看见 fallback 诊断
- 坑点：触发条件、现象、影响范围：在把 `tidevice` 失败从 `NextActions` 降级到 `ToolWarnings` 之后，JSON 输出已经能保留这些诊断，但 `report-ios-device-readiness.ps1` 和 `report-ios-installed-wda-apps.ps1` 的非 JSON 输出仍然完全看不到它们。这样用户单独跑人类可读报告时，只能看到最终结论，看不到“为什么实际用了 pymobiledevice3 fallback”，诊断链路不完整。
- 根因：两个 `Write-*Report` 函数都只打印主结论、blocker 和 next actions，没有为 `ToolWarnings` 预留独立展示段落。
- 处理：在两个人类可读输出函数里增加 `Tool warnings:` 段落；当 `ToolWarnings` 非空时单独打印每条 warning，但仍不把它们重新放回 `NextActions`。这样既保留诊断上下文，又不重新污染当前动作列表。
- 验证：先在 `test\ios-device-readiness-report-tests.ps1` 与 `test\ios-installed-wda-apps-report-tests.ps1` 为 fallback 成功场景新增 RED 断言，要求 rendered report 包含 `Tool warnings:` 和对应的 `tidevice ... failed with exit code 1.`；修复后重跑这两个测试和相邻 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 全部通过。真实只读运行后，`report-ios-device-readiness.ps1 -NoFail` 现会打印 `Tool warnings: - tidevice device list failed with exit code 1.`，`report-ios-installed-wda-apps.ps1 -NoFail` 现会打印 `Tool warnings: - tidevice app list failed with exit code 1.`，同时 `Next actions` 仍只保留真正当前要做的动作。
- 下次动作：凡是给 Phase 2 只读报告新增结构化诊断字段时，都要同步检查人类可读输出是否也能看到这些诊断；不要让 JSON 和终端摘要再次脱节。

## 97. 新坑：顶层 readiness 摘要如果不透传子报告 `ToolWarnings`，恢复上下文后会误丢 fallback 诊断
- 坑点：触发条件、现象、影响范围：子报告 `report-ios-device-readiness.ps1` 和 `report-ios-installed-wda-apps.ps1` 已经能把 `tidevice` 失败保留在 `ToolWarnings`，单独运行时也会打印 `Tool warnings:`；但顶层 `check-phase2-readiness.ps1 -NoFail` 之前仍完全看不到这些 warning。这样恢复上下文后，只能看到最终 gate 结论，看不到设备和已安装 app 事实其实来自 `pymobiledevice3` fallback。影响范围是 Phase 2 顶层只读入口，不涉及 gate 顺序、签名结论或真机写操作。
- 根因：`New-Phase2ReadinessReport` 之前没有汇总 `DeviceReport.ToolWarnings` 和 `InstalledAppsReport.ToolWarnings`；`Write-Phase2ReadinessReport` 也没有对应的 `Tool warnings:` 输出段落。
- 处理：在顶层 readiness 结果里新增 `DeviceToolWarnings`、`InstalledAppToolWarnings` 和汇总后的 `ToolWarnings`，并在 `Write-Phase2ReadinessReport` 里打印 `Tool warnings:`；这些 warning 只作为诊断显示，不重新进入 `NextActions`。
- 验证：先重跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`，确认 RED 失败信息是 `Human-readable readiness output should print tool warnings collected from nested reports.`；修复后同一测试通过。真实只读验证命令：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -TargetRepo 'ds0515/0516_WDA' -NoFail`。当前输出已显示 `Tool warnings:`、`Device: tidevice device list failed with exit code 1.`、`Installed apps: tidevice app list failed with exit code 1.`，且 `Next required gate` 仍是 `Signing`。
- 下次动作：凡是顶层 readiness 依赖子报告新增结构化诊断字段时，都要同时检查顶层人类可读摘要是否同步透传；不要只修子报告或 JSON，而让顶层入口继续丢失诊断上下文。

## 98. 新坑：签名阻塞如果已经收敛到“同 bundle/UDID 但仍是 distribution”，报告必须把这个最近可复用候选抬到顶层动作
- 坑点：触发条件、现象、影响范围：当前扫描到的 mobileprovision 里，已经存在 `app.honey4212.crystal5671` 且包含 `00008030-0001598021E2802E` 的 profile，但它们统一是 distribution，`get-task-allow=false`。旧版 `report-ios-signing-profiles.ps1` 只会泛泛提示“提供 Apple Development profile”，恢复上下文后仍需要人工再读一遍 profile 明细，才能确认其实不缺 bundle/UDID，只差 development profile kind。影响范围是 Phase 2 signing gate 的只读诊断和顶层 readiness 下一步动作，不涉及证书内容、账号密码或真机写操作。
- 根因：签名报告此前只聚合“是否存在可用 development profile”和“所有失败原因”，没有专门识别“作用域已正确、只剩 profile kind 错误”的最近可复用候选。
- 处理：在 `report-ios-signing-profiles.ps1` 新增 `ClosestReusableProfile`；当存在未过期、覆盖目标 bundle、包含目标 UDID，但仍未 ready 的候选时，优先把它抬到 `NextActions`。若唯一剩余 blocker 是 `profile kind is distribution`，则明确提示：现有 profile 已覆盖 bundle/UDID，但 `get-task-allow=false`，需要为同一 App ID 和同一 UDID 重新生成 Apple Development profile。
- 验证：先让 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-signing-profile-report-tests.ps1` 因 `ClosestReusableProfile` 缺失而 RED；修复后同一测试通过。相邻验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-signing-profiles.ps1 -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -SearchRoot 'D:\2026_soft' -NoFail` 现在会输出 `Closest reusable profile: 00008030-0001598021E2802E3SL5LO; kind=distribution; covers_bundle=True; includes_udid=True; expired=False; failure_reasons=profile kind is distribution`，顶层 readiness 也会把这个更具体的 signing 动作提到 `Next required action`。
- 下次动作：只要 signing gate 已经缩小到少数 profile kind / expiration / UDID 问题，就优先把“最近可复用候选 + 剩余最小 blocker”写进报告和顶层动作；不要只保留泛化的“提供 development profile”，否则恢复上下文后还要重复人工比对。

## 99. 新坑：同一 signing profile 在多个解包目录重复出现时，要优先指向源材料路径，并把该路径直接打印到文本输出
- 坑点：触发条件、现象、影响范围：当前仓库和历史目录里同时存在很多 `embedded.mobileprovision` 解包副本，以及少量更像源材料的 `cert.mobileprovision`。如果 `ClosestReusableProfile` 只按失败数和字典序选，往往会先选到 `Payload/.../embedded.mobileprovision`，恢复上下文后操作者容易拿错“只是某个 IPA 里提取出来的副本”，而不是应该直接替换或重新生成的源材料路径。影响范围是 Phase 2 signing gate 的只读诊断和顶层 `Next required action`，不涉及证书内容或写操作。
- 根因：候选排序此前没有区分“源材料 mobileprovision”和“解包副本 embedded.mobileprovision”；同时人类可读输出和 `NextActions` 里也没有直接打印 `ClosestReusableProfile.Path`，导致即使 JSON 里能看到正确路径，终端摘要里仍然缺关键定位信息。
- 处理：在 `report-ios-signing-profiles.ps1` 增加 source preference rank，降低 `Payload/.../embedded.mobileprovision` 这类解包副本的优先级；同时把 `ClosestReusableProfile.Path` 直接透传到人类可读摘要和 `NextActions` 文案里。
- 验证：先在 `test\ios-signing-profile-report-tests.ps1` 新增 RED 断言，要求重复 profile 场景下优先选择 `D:\zsource\cert.mobileprovision` 而不是 `D:\A\Payload\...\embedded.mobileprovision`；修复后同一测试通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-signing-profiles.ps1 -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -SearchRoot 'D:\2026_soft' -NoFail` 现在会输出 `Closest reusable profile: ...; path=D:\2026_soft\0424_EC_RPA\USB_Plan6\Appium_WDA\WebDriverAgent\Scripts\ci\cert.mobileprovision; ...`；顶层 readiness 也会把路径带进 `Next required action`。
- 下次动作：凡是 signing gate 依赖“最近可复用候选”推进时，都要同时检查三件事：是不是优先指向源材料路径、`NextActions` 有没有直接给出该路径、人类可读摘要是否不需要再借助 `-AsJson` 才能定位文件。

## 100. 新坑：多个“源材料样式”的 `cert.mobileprovision` 都存在时，还要继续优先更浅的路径，避免顶层和单独报告指向不同历史工作目录
- 坑点：触发条件、现象、影响范围：在已经排除 `embedded.mobileprovision` 解包副本后，当前环境里仍有多份等价的 `cert.mobileprovision`，例如 `D:\2026_soft\0424_EC_RPA\USB_Plan6\Appium_WDA\WebDriverAgent\Scripts\ci\cert.mobileprovision` 和 `D:\2026_soft\0430_WS\0423_iPhone11\cert.mobileprovision`。如果排序仍只靠字典序，单独签名报告和顶层 readiness 可能分别指向不同历史目录，恢复上下文后操作者还要再判断哪份更像当前要替换的源材料。影响范围是 Phase 2 signing gate 的只读定位，不涉及证书内容或写操作。
- 根因：此前只区分了“解包副本 vs 源材料”，但没有在多个非解包副本之间继续按路径深度做优先级；结果更深的历史工作目录可能因为字典序更小而被错误选中。
- 处理：在 `report-ios-signing-profiles.ps1` 的 `ClosestReusableProfile` 排序里新增路径深度偏好；在 source preference rank 相同的前提下，优先选择更浅的源材料路径。
- 验证：先在 `test\ios-signing-profile-report-tests.ps1` 新增 RED 断言，要求 `D:\zsource\cert.mobileprovision` 优先于 `D:\A_deep\workspace\WebDriverAgent\Scripts\ci\cert.mobileprovision`；修复后测试通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-signing-profiles.ps1 -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -SearchRoot 'D:\2026_soft' -NoFail` 现在已把 `Closest reusable profile` 收敛到 `D:\2026_soft\0430_WS\0423_iPhone11\cert.mobileprovision`，顶层 readiness 的 `Next required action` 也同步指向同一路径。
- 下次动作：凡是签名候选排序涉及多份等价 `cert.mobileprovision` 时，都要同时检查三点：是否已排除解包副本、是否优先更浅的源材料路径、顶层 readiness 和单独签名报告是否已经收敛到同一份文件。

## 101. 新坑：一旦已经存在 scope 正确的 signing 候选，顶层 `Profile failure reasons` 不应再混入无关 bundle 的 profile 噪声
- 坑点：触发条件、现象、影响范围：当前已经存在 `bundle + UDID` 都正确、只差 `distribution/development` 的 profile 候选，但旧版 `report-ios-signing-profiles.ps1` 仍会在 `Blocking issues` 的 `Profile failure reasons` 里混入 `CycommGroupAppProfile` 这类完全不覆盖目标 bundle 的 profile 摘要。恢复上下文后，操作者虽然能从 `NextActions` 看出最近可复用候选，却仍会被 blocker 里的无关 profile 噪声干扰。影响范围是 Phase 2 signing gate 的只读 blocker 汇总和顶层 readiness 摘要，不涉及 gate 顺序或写操作。
- 根因：此前聚合 blocker 是基于去重后的 failure summary 代表记录，而不是基于 `ClosestReusableProfile` 对应的原始 non-ready profile 对象；当同一 summary 有多份副本时，代表记录的路径可能与最近可复用候选不一致，导致筛选失败并回退到“全部失败摘要”。
- 处理：把聚合 blocker 的筛选改为先基于原始 non-ready profile 对象锁定 `ClosestReusableProfile.Path`，再重新生成去重后的 `aggregatedFailureSummaries`。这样一旦已经找到 scope 正确的最近可复用候选，`Profile failure reasons` 就只保留与该候选直接相关的最小失败原因。
- 验证：先在 `test\ios-signing-profile-report-tests.ps1` 新增 RED 断言，构造“最近可复用候选有重复副本 + 另有无关 bundle 噪声”的场景，要求 `Profile failure reasons` 保留 `dist-profile: profile kind is distribution`，但不再包含 `wrong-profile: App ID suffix app.other ...`；修复后测试通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-signing-profiles.ps1 -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -SearchRoot 'D:\2026_soft' -NoFail` 现在的 `Blocking issues` 已只剩 `00008030-0001598021E2802E3SL5LO: profile kind is distribution`；顶层 readiness 也同步只剩这个 signing blocker。
- 下次动作：凡是 signing gate 已经收敛到 scope 正确的最近可复用候选时，都要同时检查两层输出是否一致：`NextActions` 是否指向该候选，`Profile failure reasons` 是否已经压掉无关 bundle/UDID 的噪声；不要让 blocker 层继续把已经无关的 profile 抬到顶层。

## 102. 新坑：当 `ClosestReusableProfile` 已经给出精确替换目标时，不应继续保留泛化的 “Provide an Apple Development profile...” 重复动作
- 坑点：触发条件、现象、影响范围：在已经明确 `ClosestReusableProfile` 的情况下，旧版 `report-ios-signing-profiles.ps1` 仍会同时保留两条本质重复的下一步动作：一条是精确到文件路径、App ID 和 UDID 的动作，另一条是泛化的 `Provide an Apple Development profile that is unexpired...`。恢复上下文后，操作者虽然能看到精确目标，但顶层入口仍被重复动作占位，影响 Phase 2 signing gate 的可执行性和可读性。
- 根因：`NextActions` 生成逻辑此前无条件追加通用 development-profile 提示，没有在 `ClosestReusableProfile` 已存在时做去重或抑制。
- 处理：当 `ClosestReusableProfile` 存在时，只保留围绕该候选的精确替换动作和“不要继续使用 distribution profile”的安全边界提示；只有在找不到最近可复用候选时，才退回到泛化的 `Provide an Apple Development profile...` 动作。
- 验证：先在 `test\ios-signing-profile-report-tests.ps1` 新增 RED 断言，要求有 `ClosestReusableProfile` 时 `NextActions` 不再包含 `Provide an Apple Development profile that is unexpired...`；修复后测试通过。相邻验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-signing-profiles.ps1 -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -SearchRoot 'D:\2026_soft' -NoFail` 现在的 `Next actions` 已只剩两条，其中主动作直接指向 `D:\2026_soft\0430_WS\0423_iPhone11\cert.mobileprovision`；顶层 readiness 也同步只剩这个主动作和 distribution 安全边界提示。
- 下次动作：凡是 signing gate 已经明确到单一 `ClosestReusableProfile` 时，都要检查 `NextActions` 是否仍保留泛化重复动作；不要让顶层入口同时出现“精确动作 + 泛化动作”，否则恢复上下文后仍会浪费一次人工判读。

## 103. 新坑：当 blocker 和 next action 已经收敛时，人类可读签名报告也不应继续全量展开无关 profile 明细
- 坑点：触发条件、现象、影响范围：即使 `Blocking issues`、`Next actions` 和 `ClosestReusableProfile` 已经完全收敛到当前目标，旧版 `Write-IosSigningProfileReport` 仍会把 `Report.Profiles` 全量打印出来，包含大量与当前 bundle/UDID 无关的 profile 明细。这样用户单独跑签名报告时，仍然要在终端里手动过滤无关条目，影响 Phase 2 signing gate 的可读性。
- 根因：人类可读渲染层此前不区分“完整结构化事实”和“当前需要看的明细集合”；即使已经存在 `ClosestReusableProfile`，它仍无条件遍历 `Report.Profiles`。
- 处理：当 `ClosestReusableProfile` 存在时，人类可读输出只渲染当前 bundle/UDID 相关的 profile 明细，也就是 `CoversBundleId=true` 且 `IncludesDeviceUdid=true` 或 `ProvisionsAllDevices=true` 的集合；JSON 里的完整 `Profiles` 保持不变，供需要时再做深入检查。
- 验证：先在 `test\ios-signing-profile-report-tests.ps1` 新增 RED 断言，要求 `duplicateSummaryReport` 的人类可读输出里 `- kind=` 明细行数从 3 降到 2；修复后测试通过。相邻验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-signing-profiles.ps1 -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -SearchRoot 'D:\2026_soft' -NoFail` 现在从原先全量 16 条 profile 明细降到 7 条当前目标相关明细，仍保留 `ClosestReusableProfile`、`Blocking issues` 和 `Next actions`。
- 下次动作：凡是签名 gate 的结构化结论已经收敛时，都要同步检查人类可读输出是否仍在全量展开无关 profile 明细；不要只清理 blocker 和 action 层，而让明细层继续把无关 profile 噪声留在终端里。

## 104. 新坑：即使只剩当前 bundle/UDID 相关 profile 明细，也还要压掉同 UUID / 同失败原因的重复副本
- 坑点：触发条件、现象、影响范围：在把人类可读签名报告从“全量 profile”压缩到“当前 bundle/UDID 相关 profile”之后，终端里仍可能连续出现多条其实是同一份 distribution profile 的副本，例如源材料 `cert.mobileprovision`、解包后的 `embedded.mobileprovision` 以及历史 artifact 里的同 UUID 副本。这样虽然 scope 已经对了，用户仍要手工判断哪几条其实是同一份 profile 的重复影子。影响范围是 Phase 2 signing gate 的人类可读明细层，不涉及 JSON 结构或 gate 判定。
- 根因：此前渲染层虽然已经过滤到相关 profile 集合，但还没有继续对“同 UUID + 同失败原因”的副本集合做去重，因此同一份 profile 的多个副本仍会逐条打印。
- 处理：在 `Write-IosSigningProfileReport` 里，对当前目标相关的 profile 明细先按 source-preference 和路径深度排序，再按 `UUID + failure_reasons` 分组，只保留每组的代表项。这样人类可读输出最终只保留对当前目标最有用的那条代表路径。
- 验证：先在 `test\ios-signing-profile-report-tests.ps1` 新增 RED 断言，把 `duplicateSummaryReport` 里的人类可读 `- kind=` 明细行数从 2 压到 1；修复后测试通过。相邻验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-signing-profiles.ps1 -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -SearchRoot 'D:\2026_soft' -NoFail` 现在已从 7 条当前目标相关明细进一步压到 1 条代表明细，且仍保留 `ClosestReusableProfile`、`Blocking issues` 和 `Next actions`。
- 下次动作：凡是签名报告的人类可读明细已经缩小到相关 profile 集合后，都要再检查是否还残留“同一份 profile 的多个副本”；不要把“已过滤到相关集合”误当成“已经足够可读”。

## 105. 新坑：`resign-native-wda.ps1 -ValidateOnly` 遇到 distribution profile 时，错误文案既要前置说明真实阻塞，也要避免测试依赖被终端宽度截断的整句
- 坑点：触发条件、现象、影响范围：当前存在一份 `bundle + UDID` 都正确、但仍是 distribution 的 `cert.mobileprovision`。旧版 `resign-native-wda.ps1 -ValidateOnly` 只会泛化报 `kind=distribution` 或把详细原因埋在长消息尾部；外层测试再用 `2>&1` 捕获时，PowerShell 还可能按终端宽度截断整句，导致断言不稳定。影响范围是 Phase 2 signing gate 的签名前置诊断和回归测试，不涉及证书内容、账号或真机写操作。
- 根因：真实 blocker 不是 bundle scope、也不是 UDID scope，而是 `get-task-allow=false`；同时 PowerShell 对 `ErrorRecord` 的字符串化会受宿主显示宽度影响，长错误消息的后半段不适合作为稳定断言目标。
- 处理：在 `Assert-MobileProvisionReadyForPhase2` 里对“scope 已正确但 profile kind=distribution”的情况单独抛出更具体的错误，明确说明这份 mobileprovision 已覆盖目标 bundle 并包含目标 UDID，但仍需替换成同一 App ID、同一 UDID 的 Apple Development profile。测试侧不要再匹配整句或完整 UDID，而是只断言第一屏稳定可见的关键片段：`get-task-allow=false`、`already covers <bundle>`、`includes <udid-prefix>`。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\resign-native-wda-script-tests.ps1` 通过；相邻验证 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -TargetRepo 'ds0515/0516_WDA' -NoFail` 现在稳定把顶层 gate 收敛到 `Signing`，并把 `get-task-allow=false` 作为下一步动作的核心原因。
- 下次动作：只要 signing gate 仍指向“最近可复用但仍是 distribution 的 profile”，先跑 `resign-native-wda.ps1 -ValidateOnly` 或 `check-phase2-readiness.ps1` 看是否还明确指出 `get-task-allow=false`；若回归测试再次需要捕获错误文本，优先断言稳定前缀，不要回到完整长句匹配。

## 106. 新坑：目标仓库切换到 `ds0515/0516_WDA` 后，用户可见文档和顶层 readiness 示例也必须同步切换，不能只改脚本默认值
- 坑点：触发条件、现象、影响范围：脚本默认目标仓库已经切到 `ds0515/0516_WDA`，但 `docs/resign-wda.md` 以及 `test\phase2-readiness-tests.ps1` 里代表“当前目标仓库”的用户可见 workflow URL、runner 注册 URL、keep-only 清理提示等文本仍停留在 `ds0515/0511_Appium_WDA`。恢复上下文后，操作者容易把云构建、runner 注册或清理保护对象重新指回旧仓库。影响范围是 Phase 2 的文档入口、顶层 readiness 示例和云构建操作指引，不涉及真机、签名执行或 GitHub 写入本身。
- 根因：此前只修正了脚本参数默认值和部分测试，未把“当前目标仓库”的用户可见说明和顶层示例一起纳入切换范围。
- 处理：把 `docs/resign-wda.md` 中所有当前目标仓库说明统一到 `ds0515/0516_WDA`；把 `test\phase2-readiness-tests.ps1` 里表示当前目标仓库的 workflow URL、keep-only 提示、自托管 runner 提示同步改成新仓库。历史踩坑记录中的旧仓库事实保留，不做改写。
- 验证：`rg -n "ds0515/0511_Appium_WDA" .\docs\resign-wda.md .\test\phase2-readiness-tests.ps1` 无匹配；`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过；`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-default-target-repo-tests.ps1` 通过。
- 下次动作：只要再发生 target repo 切换，除了脚本默认值外，还要同时检查三层输出是否同步：面向操作者的文档、顶层 readiness 人类可读文本、以及验证这些文本的测试夹具；否则恢复上下文时仍会被旧仓库名带偏。

## 107. 新坑：默认目标仓库回归测试不能只扫脚本，主操作文档也必须纳入
- 坑点：触发条件、现象、影响范围：在把脚本默认目标仓库切到 `ds0515/0516_WDA` 之后，`phase2-default-target-repo-tests.ps1` 一度只检查脚本文件，导致 `docs/offline-automation-v1.md` 这类长期恢复会直接阅读的操作文档仍然保留旧仓库 `ds0515/0511_Appium_WDA`，但测试不会报警。影响范围是 Phase 2 的恢复指引、云构建命令示例和 runner/cleanup 操作说明，不涉及真机、签名或 GitHub 写入执行。
- 根因：默认目标仓库一致性此前被当成“脚本参数默认值”问题处理，测试覆盖范围没有扩展到同样承担操作入口职责的文档。
- 处理：把 `docs/offline-automation-v1.md` 里的当前目标仓库、`TargetRepo` 示例、runner 注册 URL、keep-only/保护仓库提示统一切到 `ds0515/0516_WDA`；同时把 `docs/resign-wda.md` 和 `docs/offline-automation-v1.md` 加入 `test\phase2-default-target-repo-tests.ps1` 的扫描列表。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-default-target-repo-tests.ps1` 通过；相邻验证 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-cloud-gate-tests.ps1` 通过。
- 下次动作：凡是再切换默认目标仓库时，先更新脚本，再更新面向操作者的主文档，最后把这些文档纳入默认仓库回归测试；不要让“脚本已切换、文档还停留在旧仓库”重复出现。

## 108. 新坑：顶层 Phase 2 readiness 也必须锁死 `get-task-allow=false` 的可见性，不能只靠 signing 子报告或 resign 脚本单测
- 坑点：触发条件、现象、影响范围：即使 `report-ios-signing-profiles.ps1` 和 `resign-native-wda.ps1 -ValidateOnly` 都已经能明确指出 `get-task-allow=false`，如果顶层 `check-phase2-readiness.ps1` 的聚合逻辑以后回退成泛化的“缺 Apple Development profile”，恢复上下文后的操作者仍然要重新下钻到子报告才能知道真实最小阻塞。影响范围是 Phase 2 的顶层门禁入口和下一步动作排序，不涉及签名执行、真机写操作或 GitHub 写入。
- 根因：此前关于 distribution profile 的回归覆盖集中在 signing 子报告和 resign 脚本，顶层 readiness 只验证了“Signing 是下一 gate”和“有 structured next actions”，但没有单独锁死 `NextRequiredAction` 必须继续暴露 scope 已正确、仅缺 development entitlement 的事实。
- 处理：在 `test\phase2-readiness-tests.ps1` 新增一个 scope 正确但仍为 distribution 的 signing fixture，用于验证：当现成可安装 artifact 已存在、Cloud 不再是下一 gate 时，顶层 `NextRequiredAction` 必须直接保留 `Closest reusable profile` 路径、bundle/UDID 已覆盖说明和 `get-task-allow=false`；人类可读输出也必须继续打印这个具体阻塞。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过；相邻验证 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\resign-native-wda-script-tests.ps1` 通过。
- 下次动作：凡是顶层 gate 已经从 Cloud/Artifact 前移到 Signing 时，都要优先检查顶层 `NextRequiredAction` 是否仍然保留 `get-task-allow=false` 和 `Closest reusable profile` 路径；不要把“子报告里还能看到”误当成“顶层入口已经足够明确”。

## 109. 新坑：顶层 readiness 的 signing 恢复线索不能只透传一个 profile 标识，`Name` 和 plist `UUID` 都要保留
- 坑点：触发条件、现象、影响范围：顶层 `check-phase2-readiness.ps1 -AsJson` 先前只透传了 `ClosestReusableProfileUuid/Path/FailureReasons`。真实只读验证表明，人类可读 `NextRequiredAction` 里展示的是 profile 的 `Name`（例如 `00008030-0001598021E2802E3SL5LO`），而 plist 里的结构化 `UUID` 则是另一个值（例如 `73290ad3-7cc8-4e4f-9d2c-a8a20052fc8d`）。如果顶层只给其中一个，恢复上下文时就会出现“字符串动作对不上结构化字段”的混淆。影响范围是 Phase 2 signing gate 的恢复定位和后续自动化消费，不涉及签名执行、真机写操作或 GitHub 写入。
- 根因：`report-ios-signing-profiles.ps1` 的人类可读文案使用 `ClosestReusableProfile.Name`，而结构化对象同时还有 `UUID`；顶层 readiness 此前只部分透传了这个对象。
- 处理：在 `check-phase2-readiness.ps1` 顶层报告中同时透传 `ClosestReusableProfileName`、`ClosestReusableProfileUuid`、`ClosestReusableProfilePath` 和 `ClosestReusableProfileFailureReasons`；在 `test\phase2-readiness-tests.ps1` 中新增断言，锁定这些字段在 Signing 成为下一 gate 时必须存在。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过；相邻验证 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-signing-profile-report-tests.ps1` 通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -TargetRepo 'ds0515/0516_WDA' -AsJson -NoFail` 现在返回 `ClosestReusableProfileName=00008030-0001598021E2802E3SL5LO`、`ClosestReusableProfileUuid=73290ad3-7cc8-4e4f-9d2c-a8a20052fc8d`、`ClosestReusableProfilePath=D:\2026_soft\0430_WS\0423_iPhone11\cert.mobileprovision`、`ClosestReusableProfileFailureReasons=profile kind is distribution`。
- 下次动作：凡是 Phase 2 顶层报告要给恢复流程或自动化消费时，都不要只依赖长字符串 `NextRequiredAction`；优先使用顶层透传的 `ClosestReusableProfile*` 结构化字段，同时保留人类可读动作用于人工确认。

## 110. 新坑：Signing gate 的测试夹具也要模拟 `Name` 与 `UUID` 不同的真实 profile，避免回归时误把两者视为同一字段
- 坑点：触发条件、现象、影响范围：在顶层 readiness 已经透传 `ClosestReusableProfileName` 和 `ClosestReusableProfileUuid` 之后，如果测试夹具还把这两个字段写成同一个值，就无法发现后续有人把“显示名”和“plist UUID”混用的回归。真实环境里这两者可能不同。影响范围是 Phase 2 signing gate 的回归质量和恢复定位，不涉及签名执行、真机写操作或 GitHub 写入。
- 根因：早期测试为了简化构造，把 scope 正确但仍为 distribution 的 profile fixture 写成了 `Name == UUID`，与真实 `cert.mobileprovision` 情况不一致。
- 处理：把 `test\phase2-readiness-tests.ps1` 中该 signing fixture 改成真实形态：`Name=00008030-0001598021E2802E3SL5LO`，`UUID=73290ad3-7cc8-4e4f-9d2c-a8a20052fc8d`，并新增断言要求顶层 readiness 必须同时保留两者且不能相等。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过；相邻验证 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-signing-profile-report-tests.ps1` 通过。
- 下次动作：凡是 Phase 2 的 fixture 要模拟 closest reusable profile 时，优先用“显示名”和“UUID”不同的样本；不要用过度简化的测试数据把真实恢复风险藏起来。

## 111. 新坑：顶层 readiness 不能只透传 `kind=distribution`，还要直接给出 `get-task-allow`
- 坑点：触发条件、现象、影响范围：即使顶层 `check-phase2-readiness.ps1 -AsJson` 已经透传 `ClosestReusableProfileKind=distribution`，恢复流程或自动化消费方仍需要再额外推断“这意味着 `get-task-allow=false`”。对当前 Phase 2 来说，`get-task-allow=false` 才是最直接、最稳定的真实阻塞信号。影响范围是 Signing gate 的顶层结构化消费和恢复判断，不涉及签名执行、真机写操作或 GitHub 写入。
- 根因：顶层 readiness 先前只是部分镜像 `ClosestReusableProfile`，没有把 signing 子报告里已经存在的 `GetTaskAllow` 原样透传出来。
- 处理：在 `check-phase2-readiness.ps1` 顶层报告中新增 `ClosestReusableProfileGetTaskAllow`；在 `test\phase2-readiness-tests.ps1` 的 distribution fixture 上新增 RED 断言，要求该字段必须存在并为 `false`。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过；相邻验证 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-signing-profile-report-tests.ps1` 通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -TargetRepo 'ds0515/0516_WDA' -AsJson -NoFail` 现在返回 `ClosestReusableProfileGetTaskAllow=false`。
- 下次动作：凡是 Phase 2 顶层 JSON 需要给恢复流程或工具消费时，优先读 `ClosestReusableProfileGetTaskAllow` 和 `ClosestReusableProfileFailureReasons`，不要只从 `ProfileKind=distribution` 做间接推断。

## 112. 新坑：人类可读 readiness 在 Signing gate 时也要把 closest profile 摘要前置打印，不能只靠长句 `Next required action`
- 坑点：触发条件、现象、影响范围：即使顶层 readiness 已经在 JSON 里透传了 `ClosestReusableProfile*` 字段，人工直接看 `check-phase2-readiness.ps1` 默认文本输出时，仍然要在一整句 `Next required action` 里人工提取 profile 名称、UUID、路径和 `get-task-allow=false`。恢复上下文时这一步容易看漏。影响范围是 Phase 2 Signing gate 的人工恢复效率和误读风险，不涉及签名执行、真机写操作或 GitHub 写入。
- 根因：人类可读输出此前只打印 `Next required gate` 和 `Next required action`，没有把顶层已经具备的 closest profile 结构化字段单独渲染出来。
- 处理：在 `Write-Phase2ReadinessReport` 中，当 `NextRequiredGate=Signing` 且 closest profile 已存在时，额外打印 `Closest reusable signing profile`、`UUID`、`path`、`kind`、`get-task-allow` 五行摘要。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过；相邻验证 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-signing-profile-report-tests.ps1` 通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -TargetRepo 'ds0515/0516_WDA' -NoFail | Select-String -Pattern 'Closest reusable signing profile|Next required gate|Next required action'` 现在会先打印 closest profile 摘要，再打印 Signing gate 和下一步动作。
- 下次动作：凡是顶层 Phase 2 文本输出已经知道“下一 gate 是 Signing 且 closest profile 已明确”时，都要优先把这份 profile 摘要前置，而不是只把信息埋在长句动作里。

## 113. 新坑：Signing gate 的人类可读摘要不能只给 `name/UUID/path/kind/get-task-allow`，还要把 scope 和剩余 blocker 一次性打全
- 坑点：触发条件、现象、影响范围：即使人类可读 readiness 已经会前置打印 closest profile 的名称、UUID、路径、kind 和 `get-task-allow`，人工恢复时仍然需要再从 `Next required action` 或下层 signing 报告里确认它是否已经覆盖目标 bundle、是否已经包含目标 UDID、是否过期、以及剩余 failure reason 是什么。影响范围是 Phase 2 Signing gate 的人工判读效率，不涉及签名执行、真机写操作或 GitHub 写入。
- 根因：人类可读摘要此前只渲染了部分 closest profile 字段，剩余状态位仍分散在长句动作和 JSON 中。
- 处理：在 `Write-Phase2ReadinessReport` 的 Signing gate 摘要里继续增加四行：`covers bundle`、`includes UDID`、`expired`、`failure reasons`，让人工恢复时不用再二次下钻。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过；相邻验证 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-signing-profile-report-tests.ps1` 通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -TargetRepo 'ds0515/0516_WDA' -NoFail | Select-String -Pattern 'Closest reusable signing profile|Next required gate|Next required action'` 现在会连续打印 `covers bundle: True`、`includes UDID: True`、`expired: False`、`failure reasons: profile kind is distribution`。
- 下次动作：凡是顶层默认文本输出已经进入 Signing gate 时，都优先把 closest profile 的 scope 状态和最小 blocker 在摘要行中打全；不要再把这些关键信息留给长句动作或 JSON 才能看见。

## 114. 新坑：顶层 JSON 不能只告诉你“这份 profile 最近可复用”，还要把 scope 形态带出来
- 坑点：触发条件、现象、影响范围：即使顶层 `check-phase2-readiness.ps1 -AsJson` 已经透传了 `ClosestReusableProfileName/UUID/Path/GetTaskAllow/CoversBundleId/IncludesDeviceUdid`，恢复流程或自动化消费方仍需要回到 signing 子报告才能知道这份 profile 的 `AppIdSuffix`、设备数、以及是否 `ProvisionsAllDevices`。这些信息会影响对 wildcard App ID、enterprise profile 或范围过宽 profile 的判断。影响范围是 Phase 2 Signing gate 的结构化恢复和自动化消费，不涉及签名执行、真机写操作或 GitHub 写入。
- 根因：顶层 readiness 先前只透传了最直接的 blocker 字段，没有把 closest reusable profile 的 scope 形态完整镜像出来。
- 处理：在 `check-phase2-readiness.ps1` 顶层 JSON 中新增 `ClosestReusableProfileAppIdSuffix`、`ClosestReusableProfileProvisionedDeviceCount`、`ClosestReusableProfileProvisionsAllDevices`；在 `test\phase2-readiness-tests.ps1` 中新增 RED 断言锁定这些字段。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过；相邻验证 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-signing-profile-report-tests.ps1` 通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -IncludeGitHubReports -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -TargetRepo 'ds0515/0516_WDA' -AsJson -NoFail` 现在返回 `ClosestReusableProfileAppIdSuffix=app.honey4212.crystal5671`、`ClosestReusableProfileProvisionedDeviceCount=1`、`ClosestReusableProfileProvisionsAllDevices=false`。
- 下次动作：凡是顶层 JSON 要喂给恢复流程或工具时，优先直接读这些 closest profile scope 字段；不要再回到 signing 子报告里补查 profile 形态。

## 115. 新坑：当 runtime probe 还没跑时，顶层 readiness 不能把 `RuntimeReady` 留空，也不能让 `NextRequiredAction` 为空
- 坑点：触发条件、现象、影响范围：当 Cloud/Artifact/Signing/Device/InstalledApps 前置 gate 都已通过，但本次恢复还没有提供 `probe-phase2-runtime.ps1` 的结果时，旧版 `check-phase2-readiness.ps1` 会把 `RuntimeReady` 保留为 `null`，人类可读输出显示成空的 `Runtime ready:`，同时 `NextRequiredGate=Runtime` 但 `NextRequiredAction` 可能为空。影响范围是 Phase 2 顶层恢复入口；会让操作者知道“卡在 Runtime”，却不知道是不是根本没跑 probe，还是 probe 已跑但失败。
- 根因：`New-Phase2ReadinessReport` 把 `RuntimeReady` 默认初始化成 `$null`，并且在 `RuntimeReport` 缺失时没有补充专门的 runtime blocker/next action；因此前置 gate 全通过但 runtime report 缺失时，顶层状态会出现布尔空洞。
- 处理：把顶层 `RuntimeReady` 默认值收敛为 `$false`；当 `RuntimeReport` 缺失且前置 gate 已通过时，显式追加 `Runtime: Runtime report was not provided.` blocker，并给出 `Run Scripts\probe-phase2-runtime.ps1 with the explicit target UDID...` 的下一步动作；同时给 Runtime gate 增加同样的 fallback next action。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -TargetRepo 'ds0515/0516_WDA' -NoFail | Select-String -Pattern 'Runtime ready|Next required gate|Next required action'`
- 下次动作：凡是顶层 `NextRequiredGate` 前移到 `Runtime` 时，先确认人类可读输出里 `Runtime ready` 是显式 `True/False`，并且 `Next required action` 直接指向 `probe-phase2-runtime.ps1`；不要再让恢复流程停在空值或空动作上。

## 116. 新坑：用户说“这个 profile 以前可以签”时，签名报告必须正面区分“可安装型签名”和“可用于 Phase 2 Development/WDA 验收”
- 坑点：触发条件、现象、影响范围：当前 `cert.mobileprovision` 已覆盖目标 bundle 且包含目标 UDID，用户容易据此判断“以前能签，所以现在也该能继续 Phase 2”。旧版 `report-ios-signing-profiles.ps1` 虽然已经给出 `kind=distribution` 和 `get-task-allow=false`，但没有在最靠前的人类可读摘要里直接说破“它可能还能做安装型签名，却不能作为 Phase 2 Development/WDA 验收签名”。影响范围是 Phase 2 signing gate 的人工恢复和沟通成本。
- 根因：签名报告此前默认把“是否覆盖 bundle/UDID”和“是否满足 Phase 2 wireless validation”混在同一层表达，操作者需要自己从 `distribution + get-task-allow=false` 再推导出“可签但不够用于当前验收”。
- 处理：在 `report-ios-signing-profiles.ps1` 的 `Closest reusable profile` 摘要下新增 `Closest reusable profile Phase 2 note:`，当最接近可复用的 profile 仅剩 `profile kind is distribution` 这个 blocker 时，明确说明：该 profile 可能仍可用于 install-oriented signing，但由于 `get-task-allow=false`、不是 Apple Development，所以不能满足 Phase 2 wireless validation。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-signing-profile-report-tests.ps1`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-signing-profiles.ps1 -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -SearchRoot 'D:\2026_soft' -NoFail | Select-String -Pattern 'Closest reusable profile|Phase 2 note|get-task-allow=false'`
- 下次动作：凡是用户或恢复流程再次引用“同一个 mobileprovision 以前可以签/可以装”时，先看 `Closest reusable profile Phase 2 note`；若它明确指向 `get-task-allow=false` 和非 Apple Development，就不要再把问题误归类成 UDID 缺失、bundle 不匹配或 p12 缺失。

## 117. 新坑：`resign-native-wda.ps1 -ValidateOnly` 的 distribution-profile 解释一旦变长，关键前缀必须前移，新增说明不能只靠运行期 stderr 断言
- 坑点：触发条件、现象、影响范围：当 `Assert-MobileProvisionReadyForPhase2` 针对“bundle/UDID 已匹配、但 profile 仍是 distribution”的场景增加更多解释时，外层 `powershell ... 2>&1` 抓到的错误文本会再次受到宿主宽度和远程异常字符串化影响。若把 `get-task-allow=false`、`already covers <bundle>`、`includes <udid>` 放到长句后半段，`test\resign-native-wda-script-tests.ps1` 会开始随机看不到这些关键片段。影响范围是 Phase 2 signing gate 的 `ValidateOnly` 入口和它的回归测试稳定性。
- 根因：运行期测试当前是通过启动外层 PowerShell 进程捕获报错文本，而不是直接调用函数对象；这类输出对长错误句后半段不稳定。此前新增的“install-oriented signing may still work”说明如果直接塞进长句中间或后部，就可能把原先稳定的 `get-task-allow=false / already covers / includes` 三个断言一起挤出第一屏。
- 处理：把 `ValidateOnly` 的 distribution-profile 错误前缀收敛为：先输出 `get-task-allow=false`、`already covers <bundle>`、`includes <udid>` 三个最小事实，再补充“install-oriented signing may still work, but Phase 2 wireless validation requires Apple Development...” 解释；同时把新增解释的验证改成 `scriptText` 断言，而不是继续依赖外层 stderr 必须完整保留长句。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\resign-native-wda-script-tests.ps1`
- 下次动作：凡是再给 `resign-native-wda.ps1` 的 distribution-profile 报错加说明时，先检查最稳定的三段事实是否仍在错误前缀第一屏；新增长说明优先加 `scriptText` 级断言，不要把测试重新绑回不稳定的完整 stderr 文本。

## 118. 新坑：签名阻塞如果已经收敛到“缺一个正确的 Apple Development profile”，就不要再只靠 `NextActions` 长句传递替换要求
- 坑点：触发条件、现象、影响范围：当 `report-ios-signing-profiles.ps1` 已经能确定当前最小阻塞是“bundle/UDID 已匹配，但缺 Development profile / get-task-allow=true”时，如果仍然只把替换要求埋在 `NextActions` 长句里，恢复流程和后续自动化消费者就必须重新解析自然语言，容易在 bundle、UDID、profile kind、get-task-allow、过期要求之间漏掉一项。影响范围是 Phase 2 signing gate 的 JSON 消费、顶层 readiness 透传和人工恢复效率。
- 根因：此前脚本更偏向人类可读叙述，`ClosestReusableProfile*` 虽已结构化，但“需要什么 replacement profile”仍主要靠文案传达，调用方只能从 `No Apple Development profile...` 和 `Regenerate the same App ID...` 这些句子里二次提取要求。
- 处理：在 `report-ios-signing-profiles.ps1` 里新增 `ReplacementRequirements` 结构化字段，明确给出 `BundleId`、`DeviceUdid`、`RequireProfileKind=development`、`RequireGetTaskAllow=true`、`RequireUnexpired=true` 等要求；在 `check-phase2-readiness.ps1` 里透传成 `SigningReplacementRequirements`，并在人类可读 Signing 摘要里直接打印这些替换要求。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-signing-profile-report-tests.ps1`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`
- 下次动作：凡是顶层 `NextRequiredGate=Signing` 且 `ClosestReusableProfile` 已经明确时，优先读取 `ReplacementRequirements` / `SigningReplacementRequirements`，不要再从 `NextActions` 长句里手工反推 Development profile 规格。

## 119. 新坑：Personal Team 临时验证不能外推到后续用另一套证书覆盖安装
- 坑点：触发条件、现象、影响范围：为了尽快验证 Phase 2，有可能先用未续费 Apple 账号的 Xcode Personal Team 临时开发签名跑通 WDA，再计划把同一个 IPA 用现有 distribution 证书或其他 profile 覆盖安装。这个流程只能证明“临时开发签名下 WDA 可以启动并响应 `/status`”，不能证明后续换 Team ID、profile kind 或 entitlements 后仍满足 Phase 2。影响范围是签名验收顺序、真机覆盖安装判断和 WDA 运行结论复用。
- 根因：iOS 安装会重新校验证书、provisioning profile、application-identifier、keychain access group、bundle id 和 entitlements。Personal Team profile 通常是短期 development profile，后续用 distribution profile 覆盖时 `get-task-allow=false`，签名语义已经变化；如果 Team ID 也变化，即使 bundle id 相同，也不能把前一次 WDA 运行结果当成最终签名验收。
- 处理：允许把 Personal Team 作为“临时可行性验证”路径，但要把结论标记为临时；最终 Phase 2 仍必须用目标 bundle `app.honey4212.crystal5671`、目标 UDID `00008030-0001598021E2802E`、`profile_kind=development`、`get_task_allow=True` 的未过期 profile 重新签名、安装并验证 `/status`。如果后续只想验证“能覆盖安装”，必须单独记录覆盖安装命令和安装结果，不得把它等同于 WDA wireless validation。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -TargetRepo 'ds0515/0516_WDA' -NoFail`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-signing-profiles.ps1 -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -SearchRoot 'D:\2026_soft' -NoFail`
- 下次动作：如果走 Personal Team 临时验证，先明确输出“临时验证假设、成功标准、验证方式”；验证通过后不要进入 Phase 3，而是回到 Signing gate，用最终 Development profile 重新跑签名报告、`ValidateOnly`、安装和 `/status`。

## 120. 新坑：Apple Profiles 页显示 `Access Unavailable` 时，不要继续排 GitHub 或本地签名脚本
- 坑点：触发条件、现象、影响范围：登录 `https://developer.apple.com/account/resources/profiles/list` 后页面显示 `Access Unavailable`，正文为该资源仅面向已加入 developer program 的开发者或组织团队成员。此时无法在网页端创建或下载 Certificates、Identifiers、Profiles。影响范围是 Phase 2 签名材料获取入口，不涉及 GitHub 云构建、unsigned IPA、设备连接或本地脚本逻辑。
- 根因：当前 Apple ID 没有有效的 Apple Developer Program 会员权限，也不是某个有效付费组织 team 的成员。Apple 官方续费说明也明确，会员过期后不能访问 Certificates, Identifiers & Profiles。
- 处理：停止在 Profiles 页面重试；优先让账号持有人续费 Apple Developer Program，或让已续费组织把该 Apple ID 加入团队并授予证书/Profile 管理权限。若暂时不续费，只能改走 Mac + Xcode Personal Team 的临时开发签名路径，并把结果标记为临时验证。
- 验证：Codex 内置浏览器当前 URL 为 `https://developer.apple.com/account/resources/profiles/list`，标题为 `Certificates, Identifiers & Profiles - Apple Developer`，DOM 可见 `Access Unavailable` 和 `This resource is only for developers enrolled in a developer program or members of an organization’s team in a developer program.`。
- 下次动作：遇到同样页面时，直接切到“续费/加入团队/Personal Team 临时验证”三选一，不要继续读取 GitHub token、重发云构建、或尝试用 distribution profile 完成 Phase 2 wireless validation。

## 121. 新坑：非 Development 实验签名已生成 IPA 后，安装失败要先分清是设备不可见还是签名不可用
- 坑点：触发条件、现象、影响范围：在无续费、无 Mac 的约束下，使用现有 distribution profile 和 `-AllowNonDevelopmentProfile` 对 native host unsigned IPA 做实验签名。`zsign` 成功生成 `LobsterWDAHost.distribution-experiment.ipa`，但 `tidevice install` 随后失败，输出 `Device for 00008030-0001598021E2802E not detected`。影响范围是 Phase 2 非 Development 实验路径的安装 gate，不代表该 IPA 已被 iOS 签名校验拒绝。
- 根因：只读设备检查显示 `tidevice list` 没有可见设备，`pymobiledevice3 usbmux list` 返回空数组；同时 Windows `Apple Mobile Device Service` 正在运行。因此当前最小解释是目标 iPhone 未通过 USB/usbmux 暴露给本机，可能是未连接、未解锁、未信任电脑、线缆/接口问题或设备未停留在信任状态。
- 处理：保留已生成的实验 IPA；先让用户连接目标 iPhone、解锁屏幕并确认“信任此电脑”，再重跑只读设备检查。只有设备可见后，才重试安装；不要在设备不可见时继续改签名参数、重发云构建或修改证书检查逻辑。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\resign-native-wda.ps1 -InputIpa 'D:\2026_soft\0511_Appium_WDA\artifacts\lobster-wda-host\LobsterWDAHost-unsigned-ipa-25955753277\LobsterWDAHost.unsigned.ipa' -OutputIpa 'D:\2026_soft\0511_Appium_WDA\artifacts\lobster-wda-host\LobsterWDAHost.distribution-experiment.ipa' -P12Path 'D:\2026_soft\0430_WS\0423_iPhone11\cert.p12' -MobileProvisionPath 'D:\2026_soft\0430_WS\0423_iPhone11\cert.mobileprovision' -PasswordPath 'D:\2026_soft\0430_WS\0423_iPhone11\password.txt' -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -AllowNonDevelopmentProfile -Install` 生成 IPA 后安装失败；`tidevice list` 为空；`pymobiledevice3 usbmux list` 返回 `[]`；`Get-Service` 显示 `Apple Mobile Device Service` 为 `Running`。
- 下次动作：继续此路线前，先执行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-device-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -NoFail`；只有 `Device ready: True` 后再重试安装和 `probe-phase2-runtime.ps1`。

## 122. 新坑：iOS 18.7 设备可见且实验 IPA 已安装后，Windows 侧 DVT 启动可能先卡在 DeveloperImage/tunneld
- 坑点：触发条件、现象、影响范围：目标 iPhone 通过 USB 可见，`LobsterWDAHost.distribution-experiment.ipa` 已成功安装且后安装检查返回 `Post-install native host installed: True`。随后 `probe-phase2-runtime.ps1` 尝试启动 native host，但 `Launch succeeded: False`，USB relay 对 8100 的 `/status`、`/screenshot`、`/source` 均为 503，relay 日志显示 `UsbmuxReplyCode.ConnectionRefused`。手动 `tidevice launch app.honey4212.crystal5671` 失败为 `DeveloperImage not found`，`pymobiledevice3 developer dvt launch` 先报 `InvalidService`，再退到 tunneld 后失败。影响范围是 Windows 侧自动启动 app，不等同于已证明 app 手动启动后不能提供 8100 服务。
- 根因：当前 iPhone 是 iOS 18.7.7，tidevice 自动下载 18.7/18.6/18.x device support 后仍找不到可用 DeveloperImage；pymobiledevice3 的 DVT launch 对开发者服务或 tunneld 依赖也未满足。因为 app 没被成功拉起，8100 端口在设备侧拒绝连接，HTTP probe 只能得到 503 和空响应体。
- 处理：不要继续改签名或重装同一 IPA；先让用户在 iPhone 上手动点开已安装的 `Lobster WDA`，保持屏幕解锁和 app 前台，再用 `probe-phase2-runtime.ps1 -SkipLaunch` 只探测 USB relay `/status` 和 WDA routes。如果手动打开后仍是 503，才把 blocker 收敛为 app runtime/签名语义不满足；如果 `/status` 变为 200，再继续验证 Wi-Fi endpoint。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\probe-phase2-runtime.ps1 -DeviceUdid '00008030-0001598021E2802E' -BundleId 'app.honey4212.crystal5671' -OutputDirectory 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\distribution-experiment' -NoFail`；`tidevice -u 00008030-0001598021E2802E launch app.honey4212.crystal5671`；`pymobiledevice3 developer dvt launch --udid 00008030-0001598021E2802E app.honey4212.crystal5671`。
- 下次动作：在 iOS 18.7 Windows 环境中，如果自动 launch 失败但安装成功，优先安排“手机手动打开 app + `-SkipLaunch` probe”的验证顺序；不要把 DeveloperImage/tunneld 启动失败直接归因到 IPA 签名失败。

## 123. 新坑：手动打开 native host 后 USB `/status` 可以 ready，但 distribution 签名仍不能证明 UI automation 和 Wi-Fi endpoint
- 坑点：触发条件、现象、影响范围：用户在 iPhone 上手动打开 `Lobster WDA` 后，`probe-phase2-runtime.ps1 -SkipLaunch` 通过 USB relay 访问 `/status` 返回 HTTP 200 且 `ready=true`，`/wda/network` 返回 `listenScope=all`、`bonjourServiceType=_wda._tcp.`、Wi-Fi IP `192.168.0.128`。但 `/screenshot` 返回 500，错误为 `Not authorized for performing UI testing actions.`；`/source` 返回 500，错误为 `Failed to get system application: Not authorized for performing UI testing actions.`；Wi-Fi `http://192.168.0.128:8100/status` 超时；Bonjour 能发现并解析 `WebDriverAgent _wda._tcp.local.` 到 `iPhone-11.local.:8100`，但该 endpoint `/status` 也超时。影响范围是无续费、无 Mac、distribution 实验签名路径的 Phase 2 验收边界。
- 根因：USB `/status` 只证明 native HTTP 服务在前台运行，并不证明 XCTest UI automation 授权存在。distribution 签名的 native host 没有获得执行 UI testing actions 的授权，因此截图、source 和后续 tap/input 类接口不能作为可用。Wi-Fi 侧则说明 Bonjour 广播和解析成立，但 TCP 8100 从 PC 到 iPhone 仍不可达，可能与 iOS Local Network 权限、前台状态、网络隔离或监听实际暴露有关；当前证据还不能把原因唯一归结为代码缺陷。
- 处理：保留该结果作为“install-oriented signing 可运行 HTTP status，但不能完成 Phase 2 WDA 控制链路”的证据。继续实验时，先让用户确认 iPhone 已允许 `Lobster WDA` 的本地网络权限、App 保持前台、PC 与 iPhone 位于同一普通 Wi-Fi 且无访客网络/AP 隔离；然后重跑 `probe-phase2-runtime.ps1 -SkipLaunch` 和 `probe-wda-bonjour.ps1 -ResolveServices -ProbeStatus`。即使 Wi-Fi 后续变通，UI automation 500 仍要求 development-signed XCTest runner 或等价授权路径才能进入 Phase 2 完成。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\probe-phase2-runtime.ps1 -DeviceUdid '00008030-0001598021E2802E' -BundleId 'app.honey4212.crystal5671' -OutputDirectory 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\distribution-experiment-manual-launch' -SkipLaunch -NoFail`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\probe-wda-bonjour.ps1 -DeviceUdid '00008030-0001598021E2802E' -ResolveServices -ProbeStatus -OutputDirectory 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\distribution-experiment-manual-launch-bonjour' -NoFail`。
- 下次动作：恢复到该点时，先看 `usb-status.json` 是否 ready；如果 ready 但 UI routes 为 500，就不要把 Phase 2 判定为完成。下一步只能是修 Wi-Fi 可达性作为部分证据，或切换到 Development/XCTest runner 授权路径来解决 UI automation。

## 124. 新坑：手机界面显示 `running` 不等于 USB relay 到 8100 仍可达
- 坑点：触发条件、现象、影响范围：用户报告 iPhone 上 `Lobster WDA` 的 status 显示 `running`，但随后 `probe-phase2-runtime.ps1 -SkipLaunch` 的 USB `/status`、`/wda/network`、`/screenshot`、`/source` 全部返回 503 且响应体为空；Bonjour 探测也没有发现 `_wda._tcp` 服务。影响范围是人工观察 App UI 状态后的 runtime 恢复判断。
- 根因：relay 日志显示 `UsbmuxReplyCode.ConnectionRefused`，说明 Windows 已经通过 USB 尝试连接设备侧 8100，但设备侧端口当时没有接受连接。App UI 的 `running` 文案可能是前一次服务状态、UI 状态或未同步的状态，不足以证明 HTTP server 当前仍在监听。
- 处理：以后不能只靠手机 UI 文案判断 WDA 运行状态；必须以 `probe-phase2-runtime.ps1 -SkipLaunch` 的 USB `/status` 为准。若 UI 显示 running 但 probe 为 503，应让用户保持 App 前台，执行一次停止/启动服务或从任务切换器划掉 App 后重新打开，再立即重跑 probe。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\probe-phase2-runtime.ps1 -DeviceUdid '00008030-0001598021E2802E' -BundleId 'app.honey4212.crystal5671' -OutputDirectory 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\distribution-experiment-status-running' -SkipLaunch -NoFail`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\probe-wda-bonjour.ps1 -DeviceUdid '00008030-0001598021E2802E' -ResolveServices -ProbeStatus -OutputDirectory 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\distribution-experiment-status-running-bonjour' -NoFail`。
- 下次动作：遇到 UI 显示 running 时，先重启服务/重开 App，再用 USB `/status` 证明 ready；不要把 UI 文案当作 Phase 2 runtime 证据。

## 125. 新坑：iOS 18.7 DeveloperImage 缺失不只影响 launch，也会影响 tidevice screenshot 取证
- 坑点：触发条件、现象、影响范围：为了确认 `Lobster WDA` 是否真的在前台，尝试用 `tidevice -u 00008030-0001598021E2802E screenshot ...\iphone-screen.png` 抓取当前屏幕。命令再次尝试下载 18.7/18.6/18.x device support，最后失败为 `DeveloperImage not found`。影响范围是 Windows 侧通过截图确认手机当前 UI 状态的取证路径。
- 根因：`tidevice screenshot` 依赖 `com.apple.mobile.screenshotr` 等开发者相关服务；在当前 iOS 18.7.7 环境下，缺少可用 DeveloperImage 时，screenshot 服务和 DVT launch 一样无法启动。因此无法用 tidevice 截图来替代用户肉眼确认。
- 处理：不要把无法抓屏误判为 WDA app 崩溃；它只是 Windows 工具链取证能力不足。继续该实验路线时，手机前台状态只能由用户人工确认，自动证据以 USB `/status`、Bonjour 和 Wi-Fi probe 为准。
- 验证：`tidevice -u 00008030-0001598021E2802E screenshot 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\resume-status-check\iphone-screen.png'`，输出 `tidevice.exceptions.ServiceError: DeveloperImage not found`。
- 下次动作：如果要在 Windows 上恢复截图取证，先解决 iOS 18.7.7 DeveloperImage/工具链支持；否则不要在 Phase 2 runtime 验证中依赖 tidevice screenshot。

## 126. 新坑：设备可见且 App 已安装时，`running` 复测仍为 503 应先收敛到设备侧 8100 未监听
- 坑点：触发条件、现象、影响范围：用户再次确认 iPhone 上 `Lobster WDA` 的 status 显示 `running`，且本机只读检查已证明目标 UDID `00008030-0001598021E2802E` 通过 USB 可见、`app.honey4212.crystal5671` 已安装。但 `probe-phase2-runtime.ps1 -SkipLaunch` 仍返回 `Status ready: False`、`Primary blocker: usb-status-not-ready`，USB `/status`、`/wda/network`、`/screenshot`、`/source` 均为 HTTP 503 且响应体为空；Bonjour 8 秒内没有发现 `_wda._tcp` 服务。影响范围是 Phase 2 runtime 恢复判断，不涉及 GitHub token、云构建或设备不可见问题。
- 根因：本次 relay 日志连续显示 `UsbmuxReplyCode.ConnectionRefused`，说明 Windows 侧 relay 能接入目标设备，但设备侧 8100 当前拒绝连接；这比 App UI 的 `running` 文案更接近实际网络状态。`/wda/network` 也无法返回，说明当前安装/运行的服务不能提供网络诊断证据。
- 处理：不要在该状态下继续重发 GitHub Actions、重签同一 IPA 或排查 token；先让用户在手机上执行服务 Stop/Start，或从任务切换器划掉 `Lobster WDA` 后重新打开并保持前台，再立即重跑 `probe-phase2-runtime.ps1 -SkipLaunch`。如果复位后仍是 503，再把问题收敛为 native host 生命周期/签名语义导致服务未监听，而不是云端构建问题。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-device-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -NoFail` 返回 `Device ready: True`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-installed-wda-apps.ps1 -DeviceUdid '00008030-0001598021E2802E' -BundleId 'app.honey4212.crystal5671' -NoFail` 返回 `Native host installed: True`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\probe-phase2-runtime.ps1 -DeviceUdid '00008030-0001598021E2802E' -BundleId 'app.honey4212.crystal5671' -OutputDirectory 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\status-running-reprobe-20260518-01' -SkipLaunch -NoFail` 返回四个 USB route 均为 503；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\probe-wda-bonjour.ps1 -DeviceUdid '00008030-0001598021E2802E' -ResolveServices -ProbeStatus -OutputDirectory 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\status-running-reprobe-20260518-01-bonjour' -NoFail` 返回 `Services found: 0`。
- 下次动作：恢复到“UI running 但电脑侧不通”时，先确认设备可见和 App 已安装，再只跑 `-SkipLaunch` runtime probe；若 relay 是 ConnectionRefused，则优先要求手机侧重启服务/重开 App，不要先回到 GitHub、token 或云构建链路。

## 127. 新坑：native host 不能在 `startServing` 前乐观标记 `Running`
- 坑点：触发条件、现象、影响范围：`LobsterWDAHost/AppDelegate.m` 曾在进入后台队列后先调用 `[self updateViewWithMessage:@"Running"]`，再调用 `[server startServing]`；同时 `webServerRunning` 也在 `startServing` 之前置为 `YES`。如果 `startServing` 尚未完成 HTTP 监听、启动失败或运行态漂移，手机 UI 会先显示 Running，但 USB `/status` 仍可能是 503。影响范围是 Phase 2 runtime 人工判断和后续真机复测顺序。
- 根因：`FBWebServer startServing` 内部先 `startHTTPServer`，再进入当前 run loop 保活；旧的 AppDelegate 没有启动成功回调，只能用“已经请求启动”代替“HTTP 已经监听”。`ViewController` 也只根据布尔值显示 Running/Stopped，导致 Starting 阶段容易被渲染成 Running。
- 处理：给 `FBWebServerDelegate` 增加可选 `webServerDidStartServing:` 回调，在 `startHTTPServer` 成功后触发；`AppDelegate` 在该回调里才设置 `webServerRunning=YES` 并显示 Running，`startWebServer` 只登记当前 server 并显示 Starting；`ViewController` 对 `Starting`/`Already starting` 显式显示 `Status: Starting`。
- 验证：先新增 `test/native-wda-host-smoke.mjs` 断言，要求 `webServerRunning = YES` 和 `updateViewWithMessage:@"Running"` 不得出现在 `[server startServing]` 之前，得到 RED；修复后 `node test/native-wda-host-smoke.mjs` 通过。相邻验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-default-target-repo-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-runtime-probe-tests.ps1` 均通过。
- 下次动作：凡是 UI 状态和 USB `/status` 冲突，先检查 Running 是否由 `webServerDidStartServing:` 这类启动成功证据驱动；不要再用“已发起启动”替代“HTTP 已监听”。真机最终仍必须用 USB `/status` 或 Wi-Fi `/status` 证明 ready。

## 128. 新坑：iOS 18.7 上 installation_proxy 可能完成安装但 CLI 不退出，不能只看超时判定失败
- 坑点：触发条件、现象、影响范围：新 cloud run `26009315286` 生成的 `LobsterWDAHost.unsigned.ipa` 已验证 ready，使用 distribution profile 生成 `LobsterWDAHost.distribution-experiment-26009315286.ipa` 后，`resign-native-wda.ps1 -Install` 卡在子进程 `tidevice install` 超过 10 分钟；随后直接 `tidevice install` 超过 3 分钟不退出，`pymobiledevice3 apps install --udid` 超过 5 分钟也不退出。影响范围是 Phase 2 实验安装 gate；不代表 IPA 静态结构失败，也不代表设备不可见。
- 根因：最小证据显示目标 UDID 仍可见，`report-native-host-artifacts.ps1` 判定新 IPA ready，`pymobiledevice3 apps query --udid ... app.honey4212.crystal5671` 能读取到目标 App 元数据；因此问题更接近 iOS 18.7/Windows 工具链的安装服务或安装完成后的 CLI 退出卡住。当前无法只凭超时区分“安装已完成但命令未退出”和“安装服务仍挂起”。
- 处理：安装命令超时后先查找并清理仅匹配该 IPA 路径的残留 `tidevice`/`pymobiledevice3`/`python` 子进程，再用 `report-ios-device-readiness.ps1`、`report-ios-installed-wda-apps.ps1`、`pymobiledevice3 apps query --udid` 做只读确认；不要无限重试安装，也不要在未确认的情况下自动卸载现有 App。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\continue-native-wda-goal.ps1 -Repo 'ds0515/0516_WDA' -Workflow 'wda-ios-unsigned-package.yml' -Ref 'lobster-wda-cloud-resign' -ExpectedHeadSha '0322f27876915ce69954e7a212d30689fb3d50ac' -BuildPackageKind 'native_host' -RunnerLabelsJson 'macos-15' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -ValidateIpaOnly -AllowDirtyCloudBuild` 成功回收 unsigned IPA；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-native-host-artifacts.ps1 -SearchRoot 'D:\2026_soft\0511_Appium_WDA\artifacts\lobster-wda-host' -NoFail` 显示 `LobsterWDAHost.distribution-experiment-26009315286.ipa` ready；`tidevice install` 和 `pymobiledevice3 apps install --udid 00008030-0001598021E2802E` 均超时；后续 `probe-phase2-runtime.ps1 -SkipLaunch` 仍为 USB 503，Bonjour 仍为 0 个服务。
- 下次动作：遇到安装 CLI 超时时，先要求用户在手机上关闭或重新打开目标 App、保持屏幕解锁，再决定是否重试安装；如需卸载重装，必须明确说明会删除当前 `Lobster WDA` App，并只对显式 UDID 操作。安装后仍必须由用户手动打开 App，再用 USB `/status` 和 Bonjour 证明运行态。

## 129. 新坑：签名脚本的安装步骤必须内建超时，不能只依赖外层命令超时
- 坑点：触发条件、现象、影响范围：`resign-native-wda.ps1 -Install` 以前直接同步执行 `& tidevice -u <UDID> install <ipa>`；当 iOS 18.7 installation_proxy 或 CLI 退出卡住时，外层 Codex 命令超时会截断当前进程，但子进程仍可能残留，后续还要手动查 `tidevice`/`python`/`powershell` 进程树。影响范围是 Phase 2 实验签名安装入口和长时间运行恢复效率。
- 根因：脚本没有安装超时参数，也没有掌控安装子进程生命周期；`tidevice install` 作为外部进程一旦挂起，脚本无法主动终止进程树和输出可复用的恢复提示。
- 处理：在 `resign-native-wda.ps1` 增加 `-InstallTimeoutSeconds`，默认 300 秒；安装时用 `Start-Process -PassThru -WindowStyle Hidden` 启动 `tidevice`，按超时等待，超时后调用进程树清理并报出包含显式 UDID 的错误提示；正常退出后继续执行 post-install installed-app report。
- 验证：先在 `test/resign-native-wda-script-tests.ps1` 用会卡住的假 `tidevice.cmd` 新增 RED 场景，要求 `-InstallTimeoutSeconds 1` 时失败并输出 `tidevice install timed out after 1 second` 且不泄漏测试密码；修复后 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\resign-native-wda-script-tests.ps1` 通过。相邻验证：`node test/native-wda-host-smoke.mjs`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-runtime-probe-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-default-target-repo-tests.ps1` 通过。
- 下次动作：任何真机安装都优先通过 `resign-native-wda.ps1 -InstallTimeoutSeconds <秒>` 运行；如果超时，按错误提示先让用户关闭目标 App、保持设备解锁，再决定是否卸载重装。不要再让外层 shell 超时成为唯一保护。

## 130. 新坑：覆盖安装超时后即使 App 元数据更新，仍必须手动重新打开再判定 runtime
- 坑点：触发条件、现象、影响范围：使用最新 `LobsterWDAHost.unsigned.ipa` 通过 distribution profile 重新签名并对显式 UDID `00008030-0001598021E2802E` 执行不卸载覆盖安装，`resign-native-wda.ps1 -InstallTimeoutSeconds 60` 在安装阶段超时；随后只读 `pymobiledevice3 apps query` 仍能看到 `app.honey4212.crystal5671`，且 App 元数据包含 `NSBonjourServices`、`NSLocalNetworkUsageDescription`、`CFBundleExecutable=LobsterWDAHost` 和 distribution 签名信息。但立即运行 `probe-phase2-runtime.ps1 -SkipLaunch` 时，USB `/status`、`/wda/network`、`/screenshot`、`/source` 仍全部为 HTTP 503，Bonjour 仍为 0 个服务。影响范围是覆盖安装超时后的 runtime 判定顺序。
- 根因：未定。最小证据只能说明安装命令没有正常返回、设备仍可见、App 元数据可读且包含网络声明；覆盖安装可能已完成或部分完成，但安装后 App 不一定保持前台运行，且 Windows 侧自动 launch 仍受 iOS 18.7 DeveloperImage/tunneld 限制。此时 `/status` 503 不能单独证明最新代码未安装，也不能证明最新代码已运行失败。
- 处理：覆盖安装超时后先检查是否有匹配 IPA 的残留 `tidevice`/`pymobiledevice3` 进程，再做只读设备和 App 元数据确认；如果 App 仍安装且设备可见，下一步应让用户在 iPhone 上手动重新打开 `Lobster WDA` 并保持前台，再立即执行 `probe-phase2-runtime.ps1 -SkipLaunch`。不要在用户未重新打开 App 前反复重签、重装或回到 GitHub 云构建。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\resign-native-wda.ps1 -InputIpa 'D:\2026_soft\0511_Appium_WDA\artifacts\lobster-wda-host\LobsterWDAHost-unsigned-ipa-26009315286\LobsterWDAHost.unsigned.ipa' -OutputIpa 'D:\2026_soft\0511_Appium_WDA\artifacts\lobster-wda-host\LobsterWDAHost.distribution-experiment-26009315286.ipa' -P12Path 'D:\2026_soft\0430_WS\0423_iPhone11\cert.p12' -MobileProvisionPath 'D:\2026_soft\0430_WS\0423_iPhone11\cert.mobileprovision' -PasswordPath 'D:\2026_soft\0430_WS\0423_iPhone11\password.txt' -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -AllowNonDevelopmentProfile -Install -InstallTimeoutSeconds 60` 返回 `tidevice install timed out after 60 seconds`；`pymobiledevice3 apps query --udid 00008030-0001598021E2802E app.honey4212.crystal5671` 能读到 App 元数据和 `NSBonjourServices`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\probe-phase2-runtime.ps1 -DeviceUdid '00008030-0001598021E2802E' -BundleId 'app.honey4212.crystal5671' -OutputDirectory 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\post-install-timeout-60-20260518-103028' -SkipLaunch -NoFail` 返回 `Primary blocker: usb-status-not-ready`；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\probe-wda-bonjour.ps1 -DeviceUdid '00008030-0001598021E2802E' -ResolveServices -ProbeStatus -OutputDirectory 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\post-install-timeout-60-20260518-103028-bonjour' -NoFail` 返回 `Services found: 0`。
- 下次动作：遇到覆盖安装超时但 App 元数据可读时，先要求手机侧手动重新打开 `Lobster WDA`，再跑 USB `/status` 和 Bonjour；只有手动重新打开后仍 503，才继续收敛到 native host 生命周期、签名语义或安装未完成问题。

## 131. 新坑：只用 `tidevice applist` 会隐藏签名和本地网络元数据
- 坑点：触发条件、现象、影响范围：`report-ios-installed-wda-apps.ps1` 以前优先使用 `tidevice applist --type user`，能证明 `app.honey4212.crystal5671` 已安装，但只能输出 bundle、名称、版本等基础字段，无法直接显示 `SignerIdentity`、`get-task-allow`、`NSBonjourServices` 或 `NSLocalNetworkUsageDescription`。影响范围是 Phase 2 恢复时判断“当前安装 App 是否具备 Bonjour/Local Network 声明、是否仍是 distribution 签名”的效率。
- 根因：`tidevice applist` 的列表输出本身就是精简文本，不包含完整安装元数据；`pymobiledevice3 apps list/query` 可以返回每个 App 的 JSON 元数据，其中包含签名、Entitlements 和 Info.plist 网络声明。
- 处理：让 `report-ios-installed-wda-apps.ps1` 优先使用 `pymobiledevice3`，解析并保留 matched app 的 `SignerIdentity`、`Entitlements.get-task-allow`、`NSBonjourServices` 和本地网络说明存在性；`pymobiledevice3` 不可用或失败时再回退 `tidevice`。人类可读输出拆成基础信息、`signing:` 和 `network:` 短行，避免 PowerShell 控制台宽度把关键字段名折断。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-installed-wda-apps-report-tests.ps1` 覆盖 RED/GREEN；`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-installed-wda-apps.ps1 -DeviceUdid '00008030-0001598021E2802E' -BundleId 'app.honey4212.crystal5671' -NoFail` 返回 `Tool used: pymobiledevice3`，并摘要显示 `get_task_allow=False`、`bonjour=_wda._tcp,_wda._tcp.`、`local_network_usage=True`。
- 下次动作：恢复 Phase 2 时先跑 installed-app report；如果它显示 `get_task_allow=False`，不要把当前安装包当成 UI automation 验收签名；如果 `bonjour` 或 `local_network_usage` 缺失，先回到 artifact/signing/install 链路，不要直接排查 Wi-Fi endpoint。

## 132. 新坑：USB `/status` 503 必须结合 relay 日志分类，不能只输出泛化 blocker
- 坑点：触发条件、现象、影响范围：`probe-phase2-runtime.ps1 -SkipLaunch` 访问 USB relay 后，`/status` 返回 HTTP 503 且响应体为空；同时 `relay.err.log` 出现 `UsbmuxReplyCode.ConnectionRefused`。旧报告只给 `Primary blocker: usb-status-not-ready`，容易把问题误判为 GitHub、artifact、签名脚本或 Wi-Fi，而不是设备侧 8100 当前拒绝连接。影响范围是 Phase 2 runtime 恢复顺序。
- 根因：HTTP 503 是本机 curl 对 relay 代理的结果，不足以说明设备侧实际状态；`relay.err.log` 的 `connect to device error: UsbmuxReplyCode.ConnectionRefused` 更直接说明 USB 已找到目标设备，但设备侧端口未接受连接。
- 处理：`probe-phase2-runtime.ps1` 增加 relay 日志解析：统计 `UsbmuxReplyCode.ConnectionRefused`，在报告中输出 `RelayDeviceConnectionRefused` 和 `RelayConnectionRefusedCount`；当 `/status` 未 ready 且存在该证据时，把 `PrimaryBlocker` 分类为 `usb-device-port-connection-refused`，并提示先手动重新打开 `Lobster WDA`、保持前台，再用显式 UDID 重跑 probe。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-runtime-probe-tests.ps1` 覆盖 RED/GREEN，断言 `Get-RelayDiagnosticsFromText` 能识别 ConnectionRefused，且 report/human output 都包含设备侧拒绝连接字段。
- 下次动作：恢复到 USB `/status` 503 时，先看 report 的 `RelayDeviceConnectionRefused`；若为 true，不要先重发云构建或重签同一 IPA，优先要求手机侧重新打开 App/重启服务后再复测。

## 133. 新坑：当前 Windows/iOS 18.7 工具链不能可靠自动关闭并重新打开 `Lobster WDA`
- 坑点：触发条件、现象、影响范围：用户授权“下回需要在手机上操作时自行关闭 app 重启打开”后，对显式 UDID `00008030-0001598021E2802E` 执行 `tidevice -u 00008030-0001598021E2802E kill app.honey4212.crystal5671` 和 `tidevice -u 00008030-0001598021E2802E launch app.honey4212.crystal5671`，二者都返回 exit code 1。影响范围是 Phase 2 runtime 复测前的自动 App 生命周期控制。
- 根因：两条命令都依赖 Instruments/Developer 服务；当前 iOS 18.7.7 环境下，`tidevice` 尝试下载 18.7 到 18.0 的 device support 后仍失败为 `DeveloperImage not found`。因此 kill/launch 与之前的 DVT launch、tidevice screenshot 属于同一类 DeveloperImage 工具链阻断。
- 处理：不要承诺 Codex 在当前 Windows 工具链下能自动关闭或重新打开 iPhone App；可以先尝试一次显式 UDID 的 `tidevice kill/launch`，但若出现 `DeveloperImage not found`，必须停止该自动重启路径，改由用户手动打开 App 或先解决 iOS 18.7.7 DeveloperImage/工具链支持。
- 验证：`tidevice -u 00008030-0001598021E2802E kill app.honey4212.crystal5671` 返回 `ServiceError: DeveloperImage not found`；`tidevice -u 00008030-0001598021E2802E launch app.honey4212.crystal5671` 同样返回 `ServiceError: DeveloperImage not found`。
- 下次动作：需要手机侧重启 App 时，先说明将尝试自动 `kill/launch`；如果命令失败为 DeveloperImage 阻断，直接要求人工操作，不要反复重试，也不要把失败归因到 IPA、GitHub 或 WDA 代码。

## 134. 新坑：runtime probe 的主阻断如果不透传到顶层 readiness，恢复后仍要翻 artifact 才能判断 503 类型
- 坑点：触发条件、现象、影响范围：`probe-phase2-runtime.ps1` 已经能在 runtime 子报告里输出 `PrimaryBlocker`、`RelayDeviceConnectionRefused` 和 `RelayConnectionRefusedCount`，但 `check-phase2-readiness.ps1` 只展示 `RuntimeReady`、时间戳和 launch 跳过状态。恢复上下文后，人类只能看到顶层 runtime 失败，仍要再打开 artifact 里的 runtime report 才能区分“UI automation 未授权”和“USB relay 已到设备但 8100 拒绝连接”。影响范围是 Phase 2 的顶层恢复入口，不涉及真机写操作、GitHub token 或签名材料。
- 根因：runtime probe 在 #132 已补齐 relay 日志分类，但顶层 readiness 聚合时没有读取这些字段，也没有在人类可读输出中打印它们；结构化消费者和人工恢复流程都缺少直接证据。
- 处理：在 `New-Phase2ReadinessReport` 中透传 `RuntimePrimaryBlocker`、`RuntimeRelayDeviceConnectionRefused`、`RuntimeRelayConnectionRefusedCount`；在 `Write-Phase2ReadinessReport` 中仅当字段存在时打印对应行，避免没有 runtime report 时制造噪声。
- 验证：先在 `test\phase2-readiness-tests.ps1` 增加 RED 断言，确认 `$blockedReport.RuntimePrimaryBlocker` 为 null；修复后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。
- 下次动作：恢复 Phase 2 时先看顶层 readiness 的 `Runtime primary blocker` 和 relay connection refused 字段；如果显示设备侧拒绝连接，优先重启/重开手机侧 App 后复测，不要先回到云构建、token、重签或 Wi-Fi 排查。

## 135. 新坑：顶层 readiness 只显示 `RuntimeReady=false` 会掩盖“HTTP 已起、UI 未授权、Wi-Fi 不通”的分层事实
- 坑点：触发条件、现象、影响范围：distribution 实验包手动打开后，runtime 子报告可同时证明 USB `/status` ready、`/wda/network` ready、ping iPhone 成功、TCP 8100 超时、UI automation 未授权；但顶层 `check-phase2-readiness.ps1` 以前只显示 `Runtime ready: False`、主阻断和少量 relay 信息。恢复上下文后容易把它误读成“WDA 完全没起”或“仍是 8100 拒绝连接”，而不是当前更精确的三层状态。影响范围是 Phase 2 runtime 恢复和下一步选择，不涉及真机写操作、GitHub token 或签名材料。
- 根因：runtime probe 已经结构化输出 `StatusReady`、`UiAutomationReady`、`WirelessReady`、`NetworkDiagnostics`、`WdaNetworkDiagnosticReady` 和 `WdaNetworkDiagnostics`，但 readiness 聚合没有透传这些字段，人类可读输出也没有分层打印。
- 处理：在 `New-Phase2ReadinessReport` 中透传 `RuntimeStatusReady`、`RuntimeUiAutomationReady`、`RuntimeWirelessReady`、`RuntimeNetworkPingSucceeded`、`RuntimeNetworkTcpOpen`、`RuntimeNetworkTcpError`、`RuntimeWdaNetworkDiagnosticReady`、`RuntimeWdaNetworkListenScope`、`RuntimeWdaNetworkInterface`、`RuntimeWdaNetworkWifiIp`；在 `Write-Phase2ReadinessReport` 中只在字段存在时打印。
- 验证：先在 `test\phase2-readiness-tests.ps1` 加 RED 断言，确认 `$blockedReport.RuntimeStatusReady` 为 null；修复后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。
- 下次动作：恢复 Phase 2 时先按层读 readiness：`Runtime status ready` 判断 HTTP 服务是否起；`Runtime UI automation ready` 判断 XCTest 授权；`Runtime network tcp` 和 Bonjour endpoint 判断无 USB 可达性。不要把单个 `Runtime ready: False` 当作唯一诊断结论。

## 136. 新坑：Bonjour 解析 hostname 带尾点时，状态探测不能只记录一种 URL 形态
- 坑点：触发条件、现象、影响范围：`dns-sd -L` 解析 `_wda._tcp` 时返回的 host 常是 `iPhone-11.local.`，旧 `probe-wda-bonjour.ps1` 只探测并记录 `http://iPhone-11.local.:8100/status`。当 endpoint 超时时，恢复上下文无法直接排除“尾点 hostname 表达导致 curl 行为不同”这一诊断分支，后续还要人工补测 `iPhone-11.local`。影响范围是 Phase 2 Bonjour endpoint 证据完整性，不涉及真机写操作、GitHub token、签名材料或 WDA 业务动作。
- 根因：Bonjour 解析器保留了 dns-sd 原始 host，状态探测 URL 直接由原始 host 拼接，没有生成去尾点的规范化候选 URL；报告中也就缺少 normalized hostname 的 curl 证据。
- 处理：新增 `Get-BonjourStatusProbeUrls`，对每个 resolved service 生成原始 host URL 和 `TrimEnd(".")` 后的 URL，并去重；`-ProbeStatus` 时对所有候选 URL 分别执行 curl 并写入 `StatusProbeResults`。
- 验证：先在 `test\wda-bonjour-probe-tests.ps1` 增加 RED 断言，要求 `iPhone-11.local.` 生成带尾点和去尾点两种 URL；修复后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\wda-bonjour-probe-tests.ps1` 通过。
- 下次动作：Bonjour endpoint 不 ready 时，先看 `StatusProbeResults` 是否同时包含原始 hostname 和 normalized hostname；如果两者都超时，再继续排查 iOS Local Network 权限、Wi-Fi/AP 隔离、监听暴露或 signing/XCTest runner 路径，不要停留在 hostname 尾点猜测上。

## 137. 新坑：顶层 readiness 不透传 Bonjour `/status` 探测结果时，恢复后仍要翻 artifact 才能判断 endpoint 细节
- 坑点：触发条件、现象、影响范围：`probe-wda-bonjour.ps1 -ProbeStatus` 已经把每个 Bonjour 候选 URL 的 HTTP code、curl exit code、响应字节数和 URL 写入 `StatusProbeResults`，但顶层 `check-phase2-readiness.ps1` 以前只显示 `Bonjour endpoint ready: False`。恢复上下文后仍要手动打开 Bonjour artifact，才能确认是否同时测过原始 hostname 和 normalized hostname，以及失败是 timeout 还是其它 curl 状态。影响范围是 Phase 2 顶层恢复入口，不涉及真机写操作、GitHub token、签名材料或 WDA 业务动作。
- 根因：`New-Phase2ReadinessReport` 没有读取 `BonjourReport.StatusProbeResults`，`Write-Phase2ReadinessReport` 也没有对应的人类可读输出段落；因此 Bonjour 子报告已经存在的诊断证据没有被聚合到 Phase 2 总入口。
- 处理：在顶层 readiness 结果中新增 `BonjourStatusProbeCount` 和 `BonjourStatusProbeSummaries`，摘要格式固定为 `http=<code>, exit=<exit>, bytes=<bytes>, url=<url>`；人类可读输出新增 `Bonjour status probes:` 和 `Bonjour status probe results:` 段落。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\wda-bonjour-probe-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-runtime-probe-tests.ps1`、`node test/native-wda-host-smoke.mjs` 均通过；真实只读验证命令 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -TargetRepo 'ds0515/0516_WDA' -RuntimeReportPath 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\resume-reprobe-20260518-105405\phase2-runtime-report.json' -BonjourReportPath 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\bonjour-normalized-20260518-01\bonjour-report.json' -NoFail` 已显示 `Bonjour status probes: 2`，并列出 `http://iPhone-11.local.:8100/status` 与 `http://iPhone-11.local:8100/status` 两条 timeout 证据。
- 下次动作：恢复 Phase 2 时优先看顶层 readiness 的 `Bonjour status probe results`；如果原始 hostname 和 normalized hostname 都 timeout，就继续排查 iOS Local Network 权限、Wi-Fi/AP 隔离、监听暴露或 development/XCTest 授权路径，不要再重复手工补测同一 hostname 变体。

## 138. 新坑：`agent-runner.ipa` 结构像可用 runner，不代表能安装到当前 UDID
- 坑点：触发条件、现象、影响范围：当前输入 `D:\2026_soft\0430_WS\0423_iPhone11\agent-runner.ipa` 是 XCTest runner 形态，包含 `PlugIns/*.xctest`、`WebDriverAgentLib.framework`、`iosauto.framework`、`FBWebServer` 标记和 `agent_port.txt=19999`。如果只看包结构，很容易把它误当成当前 iPhone 11 的 Phase 2 安装候选；但 embedded profile 的 `ProvisionedDevices` 不包含显式 UDID `00008030-0001598021E2802E`。影响范围是两 App runner 路径的下一步选择，不涉及读取 GitHub token、真机写操作、安装或启动。
- 根因：XCTest runner 包形态和签名 profile 覆盖范围是两个独立 gate。`agent-runner.ipa` 的 profile 是 development 且 `get-task-allow=true`，但只覆盖 1 台其它设备；当前目标 UDID 不在 profile 内，因此即使 runner 内含 WDA 能力，也不能直接作为当前设备的可安装验证入口。
- 处理：新增只读报告脚本 `Scripts\report-phase2-input-ipas.ps1`，固定检查 `release.ipa` 和 `agent-runner.ipa` 的 Info.plist、XCTest plug-in、嵌套 framework、端口文件、FBWebServer 标记，以及 embedded profile 的最小摘要；人类可读输出只打印 profile UUID、kind、get-task-allow、设备数量、是否包含目标 UDID和是否过期，不打印完整设备列表或 profile 内容。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-input-ipa-report-tests.ps1` 通过；真实只读命令 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-input-ipas.ps1 -MainIpaPath 'D:\2026_soft\0430_WS\0423_iPhone11\release.ipa' -AgentIpaPath 'D:\2026_soft\0430_WS\0423_iPhone11\agent-runner.ipa' -DeviceUdid '00008030-0001598021E2802E' -NoFail` 返回 `Agent IPA XCTest runner: True`、`Agent IPA WebDriverAgentLib.framework: True`、`Agent profile kind: development`、`Agent profile includes target UDID: False`、`Agent install candidate ready: False`。
- 下次动作：继续 Phase 2 两 App runner 路径前，先跑 `report-phase2-input-ipas.ps1`。如果 `Agent profile includes target UDID=False`，不要安装该 agent-runner；下一步只能重签/重构建一个覆盖当前 UDID 的 development XCTest runner，或继续使用自有 native host + runner 授权链路实验。

## 139. 新坑：agent-runner 输入诊断如果只在独立脚本里，顶层 Phase 2 恢复仍会漏掉两 App 路径阻塞
- 坑点：触发条件、现象、影响范围：`report-phase2-input-ipas.ps1` 已经能证明 `agent-runner.ipa` 是 runner 形态但 profile 不含当前 UDID；但如果顶层 `check-phase2-readiness.ps1` 不透传这些字段，恢复上下文时仍只能看到 Signing、Runtime、Wi-Fi 阻塞，容易再次把 `agent-runner.ipa` 当作下一步安装候选。影响范围是 Phase 2 两 App runner 路径恢复判断；不涉及读取 GitHub token、安装、启动或访问业务 App。
- 根因：input IPA 形态检查是独立只读报告，顶层 readiness 以前没有调用它，也没有保存 `AgentInstallCandidateReady`、runner bundle id、XCTest plug-in、WDA framework、profile UDID 覆盖等摘要字段。
- 处理：`check-phase2-readiness.ps1` 在显式 `-DeviceUdid` 存在且脚本可用时调用 `report-phase2-input-ipas.ps1 -AsJson -NoFail`；顶层报告新增 `AgentInputInstallCandidateReady`、`AgentInputBundleId`、`AgentInputHasXCTestPlugin`、`AgentInputHasWebDriverAgentLibFramework`、`AgentInputProfileIncludesTargetUdid` 等字段，并把 input IPA blocker/next action 作为诊断透传。该诊断不改变当前 gate 排序，当前仍优先停在 Signing。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-input-ipa-report-tests.ps1`、`node test/native-wda-host-smoke.mjs` 通过；真实只读命令 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -TargetRepo 'ds0515/0516_WDA' -RuntimeReportPath 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\live-reprobe-20260518-111306\phase2-runtime-report.json' -BonjourReportPath 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\live-bonjour-20260518-111329\bonjour-report.json' -NoFail` 已显示 `Agent input install candidate ready: False`、`Agent input profile includes target UDID: False`，并在 Blocking issues 中输出 `Input IPA: Agent runner embedded profile does not include target UDID 00008030-0001598021E2802E.`。
- 下次动作：恢复 Phase 2 时直接看顶层 readiness 的 `Agent input ...` 段落；如果该段落显示 install candidate false，不要安装 `agent-runner.ipa`，先解决覆盖当前 UDID 的 development runner 来源，或继续自有 native host + runner 授权链路实验。

## 140. 新坑：只检查 native host 签名会漏掉 XCTest runner 的独立签名 gate
- 坑点：触发条件、现象、影响范围：Phase 2 两 App 路径需要 `app.honey4212.crystal5671.xctrunner` 这个 XCTest runner 也具备 development profile；旧顶层 readiness 只检查 native host bundle `app.honey4212.crystal5671`，会把 runner 签名缺口隐藏在后续安装或启动失败里。影响范围是 Phase 2 runner 授权链路判断；不涉及读取 GitHub token、安装、启动或输出证书私密内容。
- 根因：`check-phase2-readiness.ps1` 只调用一次 `report-ios-signing-profiles.ps1 -BundleId app.honey4212.crystal5671`。但 XCTest runner 是独立 app bundle id，签名 profile 需要单独覆盖 `app.honey4212.crystal5671.xctrunner` 和当前 UDID。当前真实只读结果显示：native host 的最接近 profile 是 distribution 且 `get-task-allow=false`；runner 侧同一个最接近 profile 还额外不覆盖 `.xctrunner` bundle id。
- 处理：顶层 readiness 新增 `RunnerSigningReport` 聚合，CLI 会用同一显式 UDID 再调用一次 `report-ios-signing-profiles.ps1 -BundleId app.honey4212.crystal5671.xctrunner`；输出 `Native signing ready`、`Runner signing ready` 和 runner replacement requirements。组合 `SigningReady` 只有 native signing 与 runner signing 均 ready 时才为 true；缺 runner profile 时仍停在 Signing gate。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-input-ipa-report-tests.ps1`、`node test/native-wda-host-smoke.mjs` 通过；真实只读命令 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -TargetRepo 'ds0515/0516_WDA' -RuntimeReportPath 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\live-reprobe-20260518-111306\phase2-runtime-report.json' -BonjourReportPath 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\live-bonjour-20260518-111329\bonjour-report.json' -NoFail` 已显示 `Native signing ready: False`、`Runner signing ready: False`、`Runner signing replacement bundle id: app.honey4212.crystal5671.xctrunner`，并输出 runner signing blockers。
- 下次动作：恢复 Phase 2 时不要只看 native host signing。必须同时看 `Native signing ready` 和 `Runner signing ready`；如果 runner 为 false，下一步需要覆盖 `app.honey4212.crystal5671.xctrunner` 和 `00008030-0001598021E2802E` 的 Apple Development profile，不能继续安装现有 runner 或把失败归因到 GitHub/cloud build。

## 141. 新坑：native 和 runner 同时签名阻塞时，顶层下一步动作不能只优先 native profile
- 坑点：触发条件、现象、影响范围：当 `app.honey4212.crystal5671` 和 `app.honey4212.crystal5671.xctrunner` 都缺少覆盖目标 UDID 的 Apple Development profile 时，旧顶层 `NextRequiredAction` 会先取 native signing 的第一条 action。这样恢复上下文时容易只重做 native host profile，漏掉 runner 仍需要独立 development profile 的事实。影响范围是 Phase 2 Signing gate 的人工排障入口；不涉及真机写操作、GitHub token、p12 或 mobileprovision 内容输出。
- 根因：`check-phase2-readiness.ps1` 已经把 native 和 runner blocking issues 都加入顶层报告，但 `NextRequiredAction` 和 Signing gate 的 preferred action 排序仍按 native 优先返回，缺少“双签名同时阻塞”的合并动作。
- 处理：新增合并签名动作生成逻辑；当 native 和 runner 两个 signing report 都不是 `HasWirelessPhase2Profile=true` 且都提供 `ReplacementRequirements` 时，顶层 action 先输出一条合并说明，明确 `app.honey4212.crystal5671`、`app.honey4212.crystal5671.xctrunner`、显式 UDID `00008030-0001598021E2802E`、`Apple Development` 和 `get-task-allow=true`。该动作只改变诊断文本和排序，不改变 Signing gate 顺序。
- 验证：先在 `test\phase2-readiness-tests.ps1` 增加 native+runner 双阻塞 RED 断言；修复后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-input-ipa-report-tests.ps1`、`node test/native-wda-host-smoke.mjs` 均通过。真实只读命令 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -TargetRepo 'ds0515/0516_WDA' -RuntimeReportPath 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\live-reprobe-20260518-111306\phase2-runtime-report.json' -BonjourReportPath 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\live-bonjour-20260518-111329\bonjour-report.json' -NoFail` 已显示合并后的 `Next required action`，并把该合并动作排在 `Next actions` 第一条。
- 下次动作：恢复 Phase 2 且 `Native signing ready=False`、`Runner signing ready=False` 时，先按顶层合并 action 同时准备 native host 与 runner 的 Apple Development profile；不要只替换 `app.honey4212.crystal5671` 的 distribution profile，也不要在 runner profile 未覆盖 `.xctrunner` 前继续安装或判定 runtime。

## 142. 新坑：目标 WDA bundle 已安装不代表 Phase 2 安装态可验收
- 坑点：触发条件、现象、影响范围：当前 iPhone 上能列出 `app.honey4212.crystal5671`，且 `NSBonjourServices`、`NSLocalNetworkUsageDescription` 都存在，但安装元数据里的 `get-task-allow=False`。旧 installed-app gate 只看 `AnyTargetInstalled=true`，会把 distribution 签名包误当成已通过安装态，后续才在 runtime 里表现为 `ui-automation-not-authorized`。影响范围是 Phase 2 installed-app gate 与 runtime 前置顺序；不涉及安装、启动、读取 GitHub token、输出 p12 或 mobileprovision 内容。
- 根因：`report-ios-installed-wda-apps.ps1` 已经从 `pymobiledevice3` 解析出 `SignerIdentity` 和 `Entitlements.get-task-allow`，但报告对象没有独立的 `Phase2InstallReady` 字段；顶层 readiness 也只消费 `AnyTargetInstalled`，没有区分“bundle 存在”和“安装态满足 Phase 2 development signing”。
- 处理：installed-app 报告新增 `Phase2InstallReady`。当目标 WDA bundle 的安装元数据明确显示 `get-task-allow=False` 时，保留 `AnyTargetInstalled=true` 这个事实，但把 `Phase2InstallReady=false`，并输出重新使用 Apple Development profile 安装的 next action。`check-phase2-readiness.ps1` 优先消费 `Phase2InstallReady`，只有旧报告没有该字段时才回退到 `AnyTargetInstalled`。
- 验证：先在 `test\ios-installed-wda-apps-report-tests.ps1` 增加 RED 断言，要求 `get-task-allow=false` 的目标 app 不能满足 `Phase2InstallReady`；修复后 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-installed-wda-apps-report-tests.ps1` 通过。相邻验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`node test/native-wda-host-smoke.mjs` 通过。真实只读命令 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-installed-wda-apps.ps1 -DeviceUdid '00008030-0001598021E2802E' -BundleId 'app.honey4212.crystal5671' -RunnerBundleId 'app.honey4212.crystal5671.xctrunner' -NoFail` 返回 `Any target installed: True` 但 `Phase 2 install ready: False`，并明确 blocker 为 `get-task-allow=False`。
- 下次动作：恢复 Phase 2 时不要把 `Any target installed: True` 当作安装态验收。必须看 `Phase 2 install ready`；如果为 false，先重装 development-signed native host/runner，再做 runtime 或 Bonjour endpoint 验证。

## 143. 新坑：安装态缺少 `get-task-allow` 元数据时，也不能按 Phase 2 ready 放行
- 坑点：触发条件、现象、影响范围：当 installed-app 只来自 `tidevice applist` 这类精简输出时，能看到目标 bundle 已安装，但看不到 `Entitlements.get-task-allow`。如果报告把“没有看到 `false`”当成通过，就会让缺少 signing metadata 的安装态进入 runtime 阶段，影响 Phase 2 验收证据强度；不涉及真机写操作、GitHub token、证书或 profile 私密内容。
- 根因：#142 只阻断了明确 `get-task-allow=False` 的情况；`GetTaskAllow=$null` 仍继承 `AnyTargetInstalled=true`，把“证据缺失”误当成“没有反证”。这不符合 Phase 2 对 development signing 的前置要求。
- 处理：`report-ios-installed-wda-apps.ps1` 在目标 app 的 `get-task-allow` 元数据缺失时也设置 `Phase2InstallReady=false`，并提示重新使用能返回安装元数据的 `pymobiledevice3` 路径生成 installed-app 报告。只有明确拿到 `get-task-allow=true`，或后续其它强证据证明 development-signed 安装态时，才能放行到 runtime。
- 验证：先把 `test\ios-installed-wda-apps-report-tests.ps1` 的 tidevice 精简输出场景改成 RED，要求 `Phase2InstallReady=false` 且 blocker 包含 `get-task-allow metadata is unavailable`；修复后 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\ios-installed-wda-apps-report-tests.ps1` 通过。相邻验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`node test/native-wda-host-smoke.mjs` 通过。真实只读命令 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-installed-wda-apps.ps1 -DeviceUdid '00008030-0001598021E2802E' -BundleId 'app.honey4212.crystal5671' -RunnerBundleId 'app.honey4212.crystal5671.xctrunner' -NoFail` 当前仍由 `pymobiledevice3` 返回明确 `get_task_allow=False`，并保持 `Phase 2 install ready: False`。
- 下次动作：installed-app gate 的判断顺序必须是：先确认显式 UDID，再确认目标 bundle，再确认 `get-task-allow=true`。如果缺少该元数据，先修复报告工具链或换用可返回 entitlements 的只读命令，不要继续 runtime/Bonjour 验收。

## 144. 新坑：卸载事实被写入文档后，后续覆盖安装会让“当前已卸载”表述反向误导
- 坑点：触发条件、现象、影响范围：用户曾手动卸载 iPhone 上的 IPA，文档因此把多处 runtime、Bonjour、installed-state 证据降级为 historical；后续又通过 distribution profile 覆盖安装 `app.honey4212.crystal5671` 后，`docs/offline-automation-v1.md` 仍保留“当前 iPhone IPA 已卸载”“没有当前 installed-state evidence”的入口描述。恢复 Phase 2 时会误以为下一步是重新安装任意 IPA，而不是读取当前 installed-app 报告并识别 `Phase2InstallReady=false`。影响范围是 Phase 2 恢复入口和下一步 gate 排序；不涉及真机写操作、GitHub token、p12 或 mobileprovision 内容。
- 根因：旧证据降级是正确的，但文档没有在新的 live installed-app/readiness 报告生成后同步区分“旧日志因卸载仍是 historical”和“当前设备已有 distribution-signed native host 但不满足 Phase 2 install ready”这两层事实。
- 处理：在 `docs/offline-automation-v1.md` 增加 `Current live Phase 2 status (2026-05-18)`，记录 `Native host installed=True`、`Runner installed=False`、`Phase 2 install ready=False`、`Runtime primary blocker=ui-automation-not-authorized`、Bonjour endpoint timeout、`Next required gate=Signing`；同时移除或改写“current iPhone IPA has been uninstalled”“no current installed-state evidence after uninstall”等当前态表述。
- 验证：先在 `test\native-wda-host-smoke.mjs` 增加 RED 断言，要求文档包含当前 live 状态并禁止旧的“当前已卸载”入口短语；运行 `node test/native-wda-host-smoke.mjs` 失败在缺少 `Current live Phase 2 status (2026-05-18)`。修复文档后同一命令通过。真实只读佐证命令为 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-installed-wda-apps.ps1 -DeviceUdid '00008030-0001598021E2802E' -BundleId 'app.honey4212.crystal5671' -RunnerBundleId 'app.honey4212.crystal5671.xctrunner' -NoFail` 和 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -TargetRepo 'ds0515/0516_WDA' -RuntimeReportPath 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\live-reprobe-20260518-111306\phase2-runtime-report.json' -BonjourReportPath 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\live-bonjour-20260518-111329\bonjour-report.json' -NoFail`。
- 下次动作：每次手机安装状态发生变化后，同时更新 Phase 2 文档中的“当前状态”和“历史证据”两类段落；旧日志可以继续标为 historical，但当前入口必须以最新 installed-app/readiness 报告为准，并优先显示 `Phase2InstallReady`、`Native signing ready`、`Runner signing ready` 和 `Next required gate`。

## 145. 新坑：无续费/无 Mac 约束下不能把“能重签”误当成 Phase 2 可验收签名路径
- 坑点：触发条件、现象、影响范围：用户明确不想续费 Apple Developer、没有 Mac，并希望寻找其它方案。若文档只写“需要 Apple Development profile”，长期恢复时容易反复尝试现有 distribution profile、第三方重签、云端 unsigned build、或不含目标 UDID 的 runner，并把“能安装/能启动 `/status`”误判成 Phase 2 签名已通过。影响范围是 Phase 2 Signing gate 的决策入口；不涉及读取 GitHub token、打印证书密码、输出 p12 或 mobileprovision 内容。
- 根因：Phase 2 验收需要两个独立 bundle id 的 development signing 证据：`app.honey4212.crystal5671` 和 `app.honey4212.crystal5671.xctrunner` 都必须覆盖显式 UDID `00008030-0001598021E2802E` 且 `get-task-allow=true`。云端 macOS unsigned build、distribution/ad hoc profile、或只覆盖其它 UDID 的 runner profile，都不能替代这个 gate。
- 处理：在 `docs/offline-automation-v1.md` 增加 `Phase 2 signing path decision (no renewal/no Mac)`，明确可验收路径只接受能产出两个 development-signed IPA 的方案；现有 distribution profile 只允许用于已知阻塞复现；free/personal Apple ID 路径必须先产出 `get-task-allow=true` 且覆盖目标 UDID 的 profile 才算可评估；禁止使用签名、entitlement、jailbreak 或平台访问控制绕过。
- 验证：先在 `test\native-wda-host-smoke.mjs` 增加 RED 断言，要求文档包含无续费/无 Mac 签名路径合同；运行 `node test/native-wda-host-smoke.mjs` 失败在缺少 `Phase 2 signing path decision (no renewal/no Mac)`。补文档后同一命令通过。真实只读签名佐证继续由 `report-ios-signing-profiles.ps1` 和顶层 readiness 输出 `Native signing ready=False`、`Runner signing ready=False`、`Next required gate=Signing`。
- 下次动作：遇到“其它签名方案”时，先检查它能否提供两个 bundle id、目标 UDID 和 `get-task-allow=true` 的 profile 证据；不能提供时不要安装、启动或进入 runtime 验收。只允许把 distribution profile 用作已知失败复现，不得作为 Phase 2 acceptance。

## 146. 新坑：签名路径边界只写在文档里，顶层 readiness 仍可能被当成可继续执行
- 坑点：触发条件、现象、影响范围：`docs/offline-automation-v1.md` 已经写清无续费/无 Mac 情况下的签名路径合同，但 `check-phase2-readiness.ps1` 仍只输出 `Signing ready=False`、replacement requirements 和 next action。恢复上下文或自动化消费顶层 JSON 时，如果没有人工读 PRD，仍可能只看到“有 ready artifact、设备可见、USB /status 可用”，然后继续尝试安装、启动或 runtime probe。影响范围是 Phase 2 顶层恢复入口和后续自动化 gating；不涉及真机写操作或密钥内容。
- 根因：签名验收边界没有结构化字段。`ReplacementRequirements` 说明了缺什么 profile，但没有直接表达 distribution profile 只能复现、bypass 不允许、只有 development-signed native+runner 才可验收这些决策。
- 处理：`check-phase2-readiness.ps1` 新增 `SigningPathStatus`、`SigningPathDecision`、`SigningPathRequiredBundleIds`、`SigningPathRequiredProfileKind`、`SigningPathRequiresGetTaskAllow`、`SigningPathAllowsDistributionAcceptance`、`SigningPathBypassAllowed`，并在人类可读输出中打印 `Signing path ...` 行。该变更只增强诊断，不改变 gate 顺序。
- 验证：先在 `test\phase2-readiness-tests.ps1` 增加 RED 断言，要求 both-signing blocker report 暴露 `SigningPathStatus=blocked`、`SigningPathAllowsDistributionAcceptance=false`、`SigningPathBypassAllowed=false` 和两个 bundle id；运行测试失败在缺少 `SigningPathStatus`。实现后 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过，并用 `node test/native-wda-host-smoke.mjs` 覆盖脚本文本。真实只读 readiness 仍显示 `Next required gate=Signing`。
- 下次动作：Phase 2 恢复时先读顶层 readiness 的 `Signing path ...` 行；只要 `SigningPathStatus=blocked` 或 `SigningPathAllowsDistributionAcceptance=false` 与现有 distribution profile 组合出现，就不要继续安装/启动/runtime 验收。

## 147. 新坑：用户已授权需要手机侧操作时优先自动关闭并重新打开 App，但仍必须受显式 UDID 和工具链失败边界约束
- 坑点：触发条件、现象、影响范围：用户明确要求“下回需要在手机上操作的，自行关闭 app 重启打开”。如果后续恢复上下文时只记住 #133 的 `DeveloperImage not found` 失败，可能会过早要求用户手动操作；如果只记住用户授权，又可能在没有显式设备或命令失败后反复尝试自动控制。影响范围是 Phase 2 runtime 复测前的手机侧 App 生命周期控制，不涉及签名、GitHub token、安装 profile 或业务 App 操作。
- 根因：操作权限和当前工具链能力是两层事实。用户已经授权 Codex 在需要手机侧重启 App 时主动执行关闭/打开；但当前 Windows + iOS 18.7.7 路径中，`tidevice kill/launch` 已被验证可能因 `DeveloperImage not found` 失败，不能把授权等同于一定可自动完成。
- 处理：后续需要手机侧重启 `Lobster WDA` 时，先使用显式 UDID `00008030-0001598021E2802E` 对 `app.honey4212.crystal5671` 尝试一次自动关闭并重新打开；命令成功后立即跑对应 runtime/Bonjour 健康检查。若返回 `DeveloperImage not found` 或同类 Developer 服务阻断，停止自动重启路径，保留失败上下文并请用户手动打开，不要重复重试。
- 验证：本条只记录用户授权和后续执行顺序，未执行真机写操作。历史验证见 #133：`tidevice -u 00008030-0001598021E2802E kill app.honey4212.crystal5671` 和 `tidevice -u 00008030-0001598021E2802E launch app.honey4212.crystal5671` 均曾返回 `ServiceError: DeveloperImage not found`。
- 下次动作：凡是后续需要手机侧操作，默认由 Codex 先尝试显式 UDID 的自动关闭/打开；只有自动命令失败、设备不在显式 UDID、或出现验证码/风控/异常登录/限制/封禁等安全停止条件时，才要求用户介入。

## 148. 新坑：文档 smoke 断言不能假设 Markdown 句子保持单行
- 坑点：触发条件、现象、影响范围：为 `docs/offline-automation-v1.md` 新增手机侧 App 生命周期策略后，`node test/native-wda-host-smoke.mjs` 先正确 RED 于缺少 `Phone-side App lifecycle policy`；补文档后第二次运行仍失败，因为断言写成 ``/first try an explicit-UDID app restart for `app\.honey4212\.crystal5671`/``，而文档中该句按 80 列自然换行，把 `for` 与 bundle id 分成两行。影响范围是 Phase 2 文档类 smoke 回归，不涉及真机、签名、GitHub token 或 WDA 行为。
- 根因：文档的可读换行与正则断言的单行假设不一致。测试想验证的是语义短语和 bundle id 同时存在，而不是强制 Markdown 物理行不换行。
- 处理：把断言改为允许空白和换行的形式：``/first try an explicit-UDID app restart for\s+`app\.honey4212\.crystal5671`/``。文档仍保持正常换行，测试语义不变。
- 验证：`node test/native-wda-host-smoke.mjs` 先失败在缺少 `Phone-side App lifecycle policy`，补文档后失败在精确单行匹配，修正正则后通过并输出 `native WDA host smoke checks passed`。
- 下次动作：为 Markdown 文档写 smoke 断言时，涉及跨行概率高的自然语言句子统一使用 `\s+` 或拆成多个关键片段断言；不要用单行精确正则绑定文档排版。

## 149. 新坑：只在文档里授权手机侧重启 App，不等于 runtime probe 有可执行入口和结构化证据
- 坑点：触发条件、现象、影响范围：用户已授权后续需要手机侧操作时由 Codex 自行关闭并重新打开 `Lobster WDA`，主文档也记录了该策略，但 `probe-phase2-runtime.ps1` 仍只有 launch 路径，没有显式“先 kill 再 launch”的入口，也不会把 `DeveloperImage not found` 作为 app 生命周期阻断写入 runtime report。影响范围是 Phase 2 真机 runtime 复测前的 App 生命周期控制，不涉及签名绕过、GitHub token、安装 profile 或业务 App 操作。
- 根因：此前 #147 只把授权和边界写进文档/经验，执行脚本仍只能“尝试 launch”或 `-SkipLaunch`，缺少可由后续流程明确调用的 `-RestartAppBeforeProbe` gate；同时 readiness 只能看到 runtime 结果，看不到“请求过重启但被 DeveloperImage 工具链挡住”这一前置事实。
- 处理：`probe-phase2-runtime.ps1` 新增 `-RestartAppBeforeProbe`。该开关在显式 UDID 下先执行 `tidevice -u <UDID> kill <bundle-id>`，若未被 `DeveloperImage not found` 阻断，再走既有 launch fallback；runtime report 新增 `RestartAttempted`、`RestartSucceeded`、`RestartBlockedByDeveloperImage`、`RestartMessages`，人类可读输出也打印 App restart 状态。请求重启但被 DeveloperImage 阻断时，`Phase2RuntimeReady=false` 并提示手动重新打开 `Lobster WDA`。
- 验证：先在 `test\phase2-runtime-probe-tests.ps1` 和 `test\native-wda-host-smoke.mjs` 增加 RED 断言，确认缺少 `-RestartAppBeforeProbe`；实现后 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-runtime-probe-tests.ps1`、`node test/native-wda-host-smoke.mjs`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 均通过。
- 下次动作：需要手机侧重启 `Lobster WDA` 再做 runtime 复测时，优先使用 `probe-phase2-runtime.ps1 -DeviceUdid <显式UDID> -BundleId app.honey4212.crystal5671 -RestartAppBeforeProbe -NoFail`；如果 report 显示 `RestartBlockedByDeveloperImage=True`，停止自动重启路径并要求人工打开 App，不要继续把失败归因到 GitHub、IPA 包结构或 Wi-Fi endpoint。

## 150. 新坑：runtime probe 已记录 App 重启状态时，顶层 readiness 也必须透传这些字段
- 坑点：触发条件、现象、影响范围：`probe-phase2-runtime.ps1 -RestartAppBeforeProbe` 已能在 runtime report 中记录 `RestartAttempted`、`RestartSucceeded`、`RestartBlockedByDeveloperImage` 和 `RestartMessages`，但 `check-phase2-readiness.ps1` 仍只透传 `LaunchSkipped`、`RunnerStartSkipped` 等旧字段。恢复 Phase 2 时只看顶层 readiness 会不知道自动关闭/打开 App 是否已经尝试、是否成功、是否被 `DeveloperImage not found` 阻断，容易继续下钻 runtime artifact 或误判为 GitHub/IPA/Wi-Fi 问题。影响范围是 Phase 2 顶层恢复入口和人工排障顺序，不涉及真机写操作、签名绕过、GitHub token 或证书内容。
- 根因：#149 新增的是 runtime probe 的执行入口和报告字段，顶层 readiness 的聚合字段没有同步扩展；测试也只覆盖 runtime probe 本身，没有要求 readiness JSON 和人类可读输出暴露同一组 App 生命周期证据。
- 处理：`check-phase2-readiness.ps1` 从 runtime report 读取并输出 `RuntimeRestartAttempted`、`RuntimeRestartSucceeded`、`RuntimeRestartBlockedByDeveloperImage`、`RuntimeRestartMessages`；人类可读输出新增 `Runtime app restart attempted/succeeded/blocked by DeveloperImage/messages` 行。`test\phase2-readiness-tests.ps1` 用包含 `DeveloperImage not found` 的 runtime fixture 锁定 JSON 字段和文本输出，`test\native-wda-host-smoke.mjs` 增加脚本文本 smoke 断言。
- 验证：先运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`，失败在 `RuntimeRestartAttempted` 为空；实现后同一命令通过。相邻验证：`node test/native-wda-host-smoke.mjs` 和 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-runtime-probe-tests.ps1` 均通过。
- 下次动作：恢复 Phase 2 时优先看顶层 readiness 的 `Runtime app restart ...` 行。如果 `RuntimeRestartBlockedByDeveloperImage=True`，停止自动重启路径并要求手动打开 `Lobster WDA`；不要再要求先打开 runtime artifact 才能判断 App 生命周期阻断。

## 151. 新坑：Signing gate 卡住时，先做扩大范围 profile 扫描，再判断是否需要用户提供新签名材料
- 坑点：触发条件、现象、影响范围：顶层 readiness 默认只扫描固定 profile 根目录；如果用户后来把新的 `.mobileprovision` 放到 `D:\2026_soft` 其它位置，恢复流程可能误判为“缺 profile”，也可能反过来反复怀疑脚本默认搜索根漏掉材料。本次扩大只读扫描到 `D:\2026_soft` 后，native host 仍只有 `app.honey4212.crystal5671` 的 distribution profile 可复用，runner 侧没有覆盖 `app.honey4212.crystal5671.xctrunner` 的 Phase 2-ready profile。影响范围是 Phase 2 Signing gate 的下一步判断，不涉及 p12、证书密码、GitHub token、安装或真机操作。
- 根因：签名材料是否存在与默认 readiness 搜索根是否覆盖到材料是两个不同问题；只有扩大搜索后仍找不到 `development + get-task-allow=true + bundle 覆盖 + UDID 覆盖` 的 profile，才能把下一步收敛为“需要用户提供新的 Apple Development profile”，而不是继续调脚本或重试 GitHub/cloud。
- 处理：在 Signing gate 阻塞且怀疑本地可能新增 profile 时，先分别运行 native 和 runner 的 `report-ios-signing-profiles.ps1 -SearchRoot 'D:\2026_soft' -AsJson -NoFail`；再运行 `continue-native-wda-goal.ps1 -ProfileSearchRoot 'D:\2026_soft' -AutoResolveMobileProvisionPath -PreflightOnly -SkipRemoteHeadCheck -AllowDirtyCloudBuild` 作为只读 preflight。若仍提示 `No Phase 2-ready Apple Development profile found`，停止安装、启动、runtime probe 和云端排障，把下一步限定为补齐两份 Development profile。
- 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-ios-signing-profiles.ps1 -BundleId 'app.honey4212.crystal5671' -DeviceUdid '00008030-0001598021E2802E' -SearchRoot 'D:\2026_soft' -AsJson -NoFail` 返回 `HasWirelessPhase2Profile=false`，closest reusable profile 为现有 distribution profile 且 `GetTaskAllow=false`；`... -BundleId 'app.honey4212.crystal5671.xctrunner' ...` 返回 `HasWirelessPhase2Profile=false` 且无 `.xctrunner` 可复用 profile；`continue-native-wda-goal.ps1 ... -AutoResolveMobileProvisionPath -PreflightOnly -SkipRemoteHeadCheck` 停在 `No Phase 2-ready Apple Development profile found`，未进入远端 head 检查或安装。
- 下次动作：恢复 Phase 2 时，如果 `NativeSigningReady=False`、`RunnerSigningReady=False` 且扩大搜索也没有 ready profile，不要再把阻塞归因到 GitHub token、云构建、IPA 包结构或手机 App 状态；下一步只能是提供覆盖两个 bundle id 与目标 UDID 的 Apple Development profile，或继续保持 Phase 2 在诊断/文档层。

## 152. 新坑：签名阻塞的下一步不能只靠长句，应该有可交接的脱敏 profile 请求清单
- 坑点：触发条件、现象、影响范围：顶层 readiness 已经能输出 `NextRequiredAction` 和 `SigningReplacementRequirements`，但它们分散在 native/runner 子报告和长句里。恢复上下文或把需求交给外部 Mac/签名材料提供方时，容易漏掉 `.xctrunner` 的独立 bundle id、`get-task-allow=true`、显式 UDID 或安全边界。影响范围是 Phase 2 Signing gate 的人工交接和后续验证顺序，不涉及 p12 内容、证书密码、GitHub token、安装或真机操作。
- 根因：现有 `report-ios-signing-profiles.ps1` 是单 bundle 诊断；`check-phase2-readiness.ps1` 是总 gate。两者都不是“给签名材料提供方的一页 checklist”，导致操作者需要从多个字段和文案里手工提取签名要求。
- 处理：新增只读脚本 `Scripts\report-phase2-signing-unblock-plan.ps1`。它复用 native 与 runner 的 signing profile report，合并输出 `RequiredProfileRequests`，固定要求 `app.honey4212.crystal5671` 和 `app.honey4212.crystal5671.xctrunner` 都使用 Apple Development/development profile、显式 UDID `00008030-0001598021E2802E`、`get-task-allow=true`、未过期、覆盖 bundle 与 UDID；同时输出 `ExecutesSigning=false`、`ExecutesInstall=false`、`ExecutesDeviceAction=false`、`ReadsGitHubToken=false` 和不提交 p12/private key/password/token/profile 内容的安全边界。
- 验证：先新增 `test\phase2-signing-unblock-plan-tests.ps1`，运行失败在缺少 `Scripts\report-phase2-signing-unblock-plan.ps1`；实现脚本后同一测试通过。相邻 smoke 增加 `test\native-wda-host-smoke.mjs` 对脚本文本和 `docs/offline-automation-v1.md` 命令入口的断言。
- 下次动作：恢复 Phase 2 且 Signing gate 仍阻塞时，优先运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-signing-unblock-plan.ps1 -DeviceUdid '00008030-0001598021E2802E' -ProfileSearchRoot 'D:\2026_soft' -NoFail`，把输出中的 `Required profile requests` 作为获取/核对签名材料的唯一 checklist；不要从 readiness 长句里人工再拆。

## 153. 新坑：新增 signing unblock 脚本后，顶层 readiness 也要直接暴露命令入口
- 坑点：触发条件、现象、影响范围：`report-phase2-signing-unblock-plan.ps1` 已经提供脱敏签名 checklist，但 `check-phase2-readiness.ps1` 的 Signing gate 仍只输出 `SigningPathDecision`、`NextRequiredAction` 和 replacement 字段。长期恢复时操作者如果只看顶层 readiness，仍可能不知道应该先运行专用 unblock 脚本。影响范围是 Phase 2 Signing gate 的恢复入口，不涉及签名执行、安装、GitHub token 或真机操作。
- 根因：新增的 checklist 脚本没有被顶层 gate 聚合报告引用；测试只覆盖了独立脚本存在和文档入口，没有要求 `New-Phase2ReadinessReport` 与 `Write-Phase2ReadinessReport` 暴露同一命令。
- 处理：在 `check-phase2-readiness.ps1` 新增 `SigningUnblockPlanCommand` 字段。仅当 signing 未 ready 且 replacement requirements 收敛到唯一显式 UDID 时生成 `.\Scripts\report-phase2-signing-unblock-plan.ps1 -DeviceUdid '<UDID>' -NoFail`；人类可读输出在 `NextRequiredGate=Signing` 时打印 `Signing unblock plan command:`。不改变 gate 顺序、签名 ready 判定或任何设备动作。
- 验证：先在 `test\phase2-readiness-tests.ps1` 增加 RED 断言，确认缺少 `SigningUnblockPlanCommand` 会失败；实现后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`node test/native-wda-host-smoke.mjs`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-signing-unblock-plan-tests.ps1` 均通过。
- 下次动作：恢复 Phase 2 时先看顶层 readiness 的 `Signing unblock plan command:`；若该命令存在，先运行它获取 checklist，再判断是否需要新 Apple Development profile，不要先重试安装、runtime probe 或 GitHub/cloud。

## 154. 新坑：顶层 signing unblock 命令必须保留 profile 搜索范围，不能退回默认窄扫描
- 坑点：触发条件、现象、影响范围：Signing gate 已经建议用 `D:\2026_soft` 做扩大 profile 扫描，但顶层 `SigningUnblockPlanCommand` 最初只输出 `-DeviceUdid ... -NoFail`。如果用户把新的 `.mobileprovision` 放在默认目录之外，操作者照抄顶层命令会退回默认窄扫描，可能再次误判为缺 profile。影响范围是 Phase 2 Signing gate 的恢复命令入口，不涉及签名执行、安装、GitHub token 或真机操作。
- 根因：`New-Phase2ReadinessReport` 没有接收调用方的 `ProfileSearchRoot`，因此命令生成器无法知道本次 readiness 用了哪些 profile 搜索根；独立 unblock 脚本支持 `-ProfileSearchRoot`，但顶层聚合没有透传。
- 处理：`New-Phase2ReadinessReport` 新增 `ProfileSearchRoot` 参数；`New-SigningUnblockPlanCommand` 在生成命令时追加调用方传入的 `-ProfileSearchRoot '<path>'`。主脚本把已解析的 `$profileSearchRoots` 传入报告对象。该变更只影响诊断命令文本，不改变 gate 顺序、signing ready 判定或任何设备动作。
- 验证：先在 `test\phase2-readiness-tests.ps1` 增加 RED 断言并传入 `-ProfileSearchRoot @("D:\2026_soft")`，确认旧函数因缺少参数失败；实现后 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`node test/native-wda-host-smoke.mjs`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-signing-unblock-plan-tests.ps1` 均通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\check-phase2-readiness.ps1 -DeviceUdid '00008030-0001598021E2802E' -TargetRepo 'ds0515/0516_WDA' -ProfileSearchRoot 'D:\2026_soft' -RuntimeReportPath 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\live-reprobe-20260518-111306\phase2-runtime-report.json' -BonjourReportPath 'D:\2026_soft\0511_Appium_WDA\artifacts\phase2-runtime\live-bonjour-20260518-111329\bonjour-report.json' -NoFail` 输出 `Signing unblock plan command: .\Scripts\report-phase2-signing-unblock-plan.ps1 -DeviceUdid '00008030-0001598021E2802E' -ProfileSearchRoot 'D:\2026_soft' -NoFail`，且 `Next required gate: Signing`。
- 下次动作：恢复 Phase 2 时如果顶层 readiness 是用扩大搜索根运行的，直接复制 `Signing unblock plan command:`，不要手工删掉 `-ProfileSearchRoot`；这样可以避免新增 profile 已存在但不在默认目录时重复误判。

## 155. 新坑：continuation preflight 自动解析 profile 失败时也要给出同一 signing unblock checklist
- 坑点：触发条件、现象、影响范围：`continue-native-wda-goal.ps1 -AutoResolveMobileProvisionPath -PreflightOnly` 在找不到 Phase 2-ready Apple Development profile 时，只抛出 `No Phase 2-ready...` 和搜索根。长期恢复时如果操作者从 continuation 脚本入口进入，仍可能不知道下一步应该运行专用脱敏 checklist，而不是继续改 GitHub、云构建、IPA 或真机状态。影响范围是 Phase 2 Signing gate 的 preflight 入口，不涉及签名执行、安装、启动、GitHub token 输出或真机操作。
- 根因：#153/#154 补强的是顶层 readiness；`continue-native-wda-goal.ps1` 的自动 profile 解析错误路径没有复用同一 unblock command 语义。两个入口对同一个 Signing blocker 给出的下一步不一致。
- 处理：在 `continue-native-wda-goal.ps1` 新增 `New-Phase2SigningUnblockPlanCommand`，当自动解析找不到 ready profile 或搜索根下没有 profile 文件时，把 `.\Scripts\report-phase2-signing-unblock-plan.ps1 -DeviceUdid '<UDID>' -ProfileSearchRoot ... -NoFail` 附加到错误信息。该命令只打印 checklist，不签名、不安装、不启动、不读取 GitHub token。
- 验证：先在 `test\native-wda-goal-script-tests.ps1` 增加 RED 断言，要求 auto-resolve 失败消息包含 `report-phase2-signing-unblock-plan.ps1`、显式 UDID、`-ProfileSearchRoot 'D:\2026_soft'` 和 `-NoFail`；实现后 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\native-wda-goal-script-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-signing-unblock-plan-tests.ps1`、`node test/native-wda-host-smoke.mjs` 均通过。真实只读复现：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\continue-native-wda-goal.ps1 -Repo 'ds0515/0516_WDA' -Workflow 'wda-ios-unsigned-package.yml' -Ref 'lobster-wda-cloud-resign' -BuildPackageKind 'native_host' -RunnerLabelsJson 'macos-15' -TokenPath 'D:\2026_soft\0430_WS\0423_iPhone11\github.txt' -DeviceUdid '00008030-0001598021E2802E' -ProfileSearchRoot 'D:\2026_soft' -AutoResolveMobileProvisionPath -PreflightOnly -SkipRemoteHeadCheck -AllowDirtyCloudBuild` 按预期失败在 Signing gate，并输出 unblock checklist 命令。
- 下次动作：从 `continue-native-wda-goal.ps1` 入口恢复 Phase 2 时，如果 auto-resolve 报 `No Phase 2-ready Apple Development profile found`，直接运行错误中给出的 signing unblock checklist；不要先重试 GitHub/cloud、安装、launch 或 runtime probe。

## 156. 新坑：拿到新 profile 后不能只凭文件存在继续签名，unblock checklist 必须给出后置只读验证命令
- 坑点：触发条件、现象、影响范围：`report-phase2-signing-unblock-plan.ps1` 已经输出两份 required profile request，但此前只用自然语言说“重新运行 native 和 runner signing profile reports”。当用户或外部环境导入新 `.mobileprovision` 后，操作者仍可能直接进入签名/安装，或者只核验 native profile，漏掉 runner `.xctrunner`。影响范围是 Phase 2 Signing gate 的材料导入后验证顺序，不涉及签名执行、安装、启动、GitHub token 或真机操作。
- 根因：清单给出了“缺什么”，但没有给出“补齐后先跑哪几个只读命令证明已经补齐”。自然语言 next action 不足以防止长期恢复时跳过 runner profile 或跳过 `report-phase2-signing-unblock-plan.ps1` 复查。
- 处理：`report-phase2-signing-unblock-plan.ps1` 新增 `VerificationCommands`，在有显式 UDID 时输出三条只读命令：native `report-ios-signing-profiles.ps1`、runner `report-ios-signing-profiles.ps1`、以及再次运行 `report-phase2-signing-unblock-plan.ps1`。这些命令保留 `-DeviceUdid`、`-SearchRoot`/`-ProfileSearchRoot` 和 `-NoFail`，只做报告，不签名、不安装、不操作设备。
- 验证：先在 `test\phase2-signing-unblock-plan-tests.ps1` 增加 RED 断言，要求 blocked plan 包含 3 条 `VerificationCommands` 并在人类可读输出打印 `Verification commands:`；实现后 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-signing-unblock-plan-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`node test/native-wda-host-smoke.mjs` 均通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-signing-unblock-plan.ps1 -DeviceUdid '00008030-0001598021E2802E' -ProfileSearchRoot 'D:\2026_soft' -NoFail` 输出三条 verification commands，并仍显示 `Ready for Phase 2 signing materials: False`。
- 下次动作：用户提供或导入新 profile 后，先按 `Verification commands` 的顺序跑 native、runner、unblock plan 三个只读报告；只有两侧 signing 都 ready 且 unblock plan 显示 ready，才进入签名/安装/启动/runtime probe。

## 157. 新坑：Phase 2 signing unblock 不能只要求 profile，还必须要求匹配的 Apple Development 证书/私钥
- 坑点：触发条件、现象、影响范围：`report-phase2-signing-unblock-plan.ps1` 虽然显示 `Required certificate kind: Apple Development`，但此前没有结构化说明需要匹配的证书私钥、可接受 p12 容器、禁止输出密码和禁止把签名材料放入仓库。用户补齐 profile 后，仍可能缺少对应 Apple Development certificate/private key，导致后续签名才失败。影响范围是 Phase 2 Signing gate 的材料交接，不涉及读取 p12、读取密码、签名执行、安装或真机操作。
- 根因：profile 与 certificate/private key 是两类独立签名材料。现有 checklist 结构化了 profile 请求，但证书要求只是一行文本，没有出现在对象字段、human-readable checklist 和 next action 的同一层级。
- 处理：`report-phase2-signing-unblock-plan.ps1` 新增 `RequiredCertificateRequest`，字段包括 `CertificateKind=Apple Development`、`RequiresPrivateKey=True`、`AcceptsP12=True`、`AllowsPasswordOutput=False`、`AllowsRepositoryStorage=False`、`MustMatchProvisioningProfileTeam=True`。人类可读输出新增 `Required certificate request:`，next action 明确要求匹配 Apple Development certificate/private key，并提醒 p12 与证书密码留在仓库和日志之外。
- 验证：先在 `test\phase2-signing-unblock-plan-tests.ps1` 增加 RED 断言，要求 blocked plan 暴露证书请求字段并在输出中打印 `Required certificate request:`；实现后 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-signing-unblock-plan-tests.ps1`、`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1`、`node test/native-wda-host-smoke.mjs` 均通过。真实只读验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\report-phase2-signing-unblock-plan.ps1 -DeviceUdid '00008030-0001598021E2802E' -ProfileSearchRoot 'D:\2026_soft' -NoFail` 输出证书请求和安全边界，未读取 p12 或密码。
- 下次动作：用户补签名材料时，除了两份 Apple Development profile，还必须提供同 team 的 Apple Development certificate/private key 或可用 p12；不得把 p12、私钥、证书密码、profile 内容、token 或敏感日志写入仓库、终端记录或文档。

## 158. 新坑：后续手机侧 App 生命周期操作已授权自动关闭重开，但仍必须限定在显式 UDID/endpoint 下
- 坑点：触发条件、现象、影响范围：后续 Phase 2 真机验证如果需要让 iPhone 上的 WDA/native host 重新进入前台，继续等待用户手动关闭和重新打开 App 会拖慢恢复流程。用户已明确授权：下回需要在手机上操作时，可以自行关闭 App 并重启打开。影响范围仅限已明确目标设备或 WDA endpoint 的 App 生命周期操作，不扩大到自动选择设备、越过系统限制或进入 Phase 3。
- 根因：此前 iOS 18.7 Windows 环境中自动 launch 可能受 `DeveloperImage not found`、DVT/tunneld 或前台状态影响，流程容易在“请用户手动打开 App”处暂停；但用户现在已给出可自动关闭/重启 App 的操作授权。
- 处理：后续需要手机侧重启 App 时，先确认显式 UDID `00008030-0001598021E2802E` 或明确 WDA endpoint，再执行关闭 App、重新打开 App、健康检查的最小闭环；若遇到 DeveloperImage/DVT/tunneld 不可用、验证码、风控、异常登录、封禁或访问限制页面，立即停止并保存上下文。
- 验证：本条为操作边界记录，本次不执行真机命令。后续实际执行时，验证顺序应为设备可见性检查、关闭/启动 App 命令返回、`/status` 或 `probe-phase2-runtime.ps1 -SkipLaunch` 健康检查。
- 下次动作：Phase 2 恢复时如需手机侧 App 重启，不再默认要求用户手动打开；在显式 UDID/endpoint、屏幕解锁和授权范围内自动关闭并重新打开，然后继续只做 Phase 2 允许的 `/status`、截图/source 或 readiness 验证。

## 159. 新坑：顶层 readiness 不能只暴露 profile 要求，还要暴露匹配证书/私钥要求
- 坑点：触发条件、现象、影响范围：`report-phase2-signing-unblock-plan.ps1` 已经能输出 `RequiredCertificateRequest`，但 `check-phase2-readiness.ps1` 的顶层 Signing gate 此前主要打印两份 development profile 要求。长期恢复时如果操作者只看顶层 readiness，可能补齐 profile 后才发现缺同 team 的 Apple Development certificate/private key。影响范围是 Phase 2 Signing gate 的材料交接，不涉及读取 p12、读取密码、签名、安装、GitHub token 或真机操作。
- 根因：证书/私钥要求只存在于专用 unblock checklist，顶层 readiness 没有同级字段，也没有在人类可读输出和 `NextRequiredAction` 中明确同 team certificate/private key 是签名前置条件。
- 处理：`check-phase2-readiness.ps1` 新增 `SigningPathRequiredCertificateKind=Apple Development` 和 `SigningRequiredCertificateRequest`，字段包括 `RequiresPrivateKey=True`、`AcceptsP12=True`、`AllowsPasswordOutput=False`、`AllowsRepositoryStorage=False`、`MustMatchProvisioningProfileTeam=True`；`NextRequiredAction` 同时要求匹配 Apple Development certificate/private key。`docs/offline-automation-v1.md` 同步记录这些顶层字段和安全边界。
- 验证：先在 `test\phase2-readiness-tests.ps1` 增加 RED 断言，确认缺少证书/私钥要求时失败；实现后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。相邻验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-signing-unblock-plan-tests.ps1`、`node test/native-wda-host-smoke.mjs`、真实只读 `check-phase2-readiness.ps1 ... -ProfileSearchRoot 'D:\2026_soft' -NoFail` 均通过或按预期停在 Signing gate，并显示 certificate/private key 请求。
- 下次动作：恢复 Phase 2 时如果顶层 readiness 停在 Signing gate，不要只收集两份 `.mobileprovision`；同时确认同 team Apple Development certificate/private key 或可用 p12 已准备好，且 p12、私钥、证书密码、profile 内容和 token 不进入仓库、日志或终端输出。

## 160. 新坑：顶层 readiness 停在 Signing gate 时也要直接给出补材料后的只读复查命令
- 坑点：触发条件、现象、影响范围：`report-phase2-signing-unblock-plan.ps1` 已经输出三条 `VerificationCommands`，但 `check-phase2-readiness.ps1` 此前只暴露 unblock checklist 命令。长期恢复时如果操作者只看顶层 readiness，可能补齐 profile/证书后直接进入签名、安装或 runtime probe，漏掉 native profile、runner profile、unblock plan 三个只读复查步骤。影响范围是 Phase 2 Signing gate 的材料导入后验证顺序，不涉及签名、安装、启动、GitHub token、p12 读取或真机操作。
- 根因：顶层 readiness 与专用 signing unblock plan 的恢复语义不完全一致；顶层报告有“缺什么”和“去哪里看 checklist”，但没有直接给出“补齐后先跑哪些只读命令证明已经补齐”。
- 处理：`check-phase2-readiness.ps1` 新增 `SigningVerificationCommands`，在 Signing gate 下输出 native `report-ios-signing-profiles.ps1`、runner `report-ios-signing-profiles.ps1`、`report-phase2-signing-unblock-plan.ps1` 三条只读命令；命令保留显式 UDID、`-SearchRoot`/`-ProfileSearchRoot` 和 `-NoFail`。`docs/offline-automation-v1.md` 同步记录该字段和人类可读 `Signing verification commands:` 输出。
- 验证：先在 `test\phase2-readiness-tests.ps1` 增加 RED 断言，确认顶层报告缺少三条 verification commands 时失败；实现后 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-readiness-tests.ps1` 通过。相邻验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\test\phase2-signing-unblock-plan-tests.ps1`、`node test/native-wda-host-smoke.mjs`、`git diff --check -- ...` 通过；真实只读 `check-phase2-readiness.ps1 ... -ProfileSearchRoot 'D:\2026_soft' -NoFail` 按预期停在 Signing gate 并打印三条 verification commands。
- 下次动作：补齐签名材料后，优先照顶层 readiness 的 `Signing verification commands:` 顺序运行三条只读命令；只有 native 和 runner signing 报告均 ready，且 unblock plan 显示 ready，才进入签名、安装、启动或 runtime probe。

## 161. 新坑：不续费 Apple Developer Program 时，低成本路线只能作为临时开发签名实验，不能等同 Phase 2 完成
- 坑点：触发条件、现象、影响范围：用户明确不准备续费 Apple Developer 账号，希望用低成本方式推进 Phase 2。如果继续把“付费开发者后台创建 profile”当成唯一入口，会卡住；但如果改走共享证书、企业证书租赁、越狱或签名/授权绕过，又会违反项目安全边界且不能证明 WDA UI automation。影响范围是 Phase 2 Signing gate 的替代路径选择，不涉及读取 Apple 账号密码、p12、GitHub token、签名执行、安装或真机操作。
- 根因：当前账号无法访问 Certificates, Identifiers & Profiles；官方 Xcode Personal Team 可以做个人用途的设备测试，但 profile 有短期有效期，且仍需要 Mac/Xcode 生成 development-signed artifacts。该路径可降低成本，但不改变 Phase 2 对 development profile、同 team certificate/private key、显式 UDID、`get-task-allow=true` 和 WDA runtime 验证的要求。
- 处理：`docs/offline-automation-v1.md` 新增 `No-renewal low-cost path`：优先评估借用或租用 Mac + Xcode Personal Team 作为临时开发签名来源；Personal Team 结果必须继续通过顶层 `Signing verification commands:`、安装、`/status`、UI route 和 no-USB endpoint 检查；明确禁止共享开发者证书、租赁企业证书、越狱、第三方保管账号密码的 sideloading tricks 或任何 signing/entitlement/XCTest authorization bypass。
- 验证：`node test/native-wda-host-smoke.mjs` 新增断言并通过，覆盖 `No-renewal low-cost path`、`Xcode Personal Team`、`expire after 7 days`、`borrowed or rented Mac`、`shared developer certificates`、`not Phase 2 completion evidence` 等边界。
- 下次动作：如果继续不续费，下一步不是重试现有 distribution profile，也不是继续 GitHub 云构建；应准备一个可临时使用的 Mac/Xcode 环境，用 Personal Team 对两个 bundle id 做 development signing 实验，并在导出材料后先跑顶层 `Signing verification commands:`。

## 162. 新坑：GitHub 云端构建只验证 unsigned IPA 时，不应被本地签名 profile gate 阻断
- 坑点：触发条件、现象、影响范围：执行 `continue-native-wda-goal.ps1 -ValidateIpaOnly -PreflightOnly` 只想验证 GitHub workflow/source/runner，但脚本仍读取默认 `cert.mobileprovision` 并因 `profile kind is distribution` 失败，导致 workflow 未 dispatch。影响范围是纯云端 unsigned IPA 构建入口，不涉及签名、安装、启动、无线 probe 或真机 UI automation。
- 根因：`Invoke-PreflightOnlyValidation` 把 cloud source preflight 和 signing preflight 固定串在一起；主流程虽然在 `-ValidateIpaOnly` 时跳过最终签名，但 preflight-only 分支没有同步跳过 signing preflight。
- 处理：给 `Invoke-PreflightOnlyValidation` 增加 `-SkipSigningPreflight`，主流程仅在 `-ValidateIpaOnly` 时传入该开关；签名、安装、无线验收路径仍保留 Development profile 检查。
- 验证：先运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\test\native-wda-goal-script-tests.ps1` 得到 RED：缺少 `SkipSigningPreflight` 参数；实现后同一测试通过。真实预检命令 `continue-native-wda-goal.ps1 ... -ValidateIpaOnly -PreflightOnly -SkipRemoteHeadCheck -AllowDirtyCloudBuild` 输出 `Skipping signing preflight for validate-only cloud build.` 并通过。
- 下次动作：凡是目标只是获取/验证 GitHub unsigned IPA，优先使用 `-ValidateIpaOnly`，不得要求 Apple Development profile；只有进入签名、安装、`/status`、UI route 或 wireless validation 时才回到 Signing gate。

## 163. 新坑：GitHub API 发布生成远端 commit 后，cloud gate 仍可能把本地 HEAD mismatch 当阻塞
- 坑点：触发条件、现象、影响范围：用 `publish-phase2-github-api-source.ps1 -Execute` 写入 `ds0515/0516_WDA@lobster-wda-cloud-resign` 后，远端 head 变为 API 生成的 commit `facdd4f2...`；随后 `report-phase2-cloud-dispatch-plan.ps1` 仍提示 remote head mismatch，因为本地 git HEAD 仍是 `8b5f2819...` 且工作区未提交。影响范围是“远端分支已按候选路径发布，但本地不 commit/push”的云构建调度判断。
- 根因：cloud publish plan 默认以本地 git HEAD 作为预期远端 commit；GitHub API 发布走的是独立 commit/tree 写入，不会改变本地 git HEAD，也不会创建匹配的本地 remote。
- 处理：在用户已明确允许远端写入且确认构建当前远端分支时，使用 `continue-native-wda-goal.ps1` 的 `-SkipRemoteHeadCheck -AllowDirtyCloudBuild` 显式接受当前远端分支作为构建输入；执行前仍要跑 publish candidate 和 repo safety，确认不会发布 secrets、artifacts、logs 或诊断数据。
- 验证：`report-phase2-cloud-publish-candidate.ps1` 显示候选 432 个路径并排除 p12、mobileprovision、password、token、logs、artifacts；`check-repo-safety.ps1 -NoFail` 显示 forbidden tracked/pending 为 0；API 发布成功生成远端 commit `facdd4f2c4424517e40d1efca82663129e4f0392`。
- 下次动作：如果继续使用 GitHub API 发布而非本地 commit/push，cloud gate 的 head mismatch 不应直接等同 token 或仓库权限问题；先确认远端源码状态 ready，再用 `-SkipRemoteHeadCheck -AllowDirtyCloudBuild` 只针对 validate-only cloud build 显式放行。

## 164. 新坑：GitHub-hosted macOS 能完成 unsigned native host 构建，但不能替代 Phase 2 签名和 WDA UI 授权
- 坑点：触发条件、现象、影响范围：在没有 Mac、也不续费 Apple Developer Program 的条件下，使用 GitHub-hosted `macos-15` runner dispatch `.github/workflows/wda-ios-unsigned-package.yml`。workflow 可以成功生成并下载 unsigned native host IPA，但该结果只覆盖云端编译，不覆盖 iOS 安装签名、XCTest/WDA UI 授权、Wi-Fi endpoint 或真机 `/screenshot`/`/source`。
- 根因：GitHub-hosted runner 提供 Xcode 编译环境，可以产出 unsigned app/IPA；真机安装和 WDA UI automation 仍由 Apple Development profile、同 team certificate/private key、UDID、entitlements 和设备运行时授权决定。
- 处理：将 GitHub 云端路径限定为 `-ValidateIpaOnly`：dispatch 后下载 artifact，验证 `Payload/LobsterWDAHost.app`、`WebDriverAgentLib.framework`、`/wda/network`、proxy routes、Local Network plist 和 bundle id；验证通过后仍停在 Signing gate，不进入 Phase 3。
- 验证：`continue-native-wda-goal.ps1 -Repo 'ds0515/0516_WDA' -Workflow 'wda-ios-unsigned-package.yml' -Ref 'lobster-wda-cloud-resign' -BuildPackageKind 'native_host' -RunnerLabelsJson 'macos-15' -ValidateIpaOnly -SkipRemoteHeadCheck -AllowDirtyCloudBuild` dispatch run `26018145454`，下载 `D:\2026_soft\0511_Appium_WDA\artifacts\lobster-wda-host\LobsterWDAHost-unsigned-ipa-26018145454\LobsterWDAHost.unsigned.ipa`，并输出 `Native host IPA verified: CFBundleIdentifier=app.honey4212.crystal5671`。
- 下次动作：GitHub 云端成功后，下一步不是 Phase 3；只能继续解决 Development signing material 或明确接受 distribution-signed runtime 的已知局限作为实验，不得把 unsigned IPA 成功当作 WDA 控制链路完成。

## 165. 新坑：迁移到新 Mac 时，不能把 p12 或 mobileprovision 当作 GitHub 仓库文件上传
- 坑点：触发条件、现象、影响范围：为了让新 Mac 的 Codex app 更方便继续执行，用户提出把证书和描述文件也上传到 GitHub。`cert.p12` 是私钥容器，`.mobileprovision` 包含签名、team、设备和 profile 元数据；如果作为普通仓库文件、release asset、issue/comment、wiki、gist 或 Actions artifact 上传，会扩大签名材料暴露面。影响范围是迁移交接和后续签名材料读取，不涉及 unsigned IPA 云端编译。
- 根因：GitHub 仓库即使是私有仓库，也不是签名私钥和描述文件的安全交接通道；一旦进入 git blob 或附件，后续删除也可能残留在历史、缓存、fork、下载副本或日志中。
- 处理：拒绝把 p12、mobileprovision、密码或 `github.txt` 上传为仓库文件。迁移方式改为用户手动把材料放到新 Mac 仓库外的私有目录，例如 `~/secure-wda-materials/`；Codex 只在明确需要签名或只读检查时引用路径。如果后续明确要“云端签名”，必须先单独做安全方案评审，只能讨论 GitHub Actions Encrypted Secrets 这类受控入口，不得把材料提交进仓库。
- 验证：`docs/new-mac-codex-start-prompt-2026-05-25.md` 已加入“签名材料迁移规则”，明确禁止通过 GitHub 仓库、release asset、issue/comment、wiki、gist 或 Actions artifact 存放 p12、mobileprovision、密码和 token。
- 下次动作：新 Mac 恢复时若缺材料，先要求用户在本机私有目录放置文件并提供路径；不要要求上传到 GitHub 仓库，也不要读取或输出文件内容。
