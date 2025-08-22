#!/bin/bash

# 企业邮件系统 - 生产环境部署脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🚀 企业邮件系统 - 生产环境部署${NC}"
echo "=================================="

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}❌ 请不要使用root用户运行此脚本${NC}"
   exit 1
fi

# 检查系统
echo -e "${BLUE}📋 检查系统环境...${NC}"

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 未安装，请先安装${NC}"
        return 1
    else
        echo -e "${GREEN}✅ $1 已安装${NC}"
        return 0
    fi
}

# 检查必要命令
MISSING_DEPS=0
check_command "node" || MISSING_DEPS=1
check_command "npm" || MISSING_DEPS=1
check_command "mysql" || MISSING_DEPS=1

if [ $MISSING_DEPS -eq 1 ]; then
    echo -e "${RED}❌ 缺少必要依赖，请先安装后再运行此脚本${NC}"
    exit 1
fi

# 检查Node.js版本
NODE_VERSION=$(node -v | sed 's/v//')
REQUIRED_VERSION="16.0.0"
if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$NODE_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then 
    echo -e "${RED}❌ Node.js版本过低，需要 >= $REQUIRED_VERSION，当前: $NODE_VERSION${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Node.js版本检查通过: v$NODE_VERSION${NC}"

# 收集配置信息
echo -e "${BLUE}⚙️  配置系统参数...${NC}"

read -p "请输入MySQL root密码: " -s MYSQL_ROOT_PASSWORD
echo
read -p "请输入要创建的MySQL用户名 [mailuser]: " MYSQL_USER
MYSQL_USER=${MYSQL_USER:-mailuser}
read -p "请输入MySQL用户密码: " -s MYSQL_PASSWORD
echo
read -p "请输入JWT密钥 (留空将自动生成): " JWT_SECRET
if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(openssl rand -hex 32)
    echo "已生成JWT密钥: $JWT_SECRET"
fi
read -p "请输入主域名 [example.com]: " MAIL_DOMAIN
MAIL_DOMAIN=${MAIL_DOMAIN:-example.com}
read -p "请输入管理员邮箱 [admin@$MAIL_DOMAIN]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@$MAIL_DOMAIN}

# 数据库设置
echo -e "${BLUE}🗄️  配置数据库...${NC}"

# 创建数据库和用户
mysql -u root -p$MYSQL_ROOT_PASSWORD << EOF
CREATE DATABASE IF NOT EXISTS enterprise_mail CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON enterprise_mail.* TO '$MYSQL_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 数据库创建成功${NC}"
else
    echo -e "${RED}❌ 数据库创建失败${NC}"
    exit 1
fi

# 导入数据库结构
if [ -f "database/schema.sql" ]; then
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD enterprise_mail < database/schema.sql
    echo -e "${GREEN}✅ 数据库结构导入成功${NC}"
else
    echo -e "${RED}❌ 找不到数据库结构文件${NC}"
    exit 1
fi

# 插入默认域名
mysql -u $MYSQL_USER -p$MYSQL_PASSWORD enterprise_mail << EOF
INSERT IGNORE INTO domains (domain_name, is_active, mx_record) VALUES ('$MAIL_DOMAIN', TRUE, 'mail.$MAIL_DOMAIN');
EOF

# 项目构建
echo -e "${BLUE}🔨 构建项目...${NC}"

# 安装后端依赖
if [ -d "backend" ]; then
    echo "安装后端依赖..."
    cd backend
    npm ci --only=production
    echo "构建后端..."
    npm run build
    cd ..
    echo -e "${GREEN}✅ 后端构建完成${NC}"
fi

# 安装前端依赖
if [ -d "frontend" ]; then
    echo "安装前端依赖..."
    cd frontend
    npm ci
    echo "构建前端..."
    npm run build
    cd ..
    echo -e "${GREEN}✅ 前端构建完成${NC}"
fi

# 配置环境变量
echo -e "${BLUE}⚙️  配置环境变量...${NC}"

# 后端配置
cat > backend/.env << EOF
# 数据库配置
DB_HOST=localhost
DB_PORT=3306
DB_USER=$MYSQL_USER
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=enterprise_mail

# JWT配置
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=24h

# 服务器配置
PORT=3000
NODE_ENV=production

# 邮件服务器配置
SMTP_HOST=localhost
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=
SMTP_PASS=

IMAP_HOST=localhost
IMAP_PORT=993
IMAP_SECURE=true

# 邮件同步配置
ENABLE_EMAIL_SYNC=true
EMAIL_SYNC_INTERVAL=60000

# 文件上传配置
UPLOAD_PATH=./uploads
MAX_FILE_SIZE=26214400

# 系统配置
DEFAULT_STORAGE_QUOTA=1073741824
ADMIN_EMAIL=$ADMIN_EMAIL

