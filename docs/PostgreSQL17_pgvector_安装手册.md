# PostgreSQL 17 + pgvector 安装手册

> **部署日期**：2026-06-22  
> **容器名**：`postgres-hermes`  
> **宿主机端口**：`5433`  
> **镜像**：`pgvector/pgvector:pg17`（PG 17 + pgvector 0.8.3）  
> **数据卷**：`pgdata-hermes`  

---

## 一、安装命令（备忘）

```bash
# 拉取镜像（已执行）
docker pull pgvector/pgvector:pg17

# 创建容器（已执行）
docker run -d \
  --name postgres-hermes \
  -p 5433:5432 \
  -e POSTGRES_USER=kirito \
  -e POSTGRES_PASSWORD=*** \
  -e POSTGRES_DB=kirito \
  -v pgdata-hermes:/var/lib/postgresql/data \
  --restart=unless-stopped \
  pgvector/pgvector:pg17
```

> 🔑 密码见本地，文档不存明文。

---

## 二、连接方式

### 宿主机连接

```bash
# 设 .pgpass（一次，免密码）
echo "localhost:5433:kirito:kirito:<密码>" > ~/.pgpass
chmod 0600 ~/.pgpass

# 然后直接连，无需 -W
psql -h localhost -p 5433 -U kirito -d kirito

# 或环境变量方式
export PGPASSWORD='<密码>'
psql -h localhost -p 5433 -U kirito -d kirito
```

### Python 连接（psycopg2 / SQLAlchemy）

```python
import psycopg2

conn = psycopg2.connect(
    host="localhost",
    port=5433,
    user="kirito",
    password="<密码>",
    dbname="kirito"
)
```

### 远程连接（从另一台机器）

```bash
# 宿主机 IP: 192.168.99.108
psql -h 192.168.99.108 -p 5433 -U kirito -d kirito
```

### Docker 内部连接（其他容器）

```bash
# 先加入同一网络
docker network connect docker_default postgres-hermes

# 从同网络容器连接
psql -h postgres-hermes -p 5432 -U kirito -d kirito
```

---

## 三、pgvector 使用

pgvector 版本：**0.8.3**（已安装）

### 创建向量扩展（每个库执行一次）

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

### 建表

```sql
-- 1536 维 = OpenAI text-embedding-ada-002
CREATE TABLE documents (
    id       SERIAL PRIMARY KEY,
    content  TEXT,
    metadata JSONB,
    embedding VECTOR(1536)
);
```

### 常用维度对照

| 模型 | 维度 |
|------|------|
| OpenAI text-embedding-ada-002 | 1536 |
| OpenAI text-embedding-3-small | 1536 |
| OpenAI text-embedding-3-large | 3072 |
| BGE-M3 / BGE-large-zh | 1024 |
| Cohere embed-v3 | 1024 |
| Jina embeddings v2 | 768 |

### 插入向量

```sql
INSERT INTO documents (content, embedding)
VALUES ('这是一段文本',  '[0.1, 0.2, ..., 0.1536]'::vector);
```

### 相似度查询（核心）

```sql
-- 余弦距离（推荐：值越小越相似）
SELECT content, embedding <=> '[0.1, ...]'::vector AS cosine_distance
FROM documents
ORDER BY embedding <=> '[0.1, ...]'::vector
LIMIT 10;

-- L2 欧氏距离
SELECT content, embedding <-> '[0.1, ...]'::vector AS l2_distance
FROM documents
ORDER BY embedding <-> '[0.1, ...]'::vector
LIMIT 10;

-- 内积（越大越相似）
SELECT content, embedding <#> '[0.1, ...]'::vector AS inner_product
FROM documents
ORDER BY embedding <#> '[0.1, ...]'::vector DESC
LIMIT 10;
```

### 索引（性能关键！）

```sql
-- 精确搜索：10000 条以内
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops);

-- 近似搜索：10 万条以上（更快，精度略降）
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- HNSW：百万级数据推荐（PG 17 + pgvector 0.8+）
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops);
```

⚠️ **索引锚点**：建索引前先插够数据，`lists` 建议 = `sqrt(行数)`。空表建索引再大量插入性能很差。

---

## 四、Docker 管理命令

### 日常操作

