#!/bin/bash

# 企业邮件系统快速启动脚本

echo "🚀 启动企业邮件系统..."

# 检查依赖
if ! command -v node &> /dev/null; then
    echo "❌ Node.js 未安装"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm 未安装"
    exit 1
fi

# 安装依赖
echo "📦 安装依赖..."
if [ -d "backend" ]; then
    echo "安装后端依赖..."
    cd backend && npm install && cd ..
fi

if [ -d "frontend" ]; then
    echo "安装前端依赖..."
    cd frontend && npm install && cd ..
fi

# 构建项目
echo "🔨 构建项目..."
if [ -d "backend" ]; then
    echo "构建后端..."
    cd backend && npm run build && cd ..
fi

if [ -d "frontend" ]; then
    echo "构建前端..."
    cd frontend && npm run build && cd ..
fi

# 创建必要目录
mkdir -p backend/uploads
mkdir -p logs

echo "✅ 构建完成!"
echo "📝 后续步骤:"
echo "1. 配置 backend/.env 文件"
echo "2. 设置数据库"
echo "3. 运行 'npm start' 启动服务"