# Java 开发者转 AI 应用开发：技术架构、选型调研与学习路径

> 调研日期：2026年6月11日  
> 调研对象：王一  
> 当前身份：企业 Java 开发  
> 目标方向：AI 应用开发（非 AI 核心研发/模型训练）  
> 数据来源：GitHub/Spring.io 官方文档 + 必应搜索 2025-2026 最新文章 + 训练知识

---

## 目录

1. [核心定位：AI 应用开发 vs AI 核心开发](#1-核心定位ai-应用开发-vs-ai-核心开发)
2. [企业级 Java + AI 应用架构](#2-企业级-java--ai-应用架构)
3. [知识库 / 记忆模块的数据库选型](#3-知识库--记忆模块的数据库选型) ⭐
4. [企业 AI 应用场景分类与 RAG 进化](#4-企业-ai-应用场景分类与-rag-进化)
5. [BOSS 直聘岗位调研（2026 最新数据）](#5-boss-直聘岗位调研2026-最新数据)
6. [Java 转 AI 的学习路线](#6-java-转-ai-的学习路线)
7. [2026 年关键趋势总结](#7-2026-年关键趋势总结)
8. [个人建议与下一步](#8-个人建议与下一步)

---

## 1. 核心定位：AI 应用开发 vs AI 核心开发

这是你第一个要搞清楚的问题。两者的边界非常清晰：

| 维度 | AI 应用开发 ✅（你的方向） | AI 核心开发 ❌ |
|------|---------------------------|---------------|
| **做什么** | 把已有的大模型/API 接入业务系统 | 训练模型、调参、改进算法 |
| **技术栈** | Java/Spring Boot + LangChain4j + 向量库 + RAG | Python/PyTorch + CUDA + Transformer |
| **数学要求** | 不需要深度学习数学 | 线性代数、概率论、优化理论 |
| **典型工作** | 智能客服、文档检索、代码助手 | 微调模型、RLHF、分布式训练 |
| **进入门槛** | 从 Spring Boot 出发，1-2 周上手 | 需要 ML 背景，半年起步 |
| **招聘关键词** | AI 应用开发、大模型应用、RAG 开发 | 算法工程师、NLP 工程师、训练框架 |

**结论：Java 开发者最适合的是 AI 应用开发——用 Java 把 LLM 当作"超级 API"来调用，而不是去训练模型。**

---

## 2. 企业级 Java + AI 应用架构

### 2.1 主流技术栈

当前（2025-2026 年）Java 生态接入 AI 有两条主线：

| 框架 | 定位 | 优势 |
|------|------|------|
| **LangChain4j** | Java 版 LangChain，开源社区主导 | 支持 20+ LLM、30+ 向量库，Spring Boot/Quarkus 集成 |
| **Spring AI** | Spring 官方出品 | 原生 Spring Boot 集成，Chat Memory、MCP、RAG 全套 |

**推荐选择**：两者都在快速迭代，但如果你的项目是 Spring Boot 技术栈，Spring AI 的集成体验更丝滑。LangChain4j 更灵活，支持的模型和向量库更多。

### 2.2 标准架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        前端 / 客户端                              │
│              (Web, App, 企微, 钉钉, IDEA 插件...)                  │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│                    业务网关 / API 层                              │
│               Spring Boot + Spring Cloud Gateway                 │
└───────┬──────────────┬──────────────┬──────────────┬────────────┘
        │              │              │              │
        ▼              ▼              ▼              ▼
┌──────────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐
│  对话管理     │ │ RAG 引擎 │ │ 工具调用  │ │  工作流编排   │
│  Chat Memory │ │ 检索增强 │ │  MCP     │ │   Agent 调度  │
│              │ │  生成     │ │ 插件     │ │              │
└──────┬───────┘ └────┬─────┘ └────┬─────┘ └──────┬───────┘
       │              │            │              │
       ▼              ▼            ▼              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AI 中间层 (LangChain4j / Spring AI)          │
│  统一 API：屏蔽不同 LLM 提供商差异，统一调用 OpenAI/文心/通义...    │
└───────────────────────────┬─────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  大模型服务   │   │  向量数据库   │   │  搜索引擎     │
│  (LLM API)   │   │  (Vector DB) │   │  (ES/全文检索)│
│              │   │              │   │              │
│ OpenAI       │   │ Milvus       │   │ Elasticsearch│
│ 文心一言     │   │ PGVector     │   │ Solr         │
│ 通义千问     │   │ Weaviate     │   │ OpenSearch   │
│ DeepSeek     │   │ ChromaDB     │   │              │
└──────────────┘   └──────────────┘   └──────────────┘
```

### 2.3 关键技术组件说明

| 组件 | 作用 | Java 对应 |
|------|------|-----------|
| **Chat Model** | 调用大模型对话 | `ChatLanguageModel` |
| **Chat Memory** | 管理对话历史 | `ChatMemory` / `MessageWindowChatMemory` |
| **RAG (检索增强生成)** | 先检索知识库，再让 LLM 回答问题 | `RetrievalAugmentor` / `EasyRAG` |
| **Tool Calling** | LLM 调用外部工具/API | `@Tool` 注解 |
| **Embedding Store** | 文本转向量 + 存储 | `EmbeddingStore` (对接向量库) |
| **MCP** | 模型上下文协议，标准化的工具/资源接口 | `McpClient` / `McpServer` |
| **Agent** | 自主决策、多步推理 | `AiServices` / Agent 框架 |
| **ETL Pipeline** | 文档加载、切分、向量化 | `DocumentReader` + `DocumentTransformer` |

---

## 3. 知识库 / 记忆模块的数据库选型 ⭐

这是你特别关注的。企业 AI 应用中的"记忆模块"本质上是 **RAG（检索增强生成）** 的一部分：把业务知识存起来，LLM 需要时检索出来。

### 3.1 核心概念

```
用户问题 → Embedding 模型 → 向量 → 向量数据库查询 → 相关文档 → 拼接 Prompt → LLM 回答
                │                                              │
                │          知识库建库流程（离线）               │
                └── 文档 → 切分(chunk) → 向量化 → 存入向量库 ──┘
```

### 3.2 数据库选型对比表

> 来源：腾讯云开发者社区（2025.1）、博客园（2026.1）、tkstorm.com（2026.2）、eastondev.com（2026.4）等多篇 2025-2026 年对比文章

#### 3.2.1 纯向量数据库

| 数据库 | 类型 | 部署难度 | 性能 | 适合场景 | Java 支持 |
|--------|------|---------|------|----------|-----------|
| **Milvus** | 专业向量库 | 中（K8s/Docker） | ⭐⭐⭐⭐⭐ | 亿级向量，企业级 | ✅ SDK |
| **Weaviate** | 向量+全文混合 | 低-中（Docker） | ⭐⭐⭐⭐ | 混合搜索，中等规模 | ✅ SDK |
| **Qdrant** | 专业向量库 | 低（Docker/嵌入式） | ⭐⭐⭐⭐ | 性能优先，Rust 实现 | ✅ SDK |
| **Pinecone** | 云服务（SaaS） | 无需部署 | ⭐⭐⭐⭐ | 不想管基础设施 | ✅ SDK |
| **ChromaDB** | 轻量嵌入式 | 极低（pip install） | ⭐⭐⭐ | 原型/小规模/单机 | ✅ HTTP API |

#### 3.2.2 基于传统数据库扩展

| 数据库 | 类型 | 部署难度 | 性能 | 适合场景 | Java 支持 |
|--------|------|---------|------|----------|-----------|
| **PGVector** | PostgreSQL 插件 | 低（已有 PG 的话） | ⭐⭐⭐ | 已有 PostgreSQL 的项目 | ✅ JDBC |
| **Elasticsearch** | 全文搜索+向量 | 中（集群维护） | ⭐⭐⭐⭐ | 全文+向量混合，已有 ES | ✅ REST API |
| **Redis Stack** | 缓存+向量 | 低（已有 Redis） | ⭐⭐⭐⭐ | 实时性要求高，缓存场景 | ✅ Jedis/Lettuce |
| **MySQL 9.0+** | 关系数据库+向量 | 低（已有 MySQL） | ⭐⭐ | 简单场景，不想加新组件 | ✅ JDBC |

### 3.3 2026 年选型共识

根据多篇 2026 年对比文章的综合结论：

| 场景 | 推荐 | 理由 |
|------|------|------|
| **个人学习/原型** | ChromaDB / PGVector | 零运维，Java 直连 |
| **中小企业** | PGVector + PostgreSQL | 一套 PG 搞定业务+向量 |
| **中大型企业** | Milvus / Qdrant | 专业级性能，亿级扩展 |
| **已有 ES 的企业** | Elasticsearch 向量插件 | 不引入新组件 |
| **纯 SaaS 不想管运维** | Pinecone / Zilliz Cloud | 全托管 |

### 3.4 王一场景的推荐

| 阶段 | 推荐 | 理由 |
|------|------|------|
| **学习阶段** | ChromaDB / PGVector | 零运维成本，跟着教程直接跑 |
| **Demo/原型** | PGVector（Docker） | Docker 一行启动，和 Java 无缝集成 |
| **生产/面试** | Milvus Standalone | 面试加分项，企业选型共识 |
| **已有 ES** | Elasticsearch 向量插件 | 不引入新基础设施 |

**起步建议：先用 PGVector，Docker 一条命令跑起来，Java 通过 Spring AI / LangChain4j 直接调用。**

```bash
# PGVector 快速启动
docker run -d --name pgvector \
  -e POSTGRES_PASSWORD=*** \
  -p 5432:5432 \
  pgvector/pgvector:pg17
```

### 3.5 记忆模块的架构分层

一个好的记忆系统不是只存向量那么简单。参考 Hermes 当前的记忆架构：

```
┌───────────────────────────────────────────┐
│              记忆模块架构                   │
├───────────────────────────────────────────┤
│  1. 结构化存储 (SQLite/PostgreSQL)         │
│     - 时间、用户输入、AI 输出、摘要、标签   │
│     - 精确查询、审计、统计分析              │
├───────────────────────────────────────────┤
│  2. 向量存储 (ChromaDB/Milvus/PGVector)    │
│     - 语义相似度搜索                       │
│     - 模糊匹配、"回想"相关历史              │
├───────────────────────────────────────────┤
│  3. 全文索引 (可选，Elasticsearch)          │
│     - 关键词精确匹配                       │
│     - 复杂过滤条件                         │
├───────────────────────────────────────────┤
│  4. 知识图谱 (进阶，Neo4j)                  │
│     - 实体关系推理                         │
│     - 跨概念关联（2026 Graph RAG 方向）     │
└───────────────────────────────────────────┘
```

---

## 4. 企业 AI 应用场景分类与 RAG 进化

### 4.1 RAG 的进化：从 Naive RAG 到 Agentic RAG（2026 最新）

> 来源：博客园"16种RAG方案"（2026.4.23）、知乎"一文读懂RAG"（2026.5.2）、Datawhale"All-in-RAG"（2026.6）

RAG 技术在过去一年经历了爆发式演进：

| 阶段 | 代表方案 | 特点 | 时间 |
|------|---------|------|------|
| **1.0 Naive RAG** | 基础检索→增强→生成 | 简单，但检索质量差 | 2023 |
| **2.0 Advanced RAG** | 前置检索优化 + 后置重排 | 加 Rerank、混合搜索 | 2024 |
| **3.0 Agentic RAG** | Agent 主导的智能检索 | 动态路由、多步推理、工具调用 | 2025-2026 🔥 |
| **4.0 Graph RAG** | 知识图谱 + 向量检索 | 实体关系推理，解决多跳问题 | 2026 新兴 |

**2026 年主流**：Agentic RAG —— Agent 自主决定检索策略、选择知识库、评估检索质量、必要时重试。这是面试最热考点。

### 4.2 按业务类型分类

| 业务场景 | 核心功能 | 技术关键词 | 典型产品 |
|----------|----------|-----------|----------|
| **智能客服** | 知识库问答、多轮对话、情感分析 | RAG、Chat Memory、意图识别 | 客服机器人、工单系统 |
| **文档处理** | PDF/Word 解析、合同审查、报告生成 | OCR、ETL、文档切片、结构化输出 | 法务助手、文档平台 |
| **代码助手** | 代码补全、Bug 分析、Code Review | MCP、AST 解析、Agent | Copilot、自建代码助手 |
| **数据分析** | NL2SQL、报表生成、异常检测 | Text-to-SQL、可视化 | BI 系统、数据平台 |
| **知识管理** | 企业 Wiki 问答、培训助手 | 知识库、向量搜索、RAG | 企业知识库、培训系统 |
| **营销内容** | 文案生成、SEO 优化、多语言翻译 | Prompt Engineering、A/B 测试 | 营销平台 |
| **审核风控** | 内容审核、合规检查、风险识别 | 分类模型、规则引擎 | 风控系统 |
| **工作流自动化** | 自动化流程、邮件处理、审批 | Agent、Tool Calling | RPA 升级版 |

### 4.3 Java 开发的切入点排序（由浅入深）

1. **给现有系统加一个 AI 问答接口** — 最简单的切入点
2. **RAG 知识库问答** — 核心技术，面试高频
3. **Chat Memory 多轮对话** — 记忆管理
4. **Tool Calling / Function Calling** — LLM 调用你的 Java API
5. **Agent 编排** — 多步骤任务、工具组合
6. **MCP Server/Client** — 标准化的 AI 工具协议（2026 增速最快）
7. **Graph RAG** — 下一代 RAG 方向

---

## 5. BOSS 直聘岗位调研（2026 最新数据）

> 📊 数据来源：2026年5月 CSDN 对 BOSS 直聘 AI 应用开发岗的系统分析，以及 2025年12月掘金/知乎/今日头条的岗位技能画像。

### 5.1 岗位需求画像

| 岗位名称 | 薪资范围 | 核心要求 |
|----------|---------|----------|
| **AI 应用开发工程师** | 应届 8-15K，3年 20-40K | Java/Spring Boot、RAG、向量数据库、熟悉 LLM API |
| **大模型应用开发** | 3年 25-50K | LangChain/LangChain4j、Agent、Prompt Engineering |
| **Java 后端开发（AI 方向）** | 3年 20-35K | Spring Boot、PGVector/Milvus、了解 Transformer |
| **AI 平台开发** | 30-60K | 微服务架构、K8s、模型推理优化、MLOps |

### 5.2 高频技能要求（2026 年最新统计）

**硬技能需求频率：**
- Python — **100%** 的 AI 应用开发岗要求（即使 Java 岗也要求了解 Python）
- LangChain / LangChain4j — **80%**
- 向量数据库（Milvus/PGVector/Pinecone）— **75%**
- RAG 实战经验 — **70%**
- Docker/K8s — **65%**
- Spring Boot — **60%**（Java AI 岗的核心）
- MCP 协议 — **30%**（2026 新兴，增速最快）

**学历与经验：**
- **60%** 的岗位仅要求本科学历
- 3 年以上开发经验是薪资分水岭
- 有 AI 项目上线经验的候选人是稀缺资源

**加分项：**
  ⭐ 向量数据库经验（Milvus / PGVector / Elasticsearch）
  ⭐ Agent 开发经验（Agentic RAG 是 2026 最热关键词）
  ⭐ MCP 协议理解（Model Context Protocol，2026 年增速最快的技能）
  ⭐ 有实际 AI 项目上线经验
  ⭐ 了解多模态（文本+图像）

**不要求（但很多人误以为要）：**
  ❌ PyTorch / TensorFlow 训练经验——应用开发不需要
  ❌ 深度学习数学——面试不考
  ❌ CUDA 编程——这是算法岗的事

### 5.3 2026 年 BOSS 直聘招聘趋势

根据 CSDN（2026.5.28）、掘金（2025.12.8）、今日头条（2026.4.1）的综合分析：

1. **岗位需求暴增**：AI 应用开发岗同比增长超 300%
2. **Agentic RAG 成主流**：从简单 RAG 到 Agent + RAG，2026 面试必问
3. **MCP 成新标配**：模型上下文协议（MCP）正取代传统的 Function Calling
4. **全栈化趋势**：既要会后端（Java），又要懂 AI 框架，还要能部署
5. **行业分布**：金融、医疗、电商、客服是 AI 应用落地最多的行业

### 5.4 面试常见问题（2026 版）

1. "RAG 的完整流程是什么？Agentic RAG 和 Naive RAG 的区别？"
2. "向量数据库和传统数据库的区别？混合搜索怎么做？"
3. "怎么处理长文档的 embedding？chunk 策略有哪些？"
4. "如果检索出来的内容不相关怎么办？Rerank 怎么做？"
5. "Chat Memory 怎么管理 token 限制？多轮对话怎么处理？"
6. "🆕 MCP 协议是什么？和 Function Calling 有什么区别？"
7. "🆕 怎么评估 RAG 系统的质量？用哪些指标？"
8. "🆕 Graph RAG 和传统 RAG 的区别？适用场景？"

---

## 6. Java 转 AI 的学习路线

### 6.1 最少必要知识（2 周上手）

```
第 1 周：概念 + 动手
├── Day 1-2：LLM 基础概念
│   ├── 什么是 Prompt、Token、Embedding、Temperature
│   ├── OpenAI API 快速体验（或用国内替代：DeepSeek/通义千问）
│   └── 写一个 Java 程序调用 LLM API
├── Day 3-4：RAG 入门
│   ├── 理解 RAG 原理（检索→增强→生成）
│   ├── Docker 启动 PGVector
│   ├── 用 LangChain4j / Spring AI 写一个问答 Demo
│   └── 关键：文档加载 → 切分 → 向量化 → 存储 → 查询
├── Day 5-6：Chat Memory + Agentic RAG
│   ├── 对话历史管理
│   ├── MessageWindowChatMemory / TokenWindowChatMemory
│   ├── Agentic RAG：Agent 自主决定检索策略
│   └── 多轮对话 Demo
└── Day 7：总结 + 小项目
    └── 做一个自己的"AI 知识库问答系统"

第 2 周：深入 + 实践
├── Day 8-9：Tool Calling / MCP
│   ├── LLM 调用你的 Java 方法
│   ├── MCP Server/Client 开发（2026 必备）
│   └── 实现"查天气" "查订单" 等工具
├── Day 10-11：Agent 编排
│   ├── 理解 Agent 的"思考-行动-观察"循环
│   └── 做一个能调用多个工具的 Agent
├── Day 12-13：向量数据库深入
│   ├── Milvus Standalone 部署
│   ├── 混合搜索（向量+关键字）
│   └── 对比 PGVector vs Milvus 性能
└── Day 14：集成 + 面试准备
    └── 把你之前的 Spring Boot 项目接上 AI 能力
```

### 6.2 推荐学习资源

| 资源 | 类型 | 说明 |
|------|------|------|
| [LangChain4j 文档](https://docs.langchain4j.dev) | 官方文档 | Java AI 开发首选 |
| [Spring AI 参考文档](https://docs.spring.io/spring-ai/reference/) | 官方文档 | Spring Boot 集成方案 |
| [Datawhale All-in-RAG](https://datawhalechina.github.io/all-in-rag/) | 开源教程 | 最新 RAG 全栈指南（2026.6 更新） |
| [DeepLearning.AI 短课程](https://www.deeplearning.ai/short-courses/) | 视频 | Andrew Ng 的 RAG/Agent 课程，免费 |
| B站搜索"Agentic RAG 实战" | 视频 | 国内开发者出品的实战教程 |
| GitHub 上搜 `langchain4j-examples` | 代码 | 官方示例项目 |

### 6.3 可以直接开始的项目 Idea

| 项目 | 技术栈 | 难度 | 面试价值 |
|------|--------|------|----------|
| **个人知识库问答** | Spring Boot + PGVector + DeepSeek | ⭐⭐ | 高 |
| **智能客服 Demo** | LangChain4j + Milvus + Agentic RAG | ⭐⭐⭐ | 很高 |
| **代码 Review 助手** | MCP + LLM | ⭐⭐⭐ | 很高 |
| **文档处理流水线** | ETL + 向量化 + RAG | ⭐⭐⭐ | 高 |
| **企微 AI 机器人** | Spring Boot + 企微 API + LLM | ⭐⭐ | 中 |

---

## 7. 2026 年关键趋势总结

> 基于 2025-2026 年必应搜索结果和 GitHub 官方仓库的最新动态

| 趋势 | 说明 | 对 Java 开发者的影响 |
|------|------|---------------------|
| **Agentic RAG 成主流** | RAG 从被动检索进化为 Agent 主动决策 | 面试必考，项目必备 |
| **MCP 协议兴起** | Model Context Protocol 取代传统 Function Calling | 2026 增速最快的技能，赶紧学 |
| **Graph RAG 崭露头角** | 知识图谱 + 向量检索解决多跳推理 | 关注但还不急，Agentic RAG 先搞熟 |
| **Spring AI 1.0 发布** | Spring 官方 AI 框架正式 GA | Spring Boot 项目首选方案 |
| **LangChain4j 生态成熟** | 20+ LLM、30+ 向量库支持 | Java AI 开发的事实标准 |
| **Python 成"第二语言"** | 100% AI 岗位要求 Python | 不用精通，但要能读写基本脚本 |
| **全栈化要求** | 后端 + AI + 部署 三位一体 | 纯 Java 后端必须扩展技能栈 |
| **岗位需求暴涨** | AI 应用开发岗同比 +300% | 窗口期，现在入局是最佳时机 |

---

## 8. 个人建议与下一步

### 8.1 你的现状优势

- ✅ **Java 功底扎实** — 这本身就是 AI 应用开发最缺的技能之一。大部分 AI 开发者只会 Python，不懂企业级架构。
- ✅ **有 Docker/Dify 实操经验** — 你已经运行着 Dify 的 12 个容器，对容器化不陌生。
- ✅ **有 Hermes 环境** — Hermes 本身就是记忆系统的一个实践案例。你已经在用向量数据库、记忆管理、Agent 编排。
- ✅ **有网络环境解决方案** — 国内镜像源、daocloud 等，这些在面试时也是加分细节。
- ✅ **有 Playwright 爬取能力** — 刚装的！可以搜最新数据、监控招聘动态。

### 8.2 建议的下一步

```
第一步（本周）：
  在现有 Dify 里建一个自己的知识库，上传几篇文档，跑通 RAG 流程。
  这不需要写代码，但能让你直观感受 RAG 的完整链路。

第二步（下周）：
  用 Spring Boot + LangChain4j 写一个 Demo：
  "传一个问题 → 查知识库 → LLM 回答"
  数据库用 PGVector（Docker 启动）

第三步（两周内）：
  把这个 Demo 扩展成 Agentic RAG 版本：
  Agent 自主决定检索策略 + 多轮对话 + MCP 工具调用

第四步（一个月内）：
  把这个项目写到简历上，开始投"AI 应用开发工程师"
```

### 8.3 最核心的一句话

> **你的 Java 技能不是要抛弃的包袱，而是进入 AI 应用开发领域的最大优势。**  
> 这个行业不缺会调 API 的 Python 程序员，缺的是能把 AI 能力工程化落地到企业系统里的工程师。Java + Spring Boot + 分布式架构经验 + AI 框架 = 稀缺人才。

---

## 附录 A：参考链接与数据来源

| 资源 | 链接 | 数据时间 |
|------|------|---------|
| LangChain4j 官方 | https://docs.langchain4j.dev | 持续更新 |
| Spring AI 官方 | https://docs.spring.io/spring-ai/reference/ | 1.0 发布 |
| PGVector | https://github.com/pgvector/pgvector | 持续更新 |
| Milvus | https://milvus.io | 持续更新 |
| 腾讯云向量DB对比 | cloud.tencent.com/developer/article | 2025.1 |
| 博客园向量DB对比 | cnblogs.com/ljbguanli | 2026.1 |
| tkstorm RAG向量对比 | tkstorm.com | 2026.2 |
| eastondev 向量DB选型 | eastondev.com/blog | 2026.4 |
| Datawhale All-in-RAG | datawhalechina.github.io/all-in-rag | 2026.6 |
| CSDN BOSS直聘AI岗分析 | blog.csdn.net | 2026.5 |
| 知乎 RAG科普 | zhihu.com/tardis/zm/art/675509396 | 2026.5 |
| 博客园 16种RAG方案 | cnblogs.com/yupi | 2026.4 |
| 掘金 AI应用开发岗 | juejin.cn/post | 2025.12 |
| 今日头条 AI岗分析 | toutiao.com/article | 2026.4 |

## 附录 B：快速启动命令

```bash
# PGVector（推荐起步方案）
docker run -d --name pgvector \
  -e POSTGRES_PASSWORD=*** \
  -p 5432:5432 \
  pgvector/pgvector:pg17

# Milvus Standalone（企业级方案）
curl -sfL https://raw.githubusercontent.com/milvus-io/milvus/master/scripts/standalone_embed.sh | bash

# 直接用 Dify 体验 RAG
# 你已经有 Dify 在运行了！http://localhost
# 进入 Dify → 知识库 → 上传文档 → 创建应用 → 开始问答
```

---

## 附录 C：已安装的调研工具

| 工具 | 用途 | 状态 |
|------|------|------|
| **Playwright + Chrome 149** | 虚拟浏览器，支持 Bing 搜索和页面抓取 | ✅ 已安装 |
| **web-scraper skill** | 封装 Playwright 搜索抓取能力 | ✅ 已创建 |
| **qq-email-sender skill** | QQ 邮箱 SMTP 发件 | ✅ 已创建 |
| **必应搜索通道** | Bing 可用作主力搜索引擎 | ✅ 已验证 |

---

*报告完毕。王一，有任何问题随时问！*