# 前端URL
FRONTEND_URL=https://$MAIL_DOMAIN
EOF

# 前端配置
cat > frontend/.env.production << EOF
REACT_APP_API_URL=https://$MAIL_DOMAIN/api
EOF

# 创建必要目录
echo -e "${BLUE}📁 创建目录结构...${NC}"
mkdir -p backend/uploads
mkdir -p logs
sudo mkdir -p /var/log/enterprise-mail
sudo chown $USER:$USER /var/log/enterprise-mail

# 设置文件权限
chmod 755 backend/uploads
chmod 755 logs

# 安装PM2
if ! command -v pm2 &> /dev/null; then
    echo -e "${BLUE}📦 安装PM2进程管理器...${NC}"
    sudo npm install -g pm2
fi

# 创建PM2配置
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'enterprise-mail-api',
    cwd: './backend',
    script: 'dist/index.js',
    instances: 'max',
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/var/log/enterprise-mail/err.log',
    out_file: '/var/log/enterprise-mail/out.log',
    log_file: '/var/log/enterprise-mail/combined.log',
    time: true,
    merge_logs: true
  }]
};
EOF

# 启动PM2服务
echo -e "${BLUE}🚀 启动API服务...${NC}"
pm2 start ecosystem.config.js --env production
pm2 save
pm2 startup

# 配置Nginx
read -p "是否配置Nginx? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🌐 配置Nginx...${NC}"
    
    # 检查并安装Nginx
    if ! command -v nginx &> /dev/null; then
        echo "安装Nginx..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y nginx
        elif command -v yum &> /dev/null; then
            sudo yum install -y nginx
        fi
    fi

    # 创建Nginx配置
    sudo tee /etc/nginx/sites-available/enterprise-mail << EOF
server {
    listen 80;
    server_name $MAIL_DOMAIN;
    
    # 强制HTTPS重定向
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $MAIL_DOMAIN;
    
    # SSL配置 (需要配置SSL证书)
    # ssl_certificate /path/to/certificate.crt;
    # ssl_certificate_key /path/to/private.key;
    
    # 前端静态文件
    root $(pwd)/frontend/build;
    index index.html;
    
    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    # 静态文件
    location / {
        try_files \$uri \$uri/ /index.html;
        expires 1h;
    }
    
    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # API代理
    location /api {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass \$http_upgrade;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;
}
EOF

    # 启用站点
    sudo ln -sf /etc/nginx/sites-available/enterprise-mail /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # 测试配置
    if sudo nginx -t; then
        sudo systemctl restart nginx
        sudo systemctl enable nginx
        echo -e "${GREEN}✅ Nginx配置完成${NC}"
    else
        echo -e "${RED}❌ Nginx配置测试失败${NC}"
    fi
fi

# SSL证书配置提示
echo -e "${BLUE}🔒 SSL证书配置${NC}"
echo "建议使用Let's Encrypt获取免费SSL证书："
echo "sudo apt-get install certbot python3-certbot-nginx"
echo "sudo certbot --nginx -d $MAIL_DOMAIN"

# 防火墙配置
read -p "是否配置防火墙? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🛡️  配置防火墙...${NC}"
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow ssh
        sudo ufw allow http
        sudo ufw allow https
        sudo ufw allow 25/tcp    # SMTP
        sudo ufw allow 587/tcp   # SMTP提交
        sudo ufw allow 993/tcp   # IMAPS
        sudo ufw --force enable
        echo -e "${GREEN}✅ 防火墙配置完成${NC}"
    fi
fi

# 完成部署
echo
echo -e "${GREEN}🎉 部署完成！${NC}"
echo "=================================="
echo
echo -e "${YELLOW}📋 部署信息:${NC}"
echo "• 域名: https://$MAIL_DOMAIN"
echo "• 数据库: enterprise_mail"
echo "• API服务: PM2管理"
echo "• 日志目录: /var/log/enterprise-mail"
echo
echo -e "${YELLOW}🔧 管理命令:${NC}"
echo "• 查看服务状态: pm2 status"
echo "• 重启服务: pm2 restart enterprise-mail-api"
echo "• 查看日志: pm2 logs"
echo "• Nginx状态: sudo systemctl status nginx"
echo "• 数据库连接: mysql -u $MYSQL_USER -p enterprise_mail"
echo
echo -e "${YELLOW}⚠️  下一步:${NC}"
echo "1. 配置SSL证书确保HTTPS访问"
echo "2. 设置邮件服务器 (参考 MAIL_SERVER_SETUP.md)"
echo "3. 配置域名DNS记录指向此服务器"
echo "4. 创建管理员账户: https://$MAIL_DOMAIN/register"
echo "5. 监控系统运行状态和日志"
echo
echo -e "${GREEN}✨ 系统已就绪，开始使用企业邮件系统！${NC}"

exit 0