# 安全配置指南

## 🔒 安全最佳实践

### 1. 服务器安全

#### 系统更新
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum update -y
```

#### 防火墙配置
```bash
# 使用UFW
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 25/tcp
sudo ufw allow 587/tcp
sudo ufw allow 993/tcp

# 或使用iptables
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

#### SSH安全
```bash
# 修改SSH配置
sudo nano /etc/ssh/sshd_config

# 推荐设置
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
Port 2222  # 更改默认端口

sudo systemctl restart sshd
```

### 2. 应用安全

#### 环境变量保护
```bash
# 设置适当的文件权限
chmod 600 backend/.env
chown $USER:$USER backend/.env

# 从Git中排除敏感文件
echo ".env" >> .gitignore
```

#### JWT安全配置
```bash
# 生成强密钥
JWT_SECRET=$(openssl rand -hex 32)

# 设置合理的过期时间
JWT_EXPIRES_IN=24h  # 不要设置太长
```

#### 数据库安全
```sql
-- 创建专用数据库用户
CREATE USER 'mailuser'@'localhost' IDENTIFIED BY 'strong_password_here';
GRANT SELECT, INSERT, UPDATE, DELETE ON enterprise_mail.* TO 'mailuser'@'localhost';

-- 移除不必要的权限
REVOKE ALL PRIVILEGES ON *.* FROM 'mailuser'@'localhost';

-- 删除默认用户
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'%';
```

### 3. SSL/TLS配置

#### Let's Encrypt证书
```bash
# 安装Certbot
sudo apt-get install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d yourdomain.com -d mail.yourdomain.com

# 自动续期
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

#### Nginx SSL配置
```nginx
server {
    listen 443 ssl http2;
    server_name yourdomain.com;
    
    # SSL证书
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    # SSL安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;
    
    # 其他安全头
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
}
```

### 4. 邮件安全

#### SPF记录
```dns
yourdomain.com. IN TXT "v=spf1 mx a ip4:YOUR_SERVER_IP ~all"
```

#### DKIM配置
```bash
# 生成DKIM密钥
openssl genrsa -out dkim_private.pem 2048
openssl rsa -in dkim_private.pem -pubout -outform der 2>/dev/null | openssl base64 -A
```

#### DMARC策略
```dns
_dmarc.yourdomain.com. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"
```

### 5. 访问控制

#### API速率限制
```javascript
// backend/src/middleware/rateLimit.js
const rateLimit = require('express-rate-limit');

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分钟
  max: 5, // 最多5次尝试
  message: '登录尝试次数过多，请稍后再试',
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = { loginLimiter };
```

#### IP白名单（管理员功能）
```javascript
const adminIpWhitelist = ['192.168.1.100', '10.0.0.50'];

const adminAccess = (req, res, next) => {
  const clientIP = req.ip;
  if (adminIpWhitelist.includes(clientIP)) {
    next();
  } else {
    res.status(403).json({ error: '访问被拒绝' });
  }
};
```

### 6. 日志和监控

#### 日志配置
```javascript
// winston日志配置
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' })
  ]
});

// 记录安全事件
logger.warn('Failed login attempt', { ip: req.ip, email: req.body.email });
```

#### 监控脚本
```bash
#!/bin/bash
# monitor.sh - 系统监控脚本

# 检查服务状态
if ! pgrep -f "enterprise-mail-api" > /dev/null; then
    echo "API服务异常，正在重启..."
    pm2 restart enterprise-mail-api
    echo "$(date): API服务重启" >> /var/log/monitor.log
fi

# 检查磁盘空间
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    echo "磁盘空间不足: ${DISK_USAGE}%" | mail -s "服务器警告" admin@yourdomain.com
fi

# 检查内存使用
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
if [ $MEMORY_USAGE -gt 85 ]; then
    echo "内存使用率过高: ${MEMORY_USAGE}%" | mail -s "服务器警告" admin@yourdomain.com
fi
```

### 7. 备份策略

#### 数据库备份
```bash
#!/bin/bash
# backup.sh - 数据库备份脚本

BACKUP_DIR="/backup/mysql"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="enterprise_mail"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份数据库
mysqldump -u backup_user -p$BACKUP_PASSWORD $DB_NAME > $BACKUP_DIR/enterprise_mail_$DATE.sql

# 压缩备份
gzip $BACKUP_DIR/enterprise_mail_$DATE.sql

# 删除7天前的备份
find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete

# 定时任务
# 0 2 * * * /path/to/backup.sh
```

#### 文件备份
```bash
#!/bin/bash
# 备份上传文件和配置
tar -czf /backup/files_$(date +%Y%m%d).tar.gz \
    backend/uploads/ \
    backend/.env \
    frontend/.env \
    logs/
```

### 8. 安全审计

#### 定期安全检查
```bash
#!/bin/bash
# security-audit.sh

echo "=== 安全审计报告 $(date) ==="

# 检查失败的登录尝试
echo "失败的登录尝试:"
grep "Failed login" logs/combined.log | tail -10

# 检查可疑的IP访问
echo "高频访问IP:"
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head -10

# 检查系统更新
echo "可用的安全更新:"
apt list --upgradable 2>/dev/null | grep -i security

# 检查端口开放情况
echo "开放的端口:"
netstat -tuln | grep LISTEN
```

#### Fail2Ban配置
```bash
# 安装Fail2Ban
sudo apt-get install fail2ban

# 配置/etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
```

### 9. 应急响应

#### 安全事件响应
```bash
#!/bin/bash
# emergency-response.sh

# 发现安全威胁时的应急操作

# 1. 临时阻止可疑IP
SUSPICIOUS_IP="192.168.1.100"
iptables -A INPUT -s $SUSPICIOUS_IP -j DROP

# 2. 重置管理员密码
mysql -u root -p -e "UPDATE enterprise_mail.users SET password_hash = '$NEW_HASH' WHERE email = 'admin@domain.com';"

# 3. 撤销所有JWT token（通过更改密钥）
NEW_JWT_SECRET=$(openssl rand -hex 32)
sed -i "s/JWT_SECRET=.*/JWT_SECRET=$NEW_JWT_SECRET/" backend/.env

# 4. 重启服务
pm2 restart all
systemctl restart nginx

# 5. 发送警报
echo "安全事件已处理，请检查系统状态" | mail -s "安全警报" admin@domain.com
```

### 10. 合规性

#### GDPR合规
- 实现用户数据删除功能
- 提供数据导出功能
- 记录数据处理活动
- 实施数据保护措施

#### 审计日志
```javascript
// 记录所有关键操作
const auditLog = {
  timestamp: new Date(),
  user: req.user.id,
  action: 'LOGIN',
  ip: req.ip,
  userAgent: req.get('User-Agent'),
  success: true
};
```

通过实施这些安全措施，您的企业邮件系统将具备企业级的安全防护能力。记住安全是一个持续的过程，需要定期审查和更新安全措施。