```bash
# 查看状态
docker ps --filter name=postgres-hermes

# 查看日志
docker logs --tail 50 -f postgres-hermes

# 进入容器
docker exec -it postgres-hermes /bin/sh
docker exec -it postgres-hermes psql -U kirito

# 停止
docker stop postgres-hermes

# 启动
docker start postgres-hermes

# 重启
docker restart postgres-hermes

# 删除容器（数据卷还在）
docker stop postgres-hermes && docker rm postgres-hermes

# 重建容器（保留数据）
docker stop postgres-hermes && docker rm postgres-hermes
docker run -d \
  --name postgres-hermes \
  -p 5433:5432 \
  -e POSTGRES_USER=kirito \
  -e POSTGRES_PASSWORD=*** \
  -e POSTGRES_DB=kirito \
  -v pgdata-hermes:/var/lib/postgresql/data \
  --restart=unless-stopped \
  pgvector/pgvector:pg17
```

### 数据卷管理

```bash
# 查看数据卷位置
docker volume inspect pgdata-hermes

# 备份数据卷
docker run --rm -v pgdata-hermes:/data -v $(pwd):/backup alpine \
  tar czf /backup/pgdata-hermes-$(date +%Y%m%d).tar.gz -C /data .

# 恢复数据卷（⚠️ 会覆盖现有数据）
docker run --rm -v pgdata-hermes:/data -v $(pwd):/backup alpine \
  tar xzf /backup/pgdata-hermes-20260622.tar.gz -C /data
```

---

## 五、PostgreSQL 常用命令速查

### 数据库管理

```sql
-- 查看所有数据库（需超级用户）
\l
-- 或
SELECT datname FROM pg_database;

-- 创建新数据库
CREATE DATABASE mydb OWNER kirito;

-- 切换数据库
\c mydb

-- 删除数据库
DROP DATABASE IF EXISTS mydb;
```

### 表操作

```sql
-- 查看所有表
\dt
-- 或
SELECT tablename FROM pg_tables WHERE schemaname='public';

-- 查看表结构
\d table_name

-- 查看表大小
SELECT pg_size_pretty(pg_total_relation_size('table_name'));

-- 查看所有表大小
SELECT tablename, pg_size_pretty(pg_total_relation_size(tablename)) 
FROM pg_tables WHERE schemaname='public'
ORDER BY pg_total_relation_size(tablename) DESC;
```

### 用户管理

```sql
-- 查看用户
\du

-- 创建用户
CREATE USER newuser WITH PASSWORD 'password';

-- 授权
GRANT ALL PRIVILEGES ON DATABASE mydb TO newuser;
GRANT ALL ON ALL TABLES IN SCHEMA public TO newuser;

-- 改密码
ALTER USER kirito WITH PASSWORD 'newpassword';
```

### 性能查看

```sql
-- 当前连接
SELECT * FROM pg_stat_activity;

-- 慢查询（需开启日志）
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC LIMIT 10;

-- 锁等待
SELECT * FROM pg_locks WHERE NOT granted;

-- 数据库总大小
SELECT pg_size_pretty(pg_database_size('kirito'));
```

### 导入导出

```bash
# 导出整个库
pg_dump -h localhost -p 5433 -U kirito kirito > backup.sql

# 导出单表
pg_dump -h localhost -p 5433 -U kirito -t table_name kirito > table.sql

# 导入
psql -h localhost -p 5433 -U kirito -d kirito < backup.sql

# 压缩导出+导入（一条龙）
pg_dump -h localhost -p 5433 -U kirito kirito | gzip > backup.sql.gz
gunzip < backup.sql.gz | psql -h localhost -p 5433 -U kirito -d kirito
```

---

## 六、坑点 ⚠️（踩过的、会踩的）

### 🔴 坑1：ivfflat 索引和空表
- **问题**：表里没数据就建 ivfflat 索引 → 后续大批量插入性能极差
- **解法**：先插够数据（至少几千条），再 `CREATE INDEX`

### 🔴 坑2：lists 参数选错
- **问题**：`lists` 太大 → 精度高但慢；太小 → 快但精度差
- **锚点**：`lists = sqrt(表行数)`，1 万行 = 100 lists，10 万行 = 316

### 🔴 坑3：向量维度不匹配
- **问题**：建表 `vector(1536)`，插入 1024 维向量 → 直接报错
- **解法**：建表前确认 embedding 模型维度，建完不能改！只能重建表

### 🟡 坑4：pg_dump 不备份扩展
- `pg_dump` 导出 SQL 时不含 `CREATE EXTENSION vector`，恢复后需手动执行

### 🟡 坑5：重建容器端口冲突
- 重建时忘记 `-p 5433:5432` → 容器起得来但连不上，因为没端口映射

### 🟡 坑6：删除容器时加了 `-v`
- `docker rm -v postgres-hermes` 会**删除数据卷**！数据全部消失！
- 安全做法：不加 `-v`，数据卷永久保留

