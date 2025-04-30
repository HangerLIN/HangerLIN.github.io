#!/bin/bash
# 部署到 GitHub Pages 脚本
# 错误时终止脚本
set -e

echo "===== 开始部署 Hugo 博客 ====="

# 切换到博客目录
cd /Users/lth/Hanger_Blog
echo "✓ 已切换到博客目录"

# 删除现有的打包文件夹
if [ -d "public" ] || [ -d "docs" ]; then
  rm -rf public docs
  echo "✓ 已清理旧的构建文件"
fi

# 使用指定主题打包到 docs 文件夹
echo "⏳ 正在构建站点..."
hugo -t LoveIt -d docs
echo "✓ 站点构建完成"

# 提交更改到 Git
echo "⏳ 提交更改到 Git..."
git add -A
msg="更新站点 $(date '+%Y-%m-%d %H:%M:%S')"
if [ $# -eq 1 ]; then
  msg="$1"
fi
git commit -m "$msg"
echo "✓ Git 提交完成: '$msg'"

# 推送到 GitHub 的 main 分支
echo "⏳ 正在推送到 GitHub..."
git push -f https://github.com/HangerLIN/HangerLIN.github.io.git main

echo "✅ 部署完成! 网站已成功更新"
echo "   可以访问: https://hangerlin.github.io/"
