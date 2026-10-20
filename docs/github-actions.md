# GitHub Actions：macOS 自动构建、签名和公证

工作流：`.github/workflows/macos.yml`。目标为 GitHub 分发的 macOS App，使用 Developer ID Application 签名和 Apple 公证。CI 不会创建 GitHub Release、修改 `appcast.xml`、上传 App Store Connect 或提交商店审核。

## 触发与产物

- 针对 `main` 的 Pull Request：编译 arm64 / x86_64 通用 Release App，不读取 Apple Secrets。
- 推送 `main`、推送 `v*` 标签或 Actions 页面手动运行：归档、自动签名导出、公证、装订票据、Gatekeeper 校验，生成 ZIP。
- `Wannianli-macOS-*` Artifact：已装订票据的 ZIP、`SHA256SUMS`、`build-info.json`，保留 14 天。
- `macOS-diagnostics-*` Artifact：构建、公证结果及 Apple 公证日志，保留 7 天；签名私钥、临时钥匙串和 API Key 均不在上传范围。

从 Actions 下载 Artifact 后，先解压 GitHub 的外层归档，再解压其中的 `Wannianli-版本-构建号.zip` 得到 App。可在同目录执行 `shasum -a 256 -c SHA256SUMS` 校验安装包。

## 签名与凭据

以下仓库 Secrets 已配置于 `RaulVan/Wannianli`，值来自本地 `applekey/` 和与该 API Key 同团队的现有有效 Developer ID 签名身份。任何私钥、密码和证书包都不得提交 Git：

| Secret | 用途 |
| --- | --- |
| `APPLE_DEVELOPER_ID_P12_BASE64` | 带私钥的 Developer ID Application P12，Base64 编码 |
| `APPLE_DEVELOPER_ID_PASSWORD` | P12 导出密码 |
| `APPLE_TEAM_ID` | 签名团队 |
| `ASC_KEY_ID` | Apple API Key ID |
| `ASC_ISSUER_ID` | Apple API Issuer ID |
| `ASC_PRIVATE_KEY` | `.p8` 文件的完整 PEM 内容 |

本地恢复副本保留在被忽略的 `applekey/developer-id-ci.p12`，密码位于同目录 `ci-p12-password.txt`，两者权限均为 `0600`。

已补齐本地签名资源：`applekey/developer-id-application.cer`、主 App 的 `Wannianli-DeveloperID.provisionprofile`、Widget 的 `WannianliWidget-DeveloperID.provisionprofile`。两个 Bundle ID 已在同团队注册，描述文件类型均为 `MAC_APP_DIRECT`、状态 `ACTIVE`。独立证书与 P12 完全匹配；描述文件的 Bundle ID、Team ID、证书关联、有效期、CMS 内容签名与 Apple 根证书信任链均已核验。本地 `applekey/README.md` 和 `signing-resources.json` 记录交付清单和校验结果；证书及描述文件没有提交 Git。CI 继续通过 Xcode Automatic signing 按需获取描述文件。

`script/ci/signing.sh` 把 P12 导入短期钥匙串，允许 codesign 非交互访问；API Key 以权限受限文件写入 runner 临时目录。`always()` 清理步骤恢复钥匙串搜索列表并删除临时凭据。Runner 中断或强制终止仍由 GitHub 托管 runner 的销毁机制清理。

`script/ci/build-notarized.sh` 使用 XcodeGen 生成工程，先归档，再通过 `signingStyle=automatic` / `method=developer-id` 导出。Xcode 负责主 App、Widget 和 Sparkle 内嵌组件的发行签名，避免只签外层 framework。当前 App 与 Widget 权限不需要额外的 Developer ID provisioning profile；若以后加入依赖描述文件的受限能力，导出允许 Xcode 使用 API Key 自动管理。

API 认证和证书清单通过 `asc-cli` 核实。注意 `asc` v0.1.61 会优先读取本机已保存账号，再回退环境变量；本地操作前必须核实所选账号。在全新 CI runner 上需要使用 `asc` 时，可通过上述 `ASC_*` Secrets 设置环境变量，或明确执行 `asc auth login`。

## 验收和失败处理

签名导出后检查 WidgetKit 扩展、主 App / Widget 双架构、Developer ID 身份、Team ID、Hardened Runtime 和不存在 `get-task-allow`。公证必须返回 `Accepted`，随后执行 `stapler staple`、`stapler validate`、深度签名校验和 `spctl`。失败时不上传成功安装包，诊断日志仍会保留。

Apple 公证等待上限为 30 分钟。超时后 Apple 可能继续处理，可从诊断文件读取提交 ID，再执行 `xcrun notarytool info` / `log` 查询。证书过期、撤销或私钥变更后，更新 P12 和密码两个 Secrets；不在每次构建时新建证书。

版本与构建号沿用 `project.yml`。需要发布新版本时，先按项目约定递增版本。本流程只生成 Artifact；公开 Release 和 Sparkle Appcast 的发布另行执行。现有 `script/release.sh` 是原本的本机 Sparkle 打包流程，不具备此 CI 公证流程。

参考：[Apple Developer ID](https://developer.apple.com/developer-id/)、[Apple 自定义公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)、[Sparkle 内嵌组件签名](https://sparkle-project.org/documentation/sandboxing/#code-signing)。

## 2026-10-20 本地验收结果

- `actionlint`、Bash 语法和 diff 空白检查通过。
- arm64 / x86_64 归档、Developer ID 自动签名导出通过；主 App、Widget 和 Sparkle 内嵌组件通过深度签名校验。主 App / Widget 均启用 Hardened Runtime，且无调试权限。
- 临时钥匙串导入、非交互签名访问、清理和恢复原钥匙串搜索列表通过；缺少 Secrets 时在导入前失败。6 项仓库 Secrets 已确认存在。
- 实际提交 Apple 公证，提交 ID：`576aee17-b4a3-4087-90c5-a18b467be105`。Apple 返回 `Rejected`、`statusCode: 7000`、`issues: null`，团队尚未配置公证。完整日志保存在本地 `build/ci-validation/logs/notarization-log.json`。
- 票据装订、Gatekeeper 接受及成功安装包尚未验证；流程在 Apple 拒绝处停止。远端 Actions 运行尚未验证，工作流未推送。

7000 的处理路径是 [Apple Developer Program Support](https://developer.apple.com/contact/)，这是团队账号配置问题；Apple DTS 在[官方说明](https://developer.apple.com/forums/thread/118465)中明确要求通过此渠道处理。联系时提供 Team ID、上述公证提交 ID 和完整日志。团队服务恢复后，在 GitHub Actions 页面重新运行工作流即可继续公证验收。
