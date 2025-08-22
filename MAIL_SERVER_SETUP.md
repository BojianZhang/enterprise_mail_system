# 邮件服务器配置指南

本指南将帮您配置完整的邮件服务器环境，包括SMTP和IMAP服务。

## 🏗️ 架构概览

```
Internet
    ↓
[Nginx] → 反向代理
    ↓
[Enterprise Mail System] → Web界面和API
    ↓
[Postfix] → SMTP服务器（发送邮件）
    ↓
[Dovecot] → IMAP服务器（接收邮件）
    ↓
[MySQL] → 数据库存储
```

## 📧 Postfix SMTP配置

### 安装Postfix
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install postfix

# CentOS/RHEL
sudo yum install postfix
```

### 配置Postfix
编辑 `/etc/postfix/main.cf`:

```bash
# 基本配置
myhostname = mail.yourdomain.com
mydomain = yourdomain.com
myorigin = $mydomain
inet_interfaces = all
inet_protocols = all

# 网络和访问控制
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
home_mailbox = Maildir/

# 邮箱大小限制
message_size_limit = 26214400
mailbox_size_limit = 1073741824

# 虚拟域名和别名支持
virtual_alias_domains = 
virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf
virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf
virtual_mailbox_base = /var/mail/vhosts
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000

# 安全配置
smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination
```

### 创建MySQL映射配置
创建 `/etc/postfix/mysql-virtual-mailbox-domains.cf`:

```bash
user = mailuser
password = your_password
hosts = 127.0.0.1
dbname = enterprise_mail
query = SELECT domain_name FROM domains WHERE domain_name='%s' AND is_active = 1
```

创建 `/etc/postfix/mysql-virtual-mailbox-maps.cf`:

```bash
user = mailuser
password = your_password
hosts = 127.0.0.1
dbname = enterprise_mail
query = SELECT full_email FROM aliases WHERE full_email='%s' AND is_active = 1
```

创建 `/etc/postfix/mysql-virtual-alias-maps.cf`:

```bash
user = mailuser
password = your_password
hosts = 127.0.0.1
dbname = enterprise_mail
query = SELECT full_email FROM aliases WHERE full_email='%s' AND is_active = 1
```

## 📬 Dovecot IMAP配置

### 安装Dovecot
```bash
# Ubuntu/Debian
sudo apt-get install dovecot-core dovecot-imapd dovecot-lmtpd dovecot-mysql

# CentOS/RHEL
sudo yum install dovecot dovecot-mysql
```

### 基础配置
编辑 `/etc/dovecot/dovecot.conf`:

```bash
# 启用的协议
protocols = imap lmtp

# 监听地址
listen = *, ::

# 基础目录
base_dir = /var/run/dovecot/
```

### 邮件存储配置
编辑 `/etc/dovecot/conf.d/10-mail.conf`:

```bash
# 邮件存储格式
mail_location = maildir:/var/mail/vhosts/%d/%n

# 邮件用户权限
mail_uid = vmail
mail_gid = vmail

# 首次登录自动创建邮箱
first_valid_uid = 5000
last_valid_uid = 5000
```

### 认证配置
编辑 `/etc/dovecot/conf.d/10-auth.conf`:

```bash
# 禁用明文认证（除非SSL/TLS）
disable_plaintext_auth = yes

# 认证机制
auth_mechanisms = plain login

# 包含SQL认证配置
!include auth-sql.conf.ext
```

创建 `/etc/dovecot/conf.d/auth-sql.conf.ext`:

```bash
passdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf.ext
}

userdb {
  driver = static
  args = uid=vmail gid=vmail home=/var/mail/vhosts/%d/%n
}
```

### MySQL认证配置
创建 `/etc/dovecot/dovecot-sql.conf.ext`:

```bash
driver = mysql
connect = host=127.0.0.1 dbname=enterprise_mail user=mailuser password=your_password

default_pass_scheme = PLAIN

