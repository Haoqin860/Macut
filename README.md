<p align="center"><img src="docs/assets/app-icon.png" width="80" height="80" alt="Macut icon"></p>
<h1 align="center">Macut</h1>
<p align="center">随手复制，随时找回。<br>A quiet, native clipboard history app for your Mac.</p>
<p align="center"><a href="https://haoqin860.github.io/Macut/">产品首页</a> · <a href="https://github.com/Haoqin860/Macut/releases/latest">下载最新版</a> · <a href="docs/guide.md">使用说明</a> · <a href="PRIVACY.md">隐私说明</a></p>

![Macut 品牌插画](docs/assets/hero-art.jpg)

*品牌插画由 GPT 生成。产品首页的交互演示仅含虚构内容，不包含真实剪贴板记录或桌面截图。*

Macut 常驻菜单栏，按 **⌘⇧V** 呼出，直接输入就能搜索文字、图片和链接。选中内容后继续原来的工作。SwiftUI + AppKit 构建，内容仅保存在本机。

## 安装

1. 从 [GitHub Releases](https://github.com/Haoqin860/Macut/releases/latest) 下载 DMG。
2. 核对 Release 附带的 SHA256SUMS.txt，打开 DMG，将 Macut 拖入「应用程序」。
3. 启动后按 **⌘⇧V**，或点击菜单栏的叠纸图标。

当前提供 **macOS 14+ / Apple Silicon** 版本。早期公开版本采用 ad-hoc 本机签名，尚未进行 Developer ID 签名和 Apple 公证。如果系统阻止打开，请先确认下载来源及校验和，再按系统设置中的提示处理；不要关闭 Gatekeeper 等系统安全保护。

自动粘贴需要你在「系统设置 → 隐私与安全性 → 辅助功能」中允许 Macut。未授权时，回车复制后，回到原应用按 **⌘V** 即可。登录启动默认关闭，可在设置中选择开启。

## 功能

- **混合历史**：文字、富文本、图片、链接和文件引用。
- **图片预览**：图片数据与单个本地图片文件都能显示缩略图、大预览及尺寸；支持没有扩展名的图片缓存文件。
- **即输即搜**：按正文或来源应用搜索，切换文字、图片和收藏分类。
- **键盘操作**：自定义全局呼出快捷键，方向键选择，数字键快速使用。
- **收藏与整理**：保护常用内容，普通历史按时间、条数和容量清理。
- **本地保存**：无账号、云同步、遥测、远程 AI 请求或第三方运行时依赖。

## 常用快捷键

| 操作 | 快捷键 |
| --- | --- |
| 呼出 / 收起 | ⌘⇧V，可自定义 |
| 选择记录 | ↑ / ↓ |
| 使用选中内容 | ↩ |
| 以纯文本使用文字 | ⌘↩ |
| 使用前九条结果 | ⌘1–9 |
| 收藏 / 取消收藏 | ⌘P |
| 删除选中记录 | ⌘⌫ |
| 切换分类 | Tab / ⇧Tab |
| 放大图片 / 返回 | 空搜索时按空格 / Esc |
| 展开 / 收起预览 | ⌘\ |
| 设置 | ⌘, |

菜单栏 **⌥ 点击**可暂停记录，右键可打开设置或退出。

## 隐私与使用边界

历史保存在当前用户的 Application Support 目录中。Macut 不做应用层加密。自动跳过已知敏感剪贴板标记，并支持排除应用；**未标记的密码、令牌等敏感内容仍可能被记录**。

文件条目保留原始文件引用。单个图片文件额外生成预览缩略图；原文件移动或删除后，缓存缩略图可以保留，但原文件引用粘贴可能失效。多个文件作为文件组保留。来源应用由捕获时的前台应用推断，可能不准确。

微信等应用的图片缓存可能受系统保护。没有预览时，可以在记录详情中选择对应原图片来按需授权；不需要授予全盘访问。原文件已失效或授权不足时，仍可能只能保留文件引用。

完整细节见 [PRIVACY.md](PRIVACY.md) 和 [使用说明](docs/guide.md)。请勿在公开 Issue 中附上个人剪贴板数据库、密码、令牌或未经检查的系统日志。

## 从源码构建

需要 macOS 14+ 与 Swift 5.9+ 工具链；完整 Xcode 或兼容的 Command Line Tools 均可。

```sh
git clone https://github.com/Haoqin860/Macut.git
cd Macut
./Scripts/build-app.sh
./Scripts/run-checks.sh
./Scripts/package-dmg.sh
./Scripts/verify-release.sh
```

应用输出到 build/Macut.app，DMG 输出到 build/。检查程序不依赖 XCTest。--demo 启动参数使用独立临时历史，并关闭剪贴板采集。

## 项目结构

```text
Sources/ClipboardCore/  历史、载荷、缩略图与清理
Sources/Macut/          原生面板、快捷键与设置
Tests/CoreChecks/      存储与图片回归检查
Scripts/               构建、检查、隐私审计与打包
docs/                  GitHub Pages 首页与使用说明
```

源码、素材和发布包检查规则见 [公开发布检查](docs/release-checks.md)。设计素材与参考项目见 [开发记录](docs/development.md)。

## 许可证

[MIT](LICENSE) · © 2026 Macut contributors