### 🟡 坑7：忘记重启策略
- 不加 `--restart=unless-stopped` → 服务器重启后 PG 不会自动起来
- `unless-stopped`：除非你手动 stop，否则永远自动重启

### 🟢 坑8：连接被拒 / peer authentication
- 宿主机 `psql -h localhost` 和容器内 `psql` 走不同认证方式
- 走 TCP 用 scram-sha-256/密码认证（正常），走 Unix socket 用 peer 认证（报错）
- 宿主机用 `-h localhost` 强制 TCP

### 🔴 坑9：pgvector 镜像 TCP 强制密码认证（2026-06-22 实测）
- **现象**：宿主机 `psql -h localhost` 报 `FATAL: password authentication failed`，但 `docker exec` 进去却正常
- **根因**：pgvector 镜像的 `pg_hba.conf` 最后一行 `host all all all scram-sha-256`，**对所有外部 TCP 连接强制密码认证**。容器内走 Unix socket 是 `local all all trust` 所以免密
- **解法**：确保密码正确 + 设 `.pgpass` 免输入（见坑11）

### 🔴 坑10：没有默认 postgres 超级用户（2026-06-22 实测）
- **现象**：`docker exec psql -U postgres` → `role "postgres" does not exist`
- **根因**：容器创建时指定了 `POSTGRES_USER=kirito`，那就**不会创建默认的 postgres 用户**。kirito 就是唯一超级用户
- **锚点**：这个容器里 `kirito` = 超级用户 = 你唯一的 admin 账号

### 🟢 坑11：免密码连接（.pgpass）（2026-06-22 实测）
```bash
# 格式：host:port:database:user:password
echo "localhost:5433:kirito:kirito:你的密码" > ~/.pgpass
chmod 0600 ~/.pgpass

# 之后直接连，无需 -W 无需输密码
psql -h localhost -p 5433 -U kirito -d kirito
```
> ⚠️ `.pgpass` 权限必须是 600，否则 psql 会忽略它（安全机制）

### 🟢 坑12：宿主机没装 psql 客户端
```bash
# Ubuntu/Debian
sudo apt install -y postgresql-client

# 验证
which psql
```

---

## 七、健康检查（2026-06-22 验证全部通过 ✅）

```sql
-- 1. 版本
SELECT version();
-- → PostgreSQL 17.10

-- 2. pgvector
SELECT extversion FROM pg_extension WHERE extname='vector';
-- → 0.8.3

-- 3. 向量操作
CREATE TABLE _test (id serial, emb vector(3));
INSERT INTO _test (emb) VALUES ('[1,2,3]'), ('[10,20,30]');
SELECT id, emb <-> '[1,2,3]' AS dist FROM _test ORDER BY dist;
-- → 0, 33.67
DROP TABLE _test;

-- 4. 数据库大小
SELECT pg_size_pretty(pg_database_size('kirito'));
-- → 7734 kB
```

---

## 八、快速恢复检查清单

```bash
# 1. 拉镜像
docker pull pgvector/pgvector:pg17

# 2. 确认数据卷
docker volume ls | grep pgdata-hermes

# 3. 重建容器（保留数据卷）
docker run -d --name postgres-hermes \
  -p 5433:5432 \
  -e POSTGRES_USER=kirito \
  -e POSTGRES_PASSWORD=*** \
  -e POSTGRES_DB=kirito \
  -v pgdata-hermes:/var/lib/postgresql/data \
  --restart=unless-stopped \
  pgvector/pgvector:pg17

# 4. 测试连接
psql -h localhost -p 5433 -U kirito -d kirito

# 5. 验证
\l              # 数据库列表
\dt             # 表列表
SELECT extversion FROM pg_extension WHERE extname='vector';

# 6. 设免密码
echo "localhost:5433:kirito:kirito:你的密码" > ~/.pgpass
chmod 0600 ~/.pgpass
```

---

## 九、PG 17 新特性（相对于 PG 15）

| 特性 | 说明 |
|------|------|
| **增量备份** | `pg_basebackup --incremental`，只备份变更 |
| **JSON_TABLE** | SQL/JSON 语法，把 JSON 直接转成关系表 |
| **MERGE 增强** | 支持 RETURNING 子句和视图 |
| **并行 BRIN 索引** | 大表范围索引更快 |
| **vacuum 优化** | 减少死元组，节省存储 |
| **I/O 统计** | `pg_stat_io` 视图，分析磁盘瓶颈 |

---

*Hermes 整理 · 2026-06-22 · 最后验证：全部通过 ✅*