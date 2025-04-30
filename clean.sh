#!/bin/bash
# 清理 Hugo 缓存并优化构建
set -e

echo "===== 开始清理 Hugo 缓存 ====="

# 清理缓存文件
if [ -d "resources" ]; then
  echo "⏳ 清理 resources 缓存..."
  rm -rf resources
  echo "✓ resources 缓存已清理"
fi

if [ -d ".hugo_build.lock" ]; then
  echo "⏳ 删除 .hugo_build.lock..."
  rm -f .hugo_build.lock
  echo "✓ 构建锁文件已删除"
fi

# 更新主题
echo "⏳ 更新主题..."
git submodule update --remote --merge
echo "✓ 主题已更新"

echo "✅ 清理完成! 现在可以使用 deploy.sh 重新构建站点" 