# CDP + VNC 操作踩坑记录

> 2026-06-14 | 部署私人博客时遇到的 Chrome CDP + VNC 操作问题合集

---

## 坑 1：WebSocket 频繁超时，管家「老是卡顿」

**现象**：`Page.navigate` 或 `Runtime.evaluate` 持续超时 30s，用户抱怨卡顿。

**根因**：Python `websocket` 库的 `create_connection(timeout=30)` 在国内访问 GitHub 时不够用。更坑的是——即使设了 `timeout=120`，库内部 recv 用的仍是 `socket.getdefaulttimeout()`。

**修复（一行解决）**：

```python
import socket
socket.setdefaulttimeout(120)  # 必须在 create_connection 之前
```

设完后 Page.navigate 从「30s 必超时」变成「1-5s 完成」。

**教训**：CDP 模板第一行就要写这个，不然后面每一步都卡。

---

## 坑 2：pkill -f chrome 杀掉了 terminal 自己

**现象**：`terminal()` 执行 `pkill -f chrome` → exit_code: -9，进程被杀。

**根因**：`terminal(background=true)` 启动的 bash 命令行里包含 `chrome` 字样，`pkill -f` 匹配到了自己。

**修复**：用 `execute_code` + `subprocess` 精确杀 PID：

```python
import subprocess
result = subprocess.run(["pgrep", "-f", "google-chrome-stable"], capture_output=True, text=True)
for pid in result.stdout.strip().split('\n'):
    if pid:
        subprocess.run(["kill", "-9", pid], capture_output=True)
```

**教训**：永远不要在 terminal() 里用 pkill -f 杀 Chrome。今天在这上面死了 3 次。

---

## 坑 3：跑了 headless Chrome 而不是 VNC 模式

**现象**：用户说「我怎么没看到你点击」。

**根因**：启动 Chrome 时没加 VNC 参数（`DISPLAY=:2` + `--ozone-platform=x11` + `--disable-gpu`），跑的是 headless 模式。CDP 能工作，但 VNC 上看不到任何操作。

**修复**：启动前 5 步检查清单：

```
□ VNC 在跑吗？    → pgrep Xtigervnc
□ Chrome 参数对吗？ → DISPLAY=:2 + --ozone-platform=x11 + --disable-gpu
□ 窗口在桌面 0 吗？ → xdotool set_desktop_for_window <WID> 0
□ 页面能交互吗？   → CDP Runtime.evaluate("document.title")
□ socket.setdefaulttimeout(120) 了吗？
```

---

## 坑 4：GitHub 新建仓库——React SPA 没有标准控件

**现象**：`document.querySelector('input[value="private"]')` → `null`。

**根因**：GitHub new repo 页面是 React SPA，可见性选择器用的是 `<button>` + 下拉菜单，不是 `<input type="radio">`。

**选择 Private 的正确步骤**：

1. 点击「Public」按钮 → 展开下拉
2. 找到 `textContent === 'Private'` 的 `<span>`（约 1036, 608）
3. 点击该 span 中心

**React 表单填值**也不能直接 `input.value = 'xxx'`，需要用原生 setter + dispatchEvent：

```js
const nativeSetter = Object.getOwnPropertyDescriptor(
    window.HTMLInputElement.prototype, 'value'
).set;
nativeSetter.call(input, 'notes-blog');
input.dispatchEvent(new Event('input', { bubbles: true }));
```

---

## 坑 5：GitHub 反自动化拦截

**现象**：提交表单时出现 `"You can't perform that action at this time."`

**可能原因**：GitHub 检测到 CDP 自动化行为。不要反复重试——会被更深地限流。

**降级方案**：表单填好后，让用户在 VNC 中手动点击提交按钮。人工点击不会被拦截。

---

## 坑 6：GitHub Pages 不支持私有仓库（免费）

**现象**：Pages 设置页显示「Upgrade or make this repository public to enable Pages」

**结论**：免费账号的 GitHub Pages 只支持公开仓库。私有博客需换 Netlify（免费 + 私有 + 原生密码保护）。

---

## 总结

| 坑 | 一句话 | 解决 |
|---|---|---|
| WebSocket 超时 | 国内 GitHub 太慢 | `socket.setdefaulttimeout(120)` |
| pkill 自残 | bash 名含 chrome | 用 subprocess 杀 PID |
| headless vs VNC | 用户看不到操作 | 启动检查清单 |
| React SPA 表单 | 没有标准控件 | 下拉 + setter + dispatchEvent |
| 反自动化 | GitHub 拦截 | 人工兜底 |
| Pages 限制 | 私有库不让用 | 换 Netlify |

> 以上 6 坑已全部写进 `chrome-cdp-browser` skill，下次不会再犯。
