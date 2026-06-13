# Dify Docker 部署实战笔记

> 日期：2026-06-10 | 环境：Ubuntu 24.04, Docker 29.1.3 | 用户：kirito

---

## 一、项目概述

**Dify** 是开源的 LLM 应用开发平台，采用微服务架构，一个完整部署包含 12 个容器：

| 容器 | 镜像 | 作用 |
|------|------|------|
| nginx | nginx:latest | 反向代理，端口 80/443 |
| web | langgenius/dify-web:1.14.2 | 前端 Next.js UI |
| api | langgenius/dify-api:1.14.2 | 核心 REST API |
| worker | langgenius/dify-api:1.14.2 | Celery 异步任务处理 |
| worker_beat | langgenius/dify-api:1.14.2 | Celery 定时任务调度 |
| api_websocket | langgenius/dify-api:1.14.2 | WebSocket 流式输出 |
| plugin_daemon | langgenius/dify-plugin-daemon:0.6.1-local | 插件运行时 |
| sandbox | langgenius/dify-sandbox:0.2.15 | 代码执行沙箱 (660MB) |
| db_postgres | postgres:15-alpine | PostgreSQL 数据库 |
| redis | redis:6-alpine | Redis 缓存/消息队列 |
| weaviate | semitechnologies/weaviate:1.27.0 | 向量数据库 |
| ssrf_proxy | ubuntu/squid:latest | SSRF 防护代理 |

---

## 二、失败的尝试 ❌

### 1. Docker Hub 直连超时

```bash
docker pull hello-world
# Error: Get "https://registry-1.docker.io/v2/": context deadline exceeded
```

**原因**：国内网络环境，Docker Hub 被墙/限速。

### 2. GitHub 仓库克隆超时

```bash
git clone https://github.com/langgenius/dify.git --depth 1
# 300 秒超时，无法完成
```

**原因**：GitHub 在国内虽然 ping 通（~98ms），但大仓库克隆速度极慢。

### 3. 国内 Git 代理失败

```bash
# 尝试 1：gitclone.com → 502 Bad Gateway
git clone https://gitclone.com/github.com/langgenius/dify.git

# 尝试 2：ghproxy.com → 无法连接
git clone https://ghproxy.com/https://github.com/langgenius/dify.git
```

**原因**：这些代理站不稳定，经常挂掉。

### 4. 镜像源 `hub.rat.dev` 不可靠

初始镜像源配置只有一个 `hub.rat.dev`，拉取镜像时频繁超时。

### 5. sudo 密码管道注意点

```bash
echo "kirito" | sudo -S command  # 方式有时会认证失败
echo 'kirito' | sudo -S command  # 注意单双引号，大括号内变量
```

---

## 三、成功的方案 ✅

### 第 1 步：更新 Docker 镜像源

```bash
# 写入国内可用的镜像源
echo 'kirito' | sudo -S tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1panel.live",
    "https://hub.rat.dev"
  ],
  "dns": ["114.114.114.114", "223.5.5.5", "8.8.8.8"]
}
EOF

# 重启 Docker
echo 'kirito' | sudo -S systemctl daemon-reload
echo 'kirito' | sudo -S systemctl restart docker
```

> **经验**：DaoCloud 和 1Panel 的镜像源在 2026 年 6 月仍然可用，建议放前面。`hub.rat.dev` 仅作备用。

### 第 2 步：下载项目源码（绕过 git clone）

```bash
# 用 GitHub 的 tarball API 下载，比 git clone 更稳定
curl -sL --connect-timeout 30 \
  -o /tmp/dify.tar.gz \
  "https://codeload.github.com/langgenius/dify/tar.gz/main"
```

**关键洞察**：不要死磕 `git clone`！`codeload.github.com` 下载 tarball 比 git 协议稳定得多。国内环境下载 GitHub 大项目，tarball 方案优先。

### 第 3 步：解压到目标目录

```bash
mkdir -p /home/kirito/dify
tar -xzf /tmp/dify.tar.gz -C /home/kirito/dify --strip-components=1
```

### 第 4 步：配置环境变量

