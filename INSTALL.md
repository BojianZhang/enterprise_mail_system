# 企业邮件系统 - 快速开始指南

## 📋 系统要求

- Node.js >= 16.0.0
- MySQL >= 8.0
- npm >= 8.0.0

## 🚀 快速安装

### 1. 克隆或下载项目
```bash
# 如果从Git仓库克隆
git clone <repository-url>
cd enterprise_mail_system

# 或者直接在项目目录中操作
```

### 2. 自动安装脚本
```bash
chmod +x start.sh
./start.sh
```

### 3. 手动安装

#### 后端设置
```bash
cd backend
npm install
cp .env.example .env
# 编辑 .env 文件配置数据库和其他设置
npm run build
```

#### 前端设置
```bash
cd frontend
npm install
npm run build
```

### 4. 数据库设置
```bash
# 创建数据库
mysql -u root -p
CREATE DATABASE enterprise_mail;

# 导入数据库结构
mysql -u root -p enterprise_mail < database/schema.sql

# 创建用户（可选）
CREATE USER 'mailuser'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON enterprise_mail.* TO 'mailuser'@'localhost';
FLUSH PRIVILEGES;
```

### 5. 启动服务

#### 使用PM2（推荐生产环境）
```bash
npm install -g pm2
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

#### 直接启动
```bash
cd backend
npm start
```

#### 开发模式
```bash
# 后端（自动重载）
cd backend
npm run dev

# 前端（另一个终端）
cd frontend
npm start
```

## 🔧 配置说明

### 后端配置（backend/.env）
```bash
# 数据库配置
DB_HOST=localhost
DB_PORT=3306
DB_USER=your_db_user
DB_PASSWORD=your_db_password
DB_NAME=enterprise_mail

# JWT配置
JWT_SECRET=your_secret_key
JWT_EXPIRES_IN=24h

# 服务器配置
PORT=3000
NODE_ENV=production

# 邮件服务器配置
SMTP_HOST=localhost
SMTP_PORT=587
IMAP_HOST=localhost
IMAP_PORT=993
```

### 前端配置（frontend/.env）
```bash
REACT_APP_API_URL=http://localhost:3000/api
```

## 📧 默认访问

- 前端界面: http://localhost:3001
- 后端API: http://localhost:3000/api/health

## 🎯 首次使用

1. 访问前端界面
2. 点击"创建新账户"注册用户
3. 登录系统
4. 添加邮件域名（需要管理员权限）
5. 创建邮箱别名
6. 开始使用邮件功能

## 🛠️ 故障排除

### 常见问题

**1. 数据库连接失败**
- 检查MySQL是否运行
- 验证数据库配置信息
- 确保数据库用户有正确权限

**2. 前端无法连接API**
- 检查后端服务是否启动
- 验证API URL配置
- 检查防火墙设置

**3. 邮件发送失败**
- 检查SMTP服务器配置
- 验证邮件服务器连接
- 查看后端日志

**4. 权限错误**
- 确保uploads目录可写
- 检查日志目录权限

### 日志查看

```bash
# PM2日志
pm2 logs

# 直接查看日志文件
tail -f logs/combined.log
```

## 🔗 相关链接

- 项目README: README.md
- API文档: 查看后端路由文件
- 问题反馈: GitHub Issues