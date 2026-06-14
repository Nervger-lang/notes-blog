---
date: 2026-06-14
---

# Hermes 企微语音回复 — 完整解决记录

> 时间：2026.6.10 ~ 2026.6.12  
> 目标：让 Hermes 大管家通过企微给王哥哥发原生语音消息（可爱女声，正常播放 + 正确时长）

---

## 一、最终方案（就两步，中间走内存）

```
Edge TTS → /dev/shm (内存) → ffmpeg → AMR-WB
```

| 环节 | 工具 | 说明 |
|------|------|------|
| 文字→语音 | Edge TTS | `zh-CN-XiaoyiNeural`（可爱女声），免费，国内直连 |
| 音频编码 | ffmpeg + libvo_amrwbenc | 内存盘 `/dev/shm` 过渡，无磁盘 I/O |
| 发送到企微 | MEDIA: 语法 | 在 Hermes 响应中包含 `MEDIA:/tmp/voice.amr` |

> 下面三个阶段是**踩坑记录**——从 AMR-NB 无声到 SILK V3 时长归零，最终才找到 AMR-WB。实际每次执行只跑上面两步。

### 完整流程
```
王哥哥说"语音回复" 
    → Hermes 生成文字回复
    → python3 /home/kirito/.hermes/scripts/tts_amrwb.py "回复内容" /tmp/voice.amr
    → 响应中写 MEDIA:/tmp/voice.amr
    → 企微收到原生语音气泡 ✅
```

---

## 二、踩坑历程

### 阶段 1：标准 AMR-NB 方案 ❌

**尝试**：Edge TTS → ffmpeg libopencore_amrnb 编码 AMR-NB（8kHz）

**结果**：企微显示语音气泡，但**播放无声** + **时长错乱**（6 秒语音显示 55 秒）

**根因**：企微使用 SILK V3 编码，AMR-NB 格式不兼容

---

### 阶段 2：SILK V3 编码 ✅ 播放正常，但时长 0 秒

**尝试**：kn007/silk-v3-decoder 编译 encoder → Edge TTS 生成 MP3 → ffmpeg 转 PCM → SILK V3 编码（`-tencent` 兼容模式）

**流程**：
```bash
# 1. TTS → MP3
edge-tts --voice zh-CN-XiaoyiNeural --text "..." --write-media out.mp3

# 2. MP3 → PCM
ffmpeg -i out.mp3 -f s16le -ar 24000 -ac 1 out.pcm

# 3. PCM → SILK V3
/tmp/silk-v3-decoder/silk/encoder out.pcm out.amr -tencent -Fs_API 24000 -rate 25000
```

**结果**：
- ✅ 企微正常播放，音质好
- ❌ **时长显示 0 秒** ← 本次要解决的问题

**根因分析**：
- SILK V3 bitstream 格式：`\x02#!SILK_V3` + `[2字节帧大小][N字节payload]...`
- 文件中**不含任何时长元数据**
- 企微 API 的 voice 消息只有 `media_id` 参数，无独立 `duration` 字段
- 服务端/客户端无法从纯 SILK 流式计算时长（可变帧大小）

---

### 阶段 3：AMR-WB 方案 ✅ 完美解决

**思路**：AMR-WB（宽带自适应多速率，16kHz）有标准 `#!AMR-WB\n` 文件头 + 规范帧结构，服务端可从帧头计算时长。

**尝试**：
```bash
ffmpeg -i voice.mp3 -ar 16000 -ac 1 -c:a libvo_amrwbenc -b:a 23.85k voice.amr
```

**结果**：
- ✅ 正常播放
- ✅ **时长显示正确**
- ✅ 零额外依赖（纯 ffmpeg）
- ✅ 音质好（16kHz / 50-7000Hz 带宽）

**为什么 AMR-WB 能有正确时长？**
- 标准文件头 `#!AMR-WB\n`（6 字节）
- 每帧有模式指示位，服务端能确定帧类型
- 固定帧率（50 帧/秒），帧数 × 20ms = 时长
- ffprobe 可直接读取时长

---

## 三、方案对比

| 方案 | 编码 | 采样率 | 播放 | 时长 | 音质 | 依赖 |
|------|------|--------|------|------|------|------|
| AMR-NB | libopencore_amrnb | 8kHz | ❌ 无声 | ❌ 错乱 | 低 | ffmpeg |
| SILK V3 | kn007 encoder | 24kHz | ✅ | ❌ 0秒 | 高 | 需编译 SILK SDK |
| **AMR-WB 🏆** | **libvo_amrwbenc** | **16kHz** | **✅** | **✅** | **中高** | **纯 ffmpeg** |

---

## 四、关键文件

| 文件 | 说明 |
|------|------|
| `/home/kirito/.hermes/scripts/tts_amrwb.py` | 🏆 当前方案：Edge TTS → AMR-WB 一键脚本 |
| `/home/kirito/.hermes/scripts/tts_silk.py` | 旧方案（历史参考）：SILK V3 编码 |
| `/home/kirito/.hermes/skills/communication/wecom-voice-reply/SKILL.md` | 技能文档 v4.0 |
| `/tmp/silk-v3-decoder/` | SILK V3 编码器（已编译，备用） |

---

## 五、快速参考

```bash
# 生成语音
python3 /home/kirito/.hermes/scripts/tts_amrwb.py "要说的话" /tmp/voice.amr

# 在 Hermes 响应中发送
MEDIA:/tmp/voice.amr

# 查看时长
ffprobe -v quiet -show_entries format=duration -of csv=p=0 /tmp/voice.amr
```
