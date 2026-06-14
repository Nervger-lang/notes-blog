#!/bin/bash
# 在 mkdocs build 前运行，生成文章列表 JSON
cd docs
echo '[' > posts.json
first=true
for f in *.md; do
  [ "$f" = "index.md" ] && continue
  [ "$f" = "最近更新.md" ] && continue
  [ "$f" = "posts.md" ] && continue
  # 获取标题（跳过 frontmatter，找第一个 # 开头的行）
  title=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      "---") continue ;;
      "# "*) title="${line#\# }"; title="${title%¶}"; break ;;
    esac
  done < "$f"
  [ -z "$title" ] && title="${f%.md}"
  # 获取日期
  date=$(git log -1 --format="%as" -- "$f" 2>/dev/null)
  [ -z "$date" ] && date="2026-06-14"
  url="${f%.md}/"
  [ "$first" = true ] && first=false || echo ',' >> posts.json
  echo "  {\"title\": \"$title\", \"date\": \"$date\", \"url\": \"$url\"}" >> posts.json
done
echo ']' >> posts.json
echo "Generated posts.json with $(grep -c '"title"' posts.json) entries"
