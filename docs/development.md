# 开发与设计记录

## 方向

采用原生悬浮搜索面板。840 × 566 点的展开布局，左侧混合历史、右侧预览；收起预览后为 445 点宽。遵循系统深浅色和原生材质，使用克制的青绿色选中态。

原始讨论用概念图为 `concept.png`，实际界面由 SwiftUI 实现。概念图不代表运行截图。

## 工程参考

2026-10-15 核对了以下 GitHub 项目的 README 与许可证，并阅读 Maccy、SmartClipboard 的部分源码：

- Maccy：https://github.com/p0deje/Maccy ，MIT。参考了浮窗、文字 / 图片预览和系统剪贴板边界处理思路。调研快照 `22bd46624d5a474615561daee38ade130390ecde`。
- SmartClipboard：https://github.com/saihgupr/SmartClipboard ，MIT。参考 Spotlight 式入口和快捷键流程。调研快照 `855a662cdad901f4ed2ad03001f4ce5af81fe8b1`。
- Clipy：https://github.com/Clipy/Clipy ，MIT。参考常用片段和历史访问方式。
- Copyo：https://github.com/VibeMage/copyo ，GPL-3.0。参考类型筛选和图片卡片呈现。
- PasteBar：https://github.com/PasteBar/PasteBarApp ，仓库注明限制商业使用的 CC 许可及例外。仅调研，未引入。

当前代码独立实现，没有直接拷贝上述项目源码，也未引入其图片、品牌资产或依赖。

## 图像素材

`Resources/AppIcon.png` 使用内置 GPT 图像生成工具创建，并由构建脚本转换为 `.icns`。仅做尺寸转换用于图标打包。

生成提示词原文：

> Use case: logo-brand. Asset type: production macOS application icon master, app named Macut, clipboard history utility. Generate a single immaculate macOS app icon, square 1024x1024 composition. Front-on centered dimensional icon: two gently overlapping rounded paper sheets, front paper soft porcelain white with three short subtle embossed horizontal lines, back sheet refined muted sea-teal. The sheets form a simple clear memorable silhouette, floating a tiny distance above a rich but quiet desaturated pale-teal background. Professional native macOS icon craft, soft studio lighting top left, precise rounded corners on paper, fine edge highlights, restrained realistic material and subtle ambient contact shadow, beautiful at tiny sizes. Background fills the entire square edge to edge: do NOT bake any outer app-icon rounded-square mask, black corners, or external transparent margins; operating system will apply the mask. Central paper symbol occupies about 65 percent of frame. No lettering, no word Macut, no watermark, no extra objects, no scissors, no badges, no glass bubbles, no complex gradients. Calm elegant utilitarian personality.

## 验证边界

## 首页品牌插画

官网使用 `assets/hero-art.jpg`，原稿 `assets/hero-art.png` 由内置 GPT 图像生成工具创建。导航图标仅做尺寸优化。所有演示文字均为虚构内容，未使用真实用户截图。

生成提示词原文：

> Use case: ads-marketing. Asset type: original editorial hero artwork for Macut, an elegant native macOS clipboard history application. Generate one exquisite wide landscape still life, approximately 3:2 ratio, suitable as a product homepage hero image and as a fictional image in an interface demonstration. Scene: an architectural miniature landscape built entirely from folded ivory paper and muted sea-teal cardstock. Three gently curved sheets rise like soft sculptural ribbons from a low off-white paper plinth, with a few neatly layered rectangular paper cards behind them suggesting an orderly collection of saved ideas. Sophisticated physical paper craft, tactile fibers, carefully rounded folds and subtle edge highlights. Restrained palette: warm chalk, pale sage, deep desaturated teal, soft gray. Quiet editorial product photography, diffuse daylight from upper left, realistic soft shadows, ample breathing room, delicate asymmetry. Studio backdrop seamless pale warm gray. Composition visually simple and premium at thumbnail sizes, main sculpture centered with surrounding negative space. No computer screens, no application UI, no text, no glyphs, no logos, no usernames, no watermarks, no real documents, no people or personal information. This is abstract brand imagery, not a screenshot. Meticulous materials and refined lighting, not cartoon, not neon, not shiny plastic.


已完成的检查以 `verification.md` 为准。自动粘贴的完整跨应用端到端验证，依赖用户自行授权辅助功能；未授权的复制回退路径可独立验证。