```bash
cd /home/kirito/dify/docker

# 复制配置模板
cp .env.example .env

# 生成随机 SECRET_KEY（安全必需）
openssl rand -hex 32 | xargs -I{} sed -i "s|SECRET_KEY=.*|SECRET_KEY={}|" .env
```

> **重要**：不要用 `.env.example` 里的默认密钥！必须生成自己的，否则不安全。

### 第 5 步：验证镜像源可用

```bash
echo "kirito" | sudo -S docker pull busybox:latest
# 能看到正常下载 → 镜像源配置成功
```

### 第 6 步：后台启动 Docker Compose

```bash
cd /home/kirito/dify/docker
echo "kirito" | sudo -S docker compose up -d
```

**预计耗时**：
- 首次拉取镜像：5-15 分钟（取决于网络）
- 最大镜像：`dify-sandbox` 约 660MB
- 容器启动：约 30 秒

### 第 7 步：验证服务状态

```bash
# 查看所有容器
docker ps --format "table {{.Names}}\t{{.Status}}"

# 验证 Web 可访问
curl -sL -o /dev/null -w "HTTP: %{http_code}" http://localhost
```

---

## 四、最终运行状态

| 容器 | 状态 | 端口 |
|------|------|------|
| docker-nginx-1 | ✅ Up | 80, 443 |
| docker-web-1 | ✅ Up | 3000（内部） |
| docker-api-1 | ✅ Up + healthy | 5001（内部） |
| docker-worker-1 | ✅ Up | - |
| docker-worker_beat-1 | ✅ Up | - |
| docker-api_websocket-1 | ✅ Up | - |
| docker-plugin_daemon-1 | ✅ Up | 5003 |
| docker-sandbox-1 | ✅ Up + healthy | - |
| docker-db_postgres-1 | ✅ Up + healthy | 5432 |
| docker-redis-1 | ✅ Up + healthy | 6379 |
| docker-weaviate-1 | ✅ Up | - |
| docker-ssrf_proxy-1 | ✅ Up | 3128 |

### 访问地址

- **本机**：`http://localhost`
- **局域网**：`http://<内网IP>`

---

## 五、踩坑经验总结

### 🔑 核心经验

1. **国内部署 Dify 的三大难点**：
   - GitHub 源码下载 → 用 tarball 代替 git clone
   - Docker 镜像拉取 → 配置国内镜像源
   - 大镜像（660MB sandbox）→ 耐心等待 + 后台执行

2. **镜像源优先级**：
   ```
   docker.m.daocloud.io > docker.1panel.live > hub.rat.dev
   ```
   前两个在 2026.6 实测可用，`hub.rat.dev` 稳定性差。

3. **下载策略**：
   ```
   codeload.github.com tarball > git clone > 国内代理站
   ```
   gitclone.com / ghproxy.com 在 2026 年几乎不可用。

4. **大任务放后台**：
   `docker compose up -d` 首次执行要拉取 ~1.5GB 镜像，务必在后台运行，等待完成通知。

### ⚠️ 注意事项

- **sudo 密码**：`echo "password" | sudo -S` 在单引号 EOF 场景下注意变量展开问题
- **磁盘空间**：项目 + 镜像 + 数据约需 15-20GB，确保 `/home` 有足够空间
- **Docker 重启**：修改 `/etc/docker/daemon.json` 后必须 `systemctl daemon-reload` + `systemctl restart docker`

### 📋 常用管理命令

```bash
# 查看所有容器状态
docker ps

# 查看日志（某个服务）
docker logs docker-api-1 --tail 50

# 停止所有服务
cd /home/kirito/dify/docker
echo "kirito" | sudo -S docker compose down

# 重启所有服务
echo "kirito" | sudo -S docker compose up -d

# 更新镜像并重启
echo "kirito" | sudo -S docker compose pull
echo "kirito" | sudo -S docker compose up -d --force-recreate
```

---

## 六、参考

- Dify 官方仓库：https://github.com/langgenius/dify
- Docker Compose 配置：`/home/kirito/dify/docker/docker-compose.yaml`
- 环境配置：`/home/kirito/dify/docker/.env`
- Docker 镜像源配置：`/etc/docker/daemon.json`
