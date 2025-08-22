#!/bin/bash

# 企业邮件系统部署脚本

set -e

echo "🚀 开始部署企业邮件系统..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}请不要使用root用户运行此脚本${NC}"
   exit 1
fi

# 检查必要的命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}错误: $1 未安装${NC}"
        exit 1
    fi
}

echo "📋 检查系统依赖..."
check_command "node"
check_command "npm"
check_command "git"

# 检查Node.js版本
NODE_VERSION=$(node -v | cut -d'v' -f2)
REQUIRED_VERSION="16.0.0"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$NODE_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then 
    echo -e "${RED}错误: 需要 Node.js >= $REQUIRED_VERSION，当前版本: $NODE_VERSION${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Node.js 版本检查通过: $NODE_VERSION${NC}"

# 安装依赖
echo "📦 安装项目依赖..."
if [ -f "package.json" ]; then
    npm run install:all
else
    echo "⚠️ 在根目录未找到 package.json，尝试分别安装..."
    if [ -d "backend" ]; then
        cd backend && npm install && cd ..
    fi
    if [ -d "frontend" ]; then
        cd frontend && npm install && cd ..
    fi
fi

# 构建项目
echo "🔨 构建项目..."
if [ -d "backend" ]; then
    cd backend && npm run build && cd ..
fi
if [ -d "frontend" ]; then
    cd frontend && npm run build && cd ..
fi

echo -e "${GREEN}✅ 项目构建完成${NC}"

# 创建上传目录
mkdir -p backend/uploads
chmod 755 backend/uploads

# 创建日志目录
mkdir -p logs

echo -e "${GREEN}✅ 部署完成!${NC}"
echo
echo "📋 后续步骤:"
echo "1. 配置数据库连接"
echo "2. 设置环境变量"
echo "3. 启动服务"
echo "4. 配置邮件服务器"

exit 0