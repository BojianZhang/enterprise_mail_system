#!/bin/bash

# 企业邮件系统 - 开发环境启动脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 启动企业邮件系统开发环境${NC}"

# 检查Node.js和npm
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 未安装${NC}"
        exit 1
    fi
}

echo -e "${YELLOW}📋 检查依赖...${NC}"
check_dependency "node"
check_dependency "npm"

# 检查MySQL连接（可选）
if command -v mysql &> /dev/null; then
    echo -e "${GREEN}✅ MySQL 已安装${NC}"
else
    echo -e "${YELLOW}⚠️  MySQL 未安装，请确保数据库可用${NC}"
fi

# 安装依赖
install_deps() {
    local dir=$1
    local name=$2
    
    if [ -d "$dir" ]; then
        echo -e "${YELLOW}📦 安装 $name 依赖...${NC}"
        cd "$dir"
        
        if [ ! -d "node_modules" ]; then
            npm install
        else
            echo -e "${GREEN}✅ $name 依赖已安装${NC}"
        fi
        
        cd ..
    else
        echo -e "${RED}❌ $dir 目录不存在${NC}"
        exit 1
    fi
}

# 安装后端依赖
install_deps "backend" "后端"

# 安装前端依赖
install_deps "frontend" "前端"

# 检查环境变量文件
check_env_file() {
    local dir=$1
    local name=$2
    
    if [ -d "$dir" ]; then
        cd "$dir"
        if [ ! -f ".env" ]; then
            if [ -f ".env.example" ]; then
                cp .env.example .env
                echo -e "${YELLOW}⚠️  已创建 $name/.env 文件，请配置相关参数${NC}"
            else
                echo -e "${YELLOW}⚠️  $name 缺少 .env 文件${NC}"
            fi
        else
            echo -e "${GREEN}✅ $name .env 文件已存在${NC}"
        fi
        cd ..
    fi
}

echo -e "${YELLOW}⚙️  检查配置文件...${NC}"
check_env_file "backend" "后端"
check_env_file "frontend" "前端"

# 创建必要目录
echo -e "${YELLOW}📁 创建必要目录...${NC}"
mkdir -p backend/uploads
mkdir -p logs

# 检查数据库连接
check_database() {
    if [ -f "backend/.env" ]; then
        # 从.env文件读取数据库配置
        source backend/.env 2>/dev/null || true
        
        if [ ! -z "$DB_HOST" ] && [ ! -z "$DB_USER" ] && [ ! -z "$DB_NAME" ]; then
            echo -e "${YELLOW}🗄️  检查数据库连接...${NC}"
            if command -v mysql &> /dev/null; then
                if mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" -e "USE $DB_NAME;" 2>/dev/null; then
                    echo -e "${GREEN}✅ 数据库连接正常${NC}"
                else
                    echo -e "${YELLOW}⚠️  数据库连接失败，请检查配置${NC}"
                fi
            fi
        fi
    fi
}

check_database

# 构建后端
echo -e "${YELLOW}🔨 构建后端...${NC}"
cd backend
if npm run build; then
    echo -e "${GREEN}✅ 后端构建成功${NC}"
else
    echo -e "${RED}❌ 后端构建失败${NC}"
    exit 1
fi
cd ..

echo -e "${GREEN}🎉 开发环境准备完成！${NC}"
echo
echo -e "${YELLOW}📋 启动说明：${NC}"
echo "1. 后端服务 (终端1):"
echo "   cd backend && npm run dev"
echo
echo "2. 前端服务 (终端2):"
echo "   cd frontend && npm start"
echo
echo -e "${YELLOW}🌐 访问地址：${NC}"
echo "- 前端: http://localhost:3001"
echo "- 后端: http://localhost:3000/api/health"
echo
echo -e "${YELLOW}📚 更多信息：${NC}"
echo "- 安装指南: INSTALL.md"
echo "- API文档: API_DOCS.md"
echo "- 邮件配置: MAIL_SERVER_SETUP.md"

# 询问是否自动启动服务
read -p "是否现在启动开发服务？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🚀 启动服务...${NC}"
    
    # 使用tmux或screen启动服务（如果可用）
    if command -v tmux &> /dev/null; then
        echo "使用tmux启动服务..."
        tmux new-session -d -s enterprise-mail-backend 'cd backend && npm run dev'
        tmux new-session -d -s enterprise-mail-frontend 'cd frontend && npm start'
        echo -e "${GREEN}✅ 服务已在tmux会话中启动${NC}"
        echo "查看后端日志: tmux attach -t enterprise-mail-backend"
        echo "查看前端日志: tmux attach -t enterprise-mail-frontend"
    elif command -v screen &> /dev/null; then
        echo "使用screen启动服务..."
        screen -dmS enterprise-mail-backend bash -c 'cd backend && npm run dev'
        screen -dmS enterprise-mail-frontend bash -c 'cd frontend && npm start'
        echo -e "${GREEN}✅ 服务已在screen会话中启动${NC}"
        echo "查看后端日志: screen -r enterprise-mail-backend"
        echo "查看前端日志: screen -r enterprise-mail-frontend"
    else
        echo -e "${YELLOW}请在两个终端中分别运行：${NC}"
        echo "终端1: cd backend && npm run dev"
        echo "终端2: cd frontend && npm start"
    fi
else
    echo -e "${GREEN}✅ 准备完成，请手动启动服务${NC}"
fi