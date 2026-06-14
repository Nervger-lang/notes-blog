# MkDocs Posts 页面相对路径踩坑记录

## 事件时间线

```
16:10  用户反馈：posts 页面点击文章全部 404
16:12  定位：generate-posts-json.sh 生成裸相对路径
16:14  ✅ 修复：URL 加 ../ 前缀
16:18  ✅ CDP 验证通过
```

## 症状

https://nervger-lang.github.io/notes-blog/posts/ 页面文章列表可以加载，但点击任意文章链接都跳转到 404：
- 目标 URL：`/notes-blog/posts/CDP工作原理/`（不存在）
- 实际文章在：`/notes-blog/CDP工作原理/`

右侧 MkDocs 原生导航栏点击正常，只有 posts 页面 JS 动态渲染的链接有问题。

## 根因

`generate-posts-json.sh` 生成的 URL 是**裸相对路径**：

```bash
# 第 23 行 — 旧代码
url="${f%.md}/"    # → "CDP工作原理/"
```

posts 页面本身在 `/notes-blog/posts/` 子目录下，浏览器把裸相对路径解析为相对于当前目录：
```
当前页: /notes-blog/posts/
链接:   CDP工作原理/
解析为: /notes-blog/posts/CDP工作原理/   ← 404！
```

而 MkDocs 原生导航栏用的是正确的路径（`/notes-blog/CDP工作原理/`），所以一直没问题。

## 修复

```bash
# generate-posts-json.sh 第 23 行 — 修复后
url="../${f%.md}/"  # → "../CDP工作原理/"
```

`../` 从 posts 子目录跳回父级，浏览器解析：
```
当前页: /notes-blog/posts/
链接:   ../CDP工作原理/
解析为: /notes-blog/CDP工作原理/   ✅
```

## 为什么之前没发现

1. `generate-posts-json.sh` 最初是在本地直接验证的，本地 MkDocs serve 时所有页面平铺在根目录，裸相对路径恰好能工作
2. 生产环境 posts 页面在子目录下，才会暴露这个问题
3. GitHub Pages CDN 缓存了旧版 HTML，导致第一次修复后验证时看到的是旧链接，需要清除缓存

## 教训

- 相对路径要时刻注意**当前页面所在目录层级**
- 用 `../` 永远比裸相对路径安全（即使页面搬到更深目录也不怕）
- CDN 缓存会掩盖修复效果，验证时记得清缓存