# 用户认证查询
password_query = SELECT u.email as user, u.password_hash as password FROM users u JOIN aliases a ON u.id = a.user_id WHERE a.full_email = '%u' AND u.is_active = 1 AND a.is_active = 1

# 用户信息查询  
user_query = SELECT '/var/mail/vhosts/%d/%n' as home, 'maildir:/var/mail/vhosts/%d/%n' as mail, 5000 AS uid, 5000 AS gid FROM aliases WHERE full_email = '%u' AND is_active = 1
```

### SSL/TLS配置
编辑 `/etc/dovecot/conf.d/10-ssl.conf`:

```bash
# SSL支持
ssl = required

# 证书文件路径
ssl_cert = </etc/ssl/certs/dovecot.pem
ssl_key = </etc/ssl/private/dovecot.pem

# 安全设置
ssl_prefer_server_ciphers = yes
ssl_min_protocol = TLSv1.2
```

## 🔐 用户和权限设置

### 创建邮件用户
```bash
# 创建vmail用户
sudo groupadd -g 5000 vmail
sudo useradd -g vmail -u 5000 vmail -d /var/mail/vhosts -m

# 设置权限
sudo chown -R vmail:vmail /var/mail/vhosts
sudo chmod -R 755 /var/mail/vhosts
```

## 🌐 DNS配置

### MX记录
```bash
yourdomain.com. 3600 IN MX 10 mail.yourdomain.com.
```

### SPF记录
```bash
yourdomain.com. 3600 IN TXT "v=spf1 mx a ~all"
```

### DKIM记录
```bash
default._domainkey.yourdomain.com. 3600 IN TXT "v=DKIM1; k=rsa; p=YOUR_PUBLIC_KEY"
```

### DMARC记录
```bash
_dmarc.yourdomain.com. 3600 IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"
```

## 🚀 启动服务

```bash
# 启动并启用服务
sudo systemctl start postfix
sudo systemctl enable postfix
sudo systemctl start dovecot
sudo systemctl enable dovecot

# 检查服务状态
sudo systemctl status postfix
sudo systemctl status dovecot
```

## 🔍 测试配置

### 测试SMTP
```bash
# 使用telnet测试SMTP
telnet mail.yourdomain.com 25

# 发送测试邮件
echo "Test message" | mail -s "Test" test@yourdomain.com
```

### 测试IMAP
```bash
# 使用telnet测试IMAP
telnet mail.yourdomain.com 143

# 或使用SSL
openssl s_client -connect mail.yourdomain.com:993
```

### 查看日志
```bash
# Postfix日志
sudo tail -f /var/log/mail.log

# Dovecot日志
sudo tail -f /var/log/dovecot.log
```

## 🛡️ 安全加固

### 防火墙配置
```bash
# 开放邮件端口
sudo ufw allow 25/tcp
sudo ufw allow 587/tcp
sudo ufw allow 993/tcp
sudo ufw allow 143/tcp
```

### Fail2ban配置
```bash
# 安装fail2ban
sudo apt-get install fail2ban

# 配置邮件服务保护
sudo nano /etc/fail2ban/jail.local
```

### SSL证书（Let's Encrypt）
```bash
# 安装certbot
sudo apt-get install certbot

# 获取证书
sudo certbot certonly --standalone -d mail.yourdomain.com

# 配置自动续期
sudo crontab -e
0 12 * * * /usr/bin/certbot renew --quiet
```

## 📊 监控和维护

### 邮件队列监控
```bash
# 查看队列
sudo postqueue -p

# 刷新队列
sudo postqueue -f

# 删除队列
sudo postsuper -d ALL
```

### 日志轮转
```bash
# 配置日志轮转
sudo nano /etc/logrotate.d/mail
```

### 性能优化
```bash
# Postfix性能调优
sudo postconf -e 'default_process_limit = 100'
sudo postconf -e 'smtpd_client_connection_count_limit = 50'

# Dovecot性能调优
echo 'mail_max_userip_connections = 50' >> /etc/dovecot/conf.d/20-imap.conf
```

通过以上配置，您将拥有一个完整、安全、高性能的邮件服务器系统！