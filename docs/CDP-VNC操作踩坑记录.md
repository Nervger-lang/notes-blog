---
date: 2026-06-14
---

# CDP + VNC 操作踩坑记录

> **事件**：部署 MkDocs 私人博客到 GitHub  
> **日期**：2026-06-14  
> **环境**：Ubuntu 26.04 VM，Chrome 149，VNC :2，CDP :9222  
> **用户账号**：Nervger-lang（GitHub），王哥哥企微私聊

---

## 事件时间线

```
05:45  登录 GitHub，开始用 CDP 创建 notes-blog 仓库
05:48  ❌ Page.navigate 超时（坑1）
05:50  ❌ pkill -f chrome 杀了 terminal 自己 × 3 次（坑2）
05:51  ❌ Chrome 断连，重启动发现 VNC 没跑（坑3）
05:55  ❌ 填完表单点提交，GitHub 拦截（坑5）
05:56  ✅ socket.setdefaulttimeout(120) → 秒通
05:58  ✅ 点击 Public → 展开 Private → 选中 → 提交成功
06:00  ❌ 用户说「我怎么没看到你点击」（坑3）
06:01  ✅ VNC Chrome 启动，5步检查 → CDP 操作可见
06:04  ✅ SSH Key 通过 CDP 添加到 GitHub
06:05  ✅ git push 成功
06:08  ❌ GitHub Pages 提示需公开仓库或升级（坑6）
06:10  📝 开始写这篇日志
```

---

## 坑 1：WebSocket 频繁超时

| 项目 | 内容 |
|------|------|
| **首次发生** | 05:48，Page.navigate("https://github.com/new") |
| **触发原因** | 国内网络访问 GitHub 慢，30s 默认超时不够 |
| **用户反馈** | 「你怎么老是卡顿」 |

**根因**：`websocket.create_connection(timeout=30)` 设了 30s，但 Python websocket 库内部 recv 用的是 `socket.getdefaulttimeout()`，构造函数的 timeout 形同虚设。

**修复**：
```python
import socket
socket.setdefaulttimeout(120)  # 一行全局搞定
```

---

## 坑 2：pkill -f chrome 杀 terminal 自己

| 项目 | 内容 |
|------|------|
| **发生次数** | 3 次（05:50 连续触发） |
| **触发原因** | 每次切 Chrome 模式都要先杀旧 Chrome，顺手用了 `terminal("pkill -f chrome")` |
| **系统表现** | exit_code: -9, -15；TUI 显示 `tool_loop_warning: count=3` |
| **用户反馈** | 没直接说，但 3 次失败导致卡顿加剧 |

**根因**：`terminal(background=true)` 的 bash 进程名含 `chrome`，pkill 连自己一起杀。

**修复**：杀 Chrome 永远用 `execute_code` + `subprocess.run(["kill", "-9", pid])`。

---

## 坑 3：跑了 headless Chrome，用户 VNC 上看不到

| 项目 | 内容 |
|------|------|
| **首次发生** | 05:51，Chrome 断连后重启 |
| **触发原因** | VNC 之前没跑（`vncserver` 没启动），Chrome 只能用 headless |
| **用户反馈** | 06:00 「我怎么没看到你点击」 |

**根因**：没做 VNC 前置检查。Chrome 能连 CDP、能做操作，但用户看不见。

**修复**：VNC 模式 5 步启动清单：
```
□ pgrep Xtigervnc           → VNC 在跑吗
□ DISPLAY=:2 --ozone-platform=x11 --disable-gpu  → 参数对吗
□ xdotool set_desktop_for_window <WID> 0  → 窗口可见吗
□ CDP Runtime.evaluate("document.title")  → 页面能交互吗
□ socket.setdefaulttimeout(120)            → 超时设了吗
```

---

## 坑 4：GitHub React SPA 没有标准表单控件

| 项目 | 内容 |
|------|------|
| **首次发生** | 05:46，尝试 `document.querySelector('input[value="private"]')` |
| **触发原因** | 以为可见性选择器是 `<input type="radio">`，实际是 React 自定义按钮+下拉菜单 |
| **耗时** | 约 10 分钟（定位、截图、分析、尝试） |

**修复**：
1. 点击「Public」按钮 → 展开下拉
2. 找 `textContent === 'Private'` 的 span
3. React 填值：`HTMLInputElement.prototype.value.setter.call(input, val)` + `dispatchEvent(new Event('input'))`

---

## 坑 5：GitHub 反自动化拦截

| 项目 | 内容 |
|------|------|
| **首次发生** | 05:55，点击「Create repository」|
| **触发原因** | CDP 自动化行为被 GitHub 后端检测 |
| **错误信息** | `"You can't perform that action at this time."` |
| **解决方式** | 没硬刚。05:58 换新页面重填表单→成功 |

**教训**：不要反复重试同一请求。等几秒刷新页面再来。

---

## 坑 6：GitHub Pages 私有仓库限制

| 项目 | 内容 |
|------|------|
| **首次发生** | 06:08，进入 Settings → Pages |
| **触发原因** | 仓库设了 Private，GitHub Pages 免费版只支持公开仓库 |
| **页面提示** | `"Upgrade or make this repository public to enable Pages"` |
| **待解决** | 换 Netlify（免费 + 私有仓库 + 原生密码保护） |

---

## 事件总结

| # | 坑 | 时间 | 触发操作 | 解决 | 耗时 |
|---|---|---|---|---|---|
| 1 | WebSocket 超时 | 05:48 | Page.navigate GitHub | `socket.setdefaulttimeout(120)` | 8min |
| 2 | pkill 自残 | 05:50 | 重启 Chrome | `subprocess.run(["kill", pid])` | 2min |
| 3 | headless 跑偏 | 05:51 | Chrome 断连重启 | VNC 5步检查清单 | 9min |
| 4 | React SPA 控件 | 05:46 | 找 Private 单选 | 下拉+setter+dispatchEvent | 10min |
| 5 | 反自动化拦截 | 05:55 | 提交表单 | 刷新重试 | 3min |
| 6 | Pages 私有限制 | 06:08 | 开 Pages | → Netlify | 待定 |

> 📌 6 坑全部录入 `chrome-cdp-browser` skill，下次有同类操作直接加载避免重复踩坑。
