#!/bin/bash
# 生成最近更新页面，基于 git log
# 运行前确保在博客仓库根目录

cat > docs/最近更新.md << 'HEADER'
# 最近更新

> 基于 Git 提交历史自动生成，每次推送时更新。

| 日期 | 更新内容 |
|------|---------|
HEADER

git log --oneline --format="| %ad | %s |" --date=format:'%m-%d %H:%M' -30 >> docs/最近更新.md

echo "" >> docs/最近更新.md
echo "---" >> docs/最近更新.md
echo "*此页面由 GitHub Actions 自动生成，最近 30 条提交。*" >> docs/最近更新.md
echo "生成完成: $(wc -l < docs/最近更新.md) 行"
