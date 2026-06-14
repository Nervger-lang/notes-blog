---
date: 2026-06-14
---

# CDP 工作原理

> Chrome DevTools Protocol — 不看图，直接读代码

---

## 演进史：从物理截图到 CDP 直连（为什么最终选了 CDP）

> 2026-06-14 记录 | 三次技术选型，每次都是血的教训

### 第一代：物理截图 + OCR + xdotool（已废弃）

**怎么做**：截图桌面 → Tesseract OCR 识字 → 算坐标 → xdotool 点击

```
截图 → OCR 识别「发布」→ 算出像素位置 (960, 1580) → DISPLAY=:0 xdotool click
```

**为什么放弃**：
- 🐌 **慢**：每步都要截图→OCR→算坐标，三大模型都要参与
- 🎯 **不准**：OCR 经常识别错字、漏字、把图标当文字
- 📐 **依赖模板**：需要王哥哥给模板图片做 OpenCV 匹配
- 😵 **复杂**：Wayland/X11 桌面环境差异，截图方式反复换（GNOME screenshot portal → import → scrot）

### 第二代：MCP（Chrome DevTools MCP）（已废弃）

**怎么做**：通过 `npx chrome-devtools-mcp@latest` 启动 MCP 服务器，Hermes 通过 MCP 协议操控 Chrome

```
Hermes → MCP Server (npx) → CDP → Chrome
```

**为什么放弃**：
- 🔌 **连接不稳**：MCP 服务器频繁掉线，WebSocket 断开
- 🧟 **进程泄漏**：`chrome-devtools-mcp` 进程经常变成僵尸
- 🐢 **多一层开销**：Hermes → MCP → CDP，中间多一个翻译层
- 🛠️ **排错困难**：出问题时不知道是 MCP 的问题还是 Chrome 的问题

### 第三代：CDP 直连 WebSocket（✅ 当前方案）

**怎么做**：Python 直接通过 WebSocket 连 Chrome 的 9222 端口，发 CDP 命令

```
Hermes → WebSocket → Chrome:9222
```

**为什么最终选它**：
- ⚡ **快**：直连，无中间层
- 🎯 **准**：DOM 级精确操作，不发图片不给大模型
- 🔧 **可控**：出问题直接看 CDP 返回，不猜
- 💾 **轻量**：只需要 Python `websocket-client` 一个包
- 🧩 **灵活**：`Runtime.evaluate` 可以跑任意 JS

---

## 对比：三代方案

| | 一代：截图+OCR | 二代：MCP | 三代：CDP 直连 |
|---|---|---|---|
| 速度 | 🐌🐌🐌 | 🐌🐌 | ⚡ |
| 准确度 | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 稳定性 | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| 依赖 | Tesseract + OpenCV | npx + Node | websocket-client |
| 中文识别 | 靠 OCR（不准） | 读 DOM（准） | 读 DOM（准） |
| Vue 组件 | ✅ xdotool 能点 | ⚠️ 不稳定 | ✅ Symbol(_vei) |
| 截图验证 | 天然支持 | 支持 | 支持（captureScreenshot） |
| VNC 联动 | 不需要 | 不需要 | ✅ 同一台 Chrome 可见+可控 |

---

## CDP 怎么「看」页面？

**不看图，直接读代码。** Chrome 内置了一套开发者工具协议 (CDP)，你按 F12 打开的开发者工具就是在用这套协议。CDP 通过 WebSocket 直接跟浏览器内核对话：

```
Hermes → WebSocket → Chrome 内核 → 返回数据
```

---

## 核心原理

```
❌ 视觉方案:   截图 → OCR 识字 → 猜位置 → 点
✅ CDP:        读 HTML 代码 → 精确找元素 → 执行 JS 操作
```

比如找「发布」按钮：
```javascript
// CDP 直接在浏览器里跑 JS，返回结果给 Hermes
document.querySelector('xhs-publish-btn')
// → 返回：找到了，这个元素的坐标是 (x=960, y=1580)
```

**全程没有图片、没有大模型。**

---

## 常用 CDP 操作

| 操作 | 实际干了什么 | 需要图片？ |
|------|------------|-----------|
| `Page.navigate` | 告诉 Chrome 打开网址 | ❌ |
| `Runtime.evaluate` | 在页面执行 JS，返回文字结果 | ❌ |
| `Input.dispatchMouseEvent` | 在坐标 (x,y) 模拟鼠标点击 | ❌ |
| `Page.captureScreenshot` | **截图** | ✅ 仅为你确认时用 |

唯一涉及图片的是 `captureScreenshot`——但那只是为了截图**发给你看**，让你确认操作到了哪一步。CDP 自己操作不需要看图。

---

## 一句话总结

**CDP 像黑客直接扒代码，视觉方案像人眼看屏幕。CDP 更快更准。**

唯一的死穴：Vue 3 自定义组件（如 `<xhs-publish-btn>`）的事件 handler 不在 DOM 上，需要 `Symbol(_vei)` 特殊技巧——见《小红书自动化踩坑记录》坑2。

---

## 为什么不选其他方案

| 方案 | 为什么没选 |
|------|-----------|
| Selenium / WebDriver | 太重，需要额外 driver，国内网络装不上 |
| Playwright | Ubuntu 26.04 不被官方支持 |
| Puppeteer | 需要 Node 环境，多一层依赖 |
| 纯视觉（截图+OCR） | 太慢太不准，已废弃 |
| MCP | 不稳定，已废弃 |
