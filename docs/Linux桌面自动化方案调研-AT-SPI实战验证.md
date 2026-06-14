# Linux 桌面自动化方案调研：AT-SPI 实战验证

2026-06-14 · Hermes 调研

## 起因

王哥哥问：「Linux 没有操作 exe 的开源方案吗？Ubuntu 开源这么多年不该没有。」

本文是完整调研结果——从方案对比到 GNOME 原生应用实机验证，最后修正自动化策略。

## 一、三层方案：运行 exe → 读控件树 → 模拟输入

### 1.1 让 exe 跑起来

| 方案 | 原理 | 成熟度 |
|------|------|:---:|
| Wine | API 翻译层 | ⭐⭐⭐⭐⭐ |
| Proton (Valve) | Wine + DXVK + VKD3D | ⭐⭐⭐⭐⭐ |
| KVM/QEMU + Windows VM | 完整虚拟机 | ⭐⭐⭐⭐⭐ |
| Docker + Wine | 容器隔离 | ⭐⭐⭐ |

### 1.2 Linux 控件树体系（对标 Windows UIA）

Linux 的答案叫 **AT-SPI**（DBus 辅助功能协议），工具链对标 Windows：

| Linux | Windows | Stars |
|-------|---------|-------|
| AT-SPI (DBus) | UIA (COM) | GNOME 内置 |
| Accerciser | Inspect.exe | — |
| pyatspi2/dogtail | pywinauto | ⭐6069(对标) |
| xdotool | AutoHotkey | ⭐3813 |
| ydotool | — | ⭐2247 |

### 1.3 输入模拟

xdotool(X11) / ydotool(Wayland) / AT-SPI2 generateMouseEvent（走辅助技术通道，Wayland 不拦截）。

## 二、实机验证：AT-SPI 控件树真的能用吗？

在 GNOME Wayland 桌面下实测两个原生应用：

### gnome-calculator（计算器）

运行 `python3 + pyatspi2` 读控件树：

```
application [gnome-calculator]
  frame [计算器]
    panel []
      panel []
        grouping []
          panel []
            scroll pane []
              text []
            button [退格键]   ← 唯一有名字的按钮
```

**数字按钮全部没有 accessibility name。** `grouping` 节点没有 `Component` 和 `Action` 接口。

### gnome-control-center（系统设置）

```
grouping [设置]
grouping [键盘]     ← 有名字
```

但有名字的节点也不支持 `Component`（坐标）和 `Action`（点击）。

### 结论

| 应用 | 有 name | 有 Component | 有 Action | 可纯控件树操作 |
|------|:---:|:---:|:---:|:---:|
| gnome-calculator | ⚠️ 仅退格键 | ❌ | ❌ | ❌ |
| gnome-control-center | ✅ | ❌ | ❌ | ❌ |
| Chrome | ⚠️ 仅窗口标题 | ⚠️ 仅顶层 | ❌ | ❌ |

**AT-SPI 协议完善，但 GTK 应用实现参差不齐。** 这和 Windows UIA 不在一个水平——UIA 几乎每个按钮都完整暴露。

## 三、修正后的策略

### 旧策略（❌ 已废弃）

> 「能走无障碍树绝不截图」

### 新策略（✅ 已验证）

```
📸 截图定位 → OpenCV匹配 → AT-SPI2点击   ← 主力，最可靠
🔍 控件树解析                            ← 备选，只有实现好的应用可用
⌨️ 窗口树 + 快捷键                       ← 轻量退路
👁️ 用户裁图                              ← 零成本兜底
```

**核心修正：截图+匹配优先，控件树是备选。** GTK 不给完整 accessibility 数据是老毛病。

## 四、Wine exe 的路

Wine 有实验性 `winea11y.drv` 桥接 MSAA→AT-SPI，但：
- 需编译时启用
- 依赖目标 exe 实现 MSAA
- 实际不可靠

**退路：**
1. **KVM 虚拟机 + pywinauto(⭐6069)** → Windows 内部用 UIA 拿完整控件树 → 网络传回。所有组件经过大规模验证。
2. **Wine + Portal截图 + OpenCV + AT-SPI2点击** → 不依赖控件树。
3. **Wine + 窗口树 + 键盘快捷键** → 最轻量。

## 五、搜索引擎调研限制

- Bing 英文搜索：国内 IP 强制返回中文（`cc=us&setmkt=en-US` 无效）
- DuckDuckGo：被墙
- CDP Pipe 模式（`--remote-debugging-pipe`）：需要父进程传 fd，命令行不可用
- **可靠路径**：GitHub 直接搜索 + CDP 开页面 + curl 抓 README

## 六、关键数据

| 项目 | Stars | 判断 |
|------|-------|------|
| pywinauto (Windows 对标) | ⭐6069 | ✅ 行业标准 |
| xdotool | ⭐3813 | ✅ 生产级 |
| ydotool | ⭐2247 | ✅ 生产级 |
| AccessKit | ⭐1473 | ✅ 基础设施 |
| clawdcursor | ⭐341 | ⚠️ 太小，不推荐 |
| kwin-mcp | ⭐28 | ⚠️ 太小，仅 KDE |

## 结论

**Linux 能操作 exe。** 但不要指望纯控件树——GTK 应用不给面子。可靠路径是 `Portal截图 + OpenCV + AT-SPI2点击`。对于 Wine exe，KVM 虚拟机是最完整的方案。
