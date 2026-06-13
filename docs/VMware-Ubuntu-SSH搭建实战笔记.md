# VMware Ubuntu SSH 搭建实战笔记

> 日期：2026-06-11 | 环境：Ubuntu 26.04 (Resolute Raccoon) @ VMware | 用户：kirito

---

## 目标

让外部 SSH 客户端（如 MobaXterm、Termius、VSCode Remote）连接到 VMware 虚拟机中的 Ubuntu。

---

## ❌ 失败的尝试

### 失败 1：apt install 找不到 openssh-server

```bash
sudo apt install -y openssh-server
# 错误：软件包 openssh-server 没有可安装候选
```

**现象**：`openssh-server` 本应是 Ubuntu 自带仓库的基础包，但 apt 完全找不到。

### 失败 2：apt search 空空如也

```bash
apt search ssh
# 只返回 libssh 和 libssh2（已安装的库），没有任何 server 相关包
```

### 失败 3：尝试源码编译

```bash
sudo apt install -y build-essential zlib1g-dev libssl-dev
# 错误：无法定位软件包 libssl-dev
```

连编译依赖都找不到，这条路也死了。

### 失败 4：走了歪路 — 想用 Python Twisted 搭 SSH

在发现 apt 没包之后，曾计划用 `pip install twisted` 自己写 SSH 服务，后来被纠正了——Ubuntu 26.04 怎么可能没 openssh-server？

---

## 🔍 根本原因

用户提醒：**"乌版图应该有的阿，请你去自行查询网络方案"**。

于是查了 Ubuntu 官方仓库：

```bash
curl "http://archive.ubuntu.com/ubuntu/dists/resolute/main/binary-amd64/Packages.gz" | zcat | grep "Package: openssh-server"
# Package: openssh-server ✅ — 确认包是存在的
```

再检查本机 apt 配置：

```bash
cat /etc/apt/sources.list    # 空文件！
ls /etc/apt/sources.list.d/  # 空目录！
```

**根源：`/etc/apt/sources.list` 是空的，apt 没有任何软件源可用，自然搜不到任何包。**

这是 Ubuntu 26.04 虚拟机模板的一个 bug——安装后没有自动生成 sources.list。

---

## ✅ 成功的方案

### 第 1 步：配置 apt 软件源

```bash
sudo tee /etc/apt/sources.list << 'EOF'
deb http://archive.ubuntu.com/ubuntu/ resolute main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ resolute-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ resolute-security main restricted universe multiverse
EOF

sudo apt update -qq
# 结果：136 个软件包可以升级 ← 说明源配置成功
```

### 第 2 步：安装 OpenSSH Server

```bash
sudo apt install -y openssh-server
# 成功安装，创建了 ssh.socket、ssh.service 等 systemd 单元
```

### 第 3 步：生成 SSH Host Keys

```bash
sudo ssh-keygen -A
# 生成了 ecdsa、ed25519、rsa 三种主机密钥
```

### 第 4 步：创建用户密钥对

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "kirito@kirito-VMware"
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### 第 5 步：启动 SSH 并设为开机自启

```bash
sudo systemctl start ssh
sudo systemctl enable ssh
```

### 第 6 步：验证

```bash
ss -tlnp | grep :22
# LISTEN 0.0.0.0:22 ✅ IPv4 和 IPv6 都在监听

sudo systemctl status ssh
# Active: active (running) ✅
```

---

## 📋 最终连接参数

| 参数 | 值 |
|------|------|
| IP 地址 | `192.168.99.108` |
| 端口 | `22` |
| 用户名 | `kirito` |
| 认证方式 | 密钥（ed25519）+ 密码 |

### 方式一：密钥认证（推荐）

```bash
# 从外部机器连接（需要先把私钥复制过去）
ssh -i id_ed25519 kirito@192.168.99.108
```

私钥内容：`cat /home/kirito/.ssh/id_ed25519`

主机指纹：
```
SHA256:ODDdKNrHqBXMnAg+gHtAQRgD441wTDeIwUEoAvAcaVo
```

### 方式二：密码认证

```bash
ssh ***9202@192.168.99.108
```

### 方式三：如果 SSH 端口不通（VMware NAT 网络）

检查 VMware 网络模式：
- **桥接模式**：虚拟机直接连物理网络 → 192.168.99.108 可直连
- **NAT 模式**：需要配置端口转发

```bash
# 检查当前 IP
ip addr show ens33 | grep "inet "
# inet 192.168.99.108/24 ← 桥接模式
```

---

## 🎯 经验总结

### 核心教训

| 问题 | 教训 |
|------|------|
| apt 找不到包 | 先检查 `sources.list` 是否配置了软件源 |
| 不要凭直觉走歪路 | 去官网验证（archive.ubuntu.com）而不是想着自己写 |
| Ubuntu 26.04 模板 bug | `sources.list` 可能是空的，需要手动配置 |

### 防御性检查流程

```
遇到 "apt 找不到包" →
1. cat /etc/apt/sources.list          ← 源配置存在吗？
2. ls /etc/apt/sources.list.d/       ← 有子配置吗？
3. curl 官网仓库确认包存在             ← 包真的在仓库里吗？
4. 重配源 → apt update → apt install  ← 修复
```

### 常用管理命令

```bash
# 查看 SSH 状态
sudo systemctl status ssh

# 重启 SSH
sudo systemctl restart ssh

# 查看连接日志
sudo journalctl -u ssh -f

# 查看当前登录用户
who

# 查看失败登录尝试
sudo lastb | head -10
```
