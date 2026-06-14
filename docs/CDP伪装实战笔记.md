# 🔍 CDP 伪装实战：从 9222 到 19922 的旅程

> 创建于 2026-06-14 | 标签：CDP、反爬、风控、自动化

---

## 起因

Chrome DevTools Protocol (CDP) 是浏览器自动化的利器，但网站也在进化。小红书的发布页会「静默吃掉」发布按钮——不报错、不弹验证码，就是按钮从 DOM 里消失了。这不是 bug，是风控。

## CDP 暴露了什么

当你启动 `--remote-debugging-port=9222` 时，Chrome 暴露了两个「自动化特征」：

| 特征 | 检测方式 | 影响 |
|------|---------|------|
| 端口 9222 | 页面 JS 检查 `window` 对象或 WebSocket | 所有自动化工具（Selenium/Puppeteer）共用 |
| `navigator.webdriver = true` | 标准的「我是机器人」标志 | 几乎所有反爬系统第一关 |

这两个特征是「低垂的果实」——任何有点反爬意识的网站都会查。

## 伪装第一层：端口 + webdriver

```bash
google-chrome-stable \
  --remote-debugging-port=19922 \                    # 不用 9222
  --disable-blink-features=AutomationControlled      # webdriver → false
```

效果：`navigator.webdriver` → `false` ✅，9222 端口无监听 ✅

这能骗过 **80% 的自动化检测**——GitHub、普通 CMS、大部分登录页面。

## 第二层：应用级检测

但小红书的创作者平台（`creator.xiaohongshu.com`）不止于此。它的风控分两层：

| 层级 | 检测目标 | 触发位置 | 我们的应对 |
|------|---------|---------|-----------|
| **第一层** | `navigator.webdriver` + 标准端口 | 首页、编辑器、草稿箱 | ✅ 19922 + AutomationControlled |
| **第二层** | **CDP WebSocket 协议连接** | 发布页 | ❌ 按钮从 DOM 消失 |

第二层检测的不是端口号——是**CDP 协议本身的 WebSocket 连接**。即使换成 19922、19923、99999，只要 DevTools 连着，发布按钮就不会出现在 DOM 中。

### 第二层检测的具体表现

1. **编辑器正常**：填标题、写正文、一键排版——全部 OK
2. **发布页异常**：所有设置都正常渲染，唯独 `<xhs-publish-btn>` 组件**拒绝挂在 DOM 里**
3. **静默失败**：不报错、不弹验证码，只是「发布」按钮不存在于 DOM 中
4. **不是被删除**：MutationObserver 监控显示按钮从未被创建。Vue 组件初始化时检测到 CDP，`mounted()` 直接跳过渲染

## 尝试过的失败方案

| 方案 | 原理 | 结果 |
|------|------|------|
| `addScriptToEvaluateOnNewDocument` 注入 | 页面加载前拦截检测 | ❌ 按钮从未创建，无法拦截 |
| 手动构造 `<xhs-publish-btn>` | DOM 注入 | ❌ 没有 Vue 绑定，空壳按钮 |
| Vue 组件树遍历找 publish 方法 | 直接调 Vue handler | ❌ 方法不在 setupState 中 |
| `xdotool` 网格盲扫 36 位置 | VNC 屏幕点击 | ❌ 全部未命中 |
| Pipe 模式 (`--remote-debugging-pipe`) | 不走 TCP 端口 | ❌ 需父进程传 fd，命令行不可用 |

## 最终可用方案

### 当前（半自动）

```
CDP 导航 + 编辑 + 排版 → 用户 VNC 点一下发布
```

### 如果要全自动

```
CDP 导航 + 编辑 + 排版 → 断 CDP → VNC 截图 → OCR/template 匹配找按钮 → xdotool 点击
```

## 经验总结

1. **非标端口 + webdriver 隐藏** 是必要的，但不够——只是「入场券」
2. **应用级检测无法用 JS 注入绕过**——如果组件初始化时不挂载，注入什么都晚了
3. **不要用 Pipe 模式**——概念优雅但实用价值为零（`--remote-debugging-pipe` 需要父进程传文件描述符，命令行没法用）
4. **xdotool 盲扫不可靠**——按钮位置随页面内容变化，36 个位置全空
5. **保持 `--remote-debugging-port=19922`**——这是当前最佳伪装方案，Pipe 模式已废弃

## 适用场景速查

| 平台 | 伪装效果 | 备注 |
|------|---------|------|
| GitHub | ✅ 完全 OK | 操作仓库设置、PR、Pages |
| 小红书编辑器 | ✅ OK | 可填内容、排版 |
| 小红书发布 | ❌ 需手动 | CDP 走到发布页，VNC 点按钮 |
| 一般 CMS/网站 | ✅ 大概率 OK | `navigator.webdriver: false` 已够用 |
| 金融交易平台 | ⚠️ 未知 | 大概率有更深检测 |

---

**结论**：CDP 伪装能解决 80% 的场景。对于那 20% 做了应用级检测的平台，最好的武器不是更强的伪装，而是 **CDP 做它能做的，剩下的交给 VNC 手动或视觉自动化**。
