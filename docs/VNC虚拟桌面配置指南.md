# VNC 虚拟桌面完整配置指南

> 2026-06-14 | Ubuntu 26.04 + TigerVNC + Xfce4 + Chrome

---

## 一、安装

```bash
sudo apt-get install -y xfce4 xfce4-goodies tigervnc-standalone-server tigervnc-common openbox picom
```

---

## 二、Ubuntu 26.04 特殊处理（关键！）

### 🕳️ 坑：xfwm4 不兼容 → VNC 黑屏

Ubuntu 26.04 的 xfdesktop 和 xfwm4 依赖 Wayland 的 `zwlr_layer_shell_v1` 协议，TigerVNC 的 X11 服务器不支持，直接导致整个桌面黑屏。

**解决：用 openbox 替代 xfwm4，xfce4-panel 配合使用。**

### xstartup 配置

```bash
mkdir -p ~/.config/tigervnc
echo "你的密码" | vncpasswd -f > ~/.config/tigervnc/passwd
chmod 600 ~/.config/tigervnc/passwd

cat > ~/.config/tigervnc/xstartup << 'EOF'
#!/bin/sh
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
unset WAYLAND_DISPLAY
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xfsettingsd &
xfce4-panel &
exec openbox
EOF
chmod +x ~/.config/tigervnc/xstartup
```

> ⚠️ Ubuntu 26.04 的 TigerVNC 优先读 `~/.config/tigervnc/`，不是 `~/.vnc/`

---

## 三、启动 VNC

### 杀旧实例

```bash
vncserver -kill :2 2>/dev/null
pkill -9 Xtigervnc 2>/dev/null
sleep 2
rm -f /tmp/.X11-unix/X2 /tmp/.X1-lock
```

### 启动

```bash
vncserver :2 -geometry 1920x1080 -depth 24 -localhost no
```

- 端口：**5902**（display :2）
- `-localhost no`：允许远程连接

### 如果端口冲突

```bash
# :2 被占用了就换 :3（端口 5903）
pkill -9 Xtigervnc
rm -f /tmp/.X11-unix/X2 /tmp/.X1-lock
vncserver :3 -geometry 1920x1080 -depth 24 -localhost no
```

---

## 四、VNC Chrome 启动（大坑合集）

### 🕳️ 坑 1：GPU 偷跑 Wayland → VNC 黑屏

```
Chrome GPU 进程默认 --ozone-platform=wayland
  → 渲染输出到宿主机真实桌面
  → VNC X11 虚拟桌面什么都没收到
  → 用户看到黑屏
```

### 🕳️ 坑 2：`--disable-gpu` 单用不够

仅 `--disable-gpu` 会完全杀死 GPU 进程，Chrome 失去渲染能力 → 同样黑屏。

### 🕳️ 坑 3：`--use-gl=swiftshader` 不可用

系统不支持 SwiftShader，GPU 进程反复崩溃：
```
ERROR: gl_factory.cc:110
Requested GL implementation (gl=none,angle=none) not found
Allowed: [(gl=egl-angle,angle=default)]
```

### 🕳️ 坑 4：Chrome 被放到虚拟桌面

Chrome 窗口可能出现在虚拟桌面 3（`_NET_WM_DESKTOP = 3`），用户看不到。用 xdotool 搬到桌面 0：
```bash
DISPLAY=:2 xdotool set_desktop_for_window <窗口ID> 0
```

### 🕳️ 坑 5：picom 合成器兼容性

picom 的 xrender 后端可能与 Chrome 的 ANGLE 渲染冲突，杀掉它：
```bash
pkill picom
```

---

## 五、✅ 最终 Chrome 启动命令

```bash
# 杀干净旧的
pkill -f google-chrome 2>/dev/null
sleep 2

# 环境变量锁死 X11
export DISPLAY=:2
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
unset WAYLAND_DISPLAY

# 启动 Chrome
google-chrome-stable \
  --no-sandbox \
  --ozone-platform=x11 \
  --disable-gpu \
  --disable-gpu-compositing \
  --disable-software-rasterizer \
  --disable-features=VizDisplayCompositor \
  --remote-debugging-port=9222 \
  --remote-allow-origins=* \
  --user-data-dir=/tmp/chrome-xhs \
  --window-size=1920,1080 \
  --no-first-run \
  --no-default-browser-check \
  --new-window "https://www.baidu.com" \
  2>/tmp/chrome_vnc.log &
```

### 参数说明

| 参数 | 作用 |
|------|------|
| `--ozone-platform=x11` | **强制 X11**，防止 GPU 偷跑 Wayland（最关键！） |
| `--disable-gpu` | 禁用 GPU 硬件加速 |
| `--disable-gpu-compositing` | 禁用 GPU 合成 |
| `--disable-software-rasterizer` | 禁用软件光栅化 |
| `--disable-features=VizDisplayCompositor` | 关闭 Viz 合成器 |
| `--no-sandbox` | 消除沙箱兼容问题 |
| `--remote-debugging-port=9222` | CDP 控制端口 |
| `--remote-allow-origins=*` | 允许 WebSocket 连接 |

---

## 六、客户端连接

- **地址**：`192.168.99.108:5902`
- **密码**：你设的那个
- **Mac**：`Cmd+K` → `vnc://192.168.99.108:5902`
- **Windows/Linux**：任意 VNC Viewer（TigerVNC、RealVNC、TightVNC 都免费）

---

## 七、诊断命令

```bash
# VNC 进程
ps aux | grep Xtigervnc

# Chrome 进程
pgrep -af chrome | grep -v crashpad

# 窗口列表
DISPLAY=:2 xdotool search --name "" getwindowname

# 窗口桌面位置
DISPLAY=:2 xprop -id <窗口ID> _NET_WM_DESKTOP

# 截图验证
DISPLAY=:2 import -window root /tmp/vnc_check.png

# VNC 端口
ls /tmp/.X11-unix/X*
```

---

## 八、速查：黑屏排查流程

```
1. VNC 服务在跑吗？    → ps aux | grep Xtigervnc
2. Chrome 在跑吗？      → pgrep -af chrome
3. Chrome 有窗口吗？    → DISPLAY=:2 xdotool search --name Chrome
4. 窗口在哪个桌面？     → DISPLAY=:2 xprop -id <ID> _NET_WM_DESKTOP
5. Wayland 在捣乱吗？   → 检查 --ozone-platform 参数
6. GPU 进程在崩溃吗？   → tail /tmp/chrome_vnc.log | grep ERROR
7. 截图看看？          → DISPLAY=:2 import -window root /tmp/test.png
```
