# 企业邮件系统 API 文档

## 🔗 基础信息

- **Base URL**: `http://localhost:3000/api`
- **认证方式**: Bearer Token (JWT)
- **内容类型**: `application/json`

## 📝 通用响应格式

### 成功响应
```json
{
  "success": true,
  "data": {
    // 响应数据
  },
  "message": "操作成功消息"
}
```

### 错误响应
```json
{
  "success": false,
  "error": "错误信息",
  "details": [
    // 验证错误详情（可选）
  ]
}
```

## 🔐 认证接口

### 用户注册
- **POST** `/auth/register`

**请求体**:
```json
{
  "email": "user@example.com",
  "password": "password123",
  "name": "用户姓名"
}
```

**响应**:
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "name": "用户姓名",
      "created_at": "2024-01-01T00:00:00.000Z",
      "is_active": true,
      "is_admin": false
    }
  },
  "message": "用户注册成功"
}
```

### 用户登录
- **POST** `/auth/login`

**请求体**:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**响应**:
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "name": "用户姓名"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  },
  "message": "登录成功"
}
```

### 用户登出
- **POST** `/auth/logout`
- **Headers**: `Authorization: Bearer <token>`

### 验证令牌
- **GET** `/auth/verify`
- **Headers**: `Authorization: Bearer <token>`

## 📬 别名管理

### 获取用户别名列表
- **GET** `/aliases`
- **Headers**: `Authorization: Bearer <token>`

**响应**:
```json
{
  "success": true,
  "data": {
    "aliases": [
      {
        "id": 1,
        "alias_name": "support",
        "full_email": "support@example.com",
        "display_name": "客户支持",
        "is_primary": true,
        "is_active": true,
        "domain_name": "example.com"
      }
    ]
  }
}
```

### 获取可用域名
- **GET** `/aliases/domains`
- **Headers**: `Authorization: Bearer <token>`

### 创建新别名
- **POST** `/aliases`
- **Headers**: `Authorization: Bearer <token>`

**请求体**:
```json
{
  "alias_name": "sales",
  "domain_id": 1,
  "display_name": "销售部门"
}
```

### 更新别名
- **PUT** `/aliases/:id`
- **Headers**: `Authorization: Bearer <token>`

**请求体**:
```json
{
  "display_name": "新的显示名称"
}
```

### 设置主要别名
- **PUT** `/aliases/:id/primary`
- **Headers**: `Authorization: Bearer <token>`

### 删除别名
- **DELETE** `/aliases/:id`
- **Headers**: `Authorization: Bearer <token>`

## 📧 邮件管理

### 获取邮件列表
- **GET** `/emails`
- **Headers**: `Authorization: Bearer <token>`

**查询参数**:
- `page`: 页码 (默认: 1)
- `limit`: 每页数量 (默认: 20)
- `folder`: 文件夹 (inbox, sent, drafts, trash, spam)
- `alias_id`: 别名ID
- `sort_by`: 排序字段 (created_at, subject, from_email)
- `sort_order`: 排序顺序 (ASC, DESC)

**响应**:
```json
{
  "success": true,
  "data": {
    "emails": [
      {
        "id": 1,
        "subject": "邮件主题",
        "from_email": "sender@example.com",
        "from_name": "发件人",
        "to_emails": ["recipient@example.com"],
        "is_read": false,
        "is_starred": false,
        "folder": "inbox",
        "created_at": "2024-01-01T00:00:00.000Z",
        "alias_email": "support@example.com"
      }
    ],
    "total": 50,
    "page": 1,
    "limit": 20,
    "totalPages": 3
  }
}
```

### 获取邮件详情
- **GET** `/emails/:id`
- **Headers**: `Authorization: Bearer <token>`

### 发送邮件
- **POST** `/emails`
- **Headers**: `Authorization: Bearer <token>`

**请求体**:
```json
{
  "alias_id": 1,
  "to": ["recipient@example.com"],
  "cc": ["cc@example.com"],
  "bcc": ["bcc@example.com"],
  "subject": "邮件主题",
  "body_text": "纯文本内容",
  "body_html": "<p>HTML内容</p>"
}
```

### 搜索邮件
- **GET** `/emails/search`
- **Headers**: `Authorization: Bearer <token>`

**查询参数**:
- `q`: 搜索关键词
- `page`: 页码
- `limit`: 每页数量

### 标记邮件已读/未读
- **PUT** `/emails/:id/read`
- **Headers**: `Authorization: Bearer <token>`

**请求体**:
```json
{
  "is_read": true
}
```

### 星标邮件
- **PUT** `/emails/:id/star`
- **Headers**: `Authorization: Bearer <token>`

**请求体**:
```json
{
  "is_starred": true
}
```

### 移动邮件到文件夹
- **PUT** `/emails/:id/folder`
- **Headers**: `Authorization: Bearer <token>`

**请求体**:
```json
{
  "folder": "trash"
}
```

### 删除邮件
- **DELETE** `/emails/:id`
- **Headers**: `Authorization: Bearer <token>`

## 🌐 域名管理 (管理员)

### 获取所有域名
- **GET** `/domains`
- **Headers**: `Authorization: Bearer <token>`
- **权限**: 管理员

### 获取活跃域名
- **GET** `/domains/active`
- **Headers**: `Authorization: Bearer <token>`

### 获取域名详情
- **GET** `/domains/:id`
- **Headers**: `Authorization: Bearer <token>`
- **权限**: 管理员

**响应**:
```json
{
  "success": true,
  "data": {
    "domain": {
      "id": 1,
      "domain_name": "example.com",
      "is_active": true,
      "mx_record": "mail.example.com"
    },
    "aliasCount": 5,
    "emailCount": 150
  }
}
```

### 创建域名
- **POST** `/domains`
- **Headers**: `Authorization: Bearer <token>`
- **权限**: 管理员

**请求体**:
```json
{
  "domain_name": "newdomain.com",
  "mx_record": "mail.newdomain.com",
  "spf_record": "v=spf1 mx a ~all"
}
```

### 更新域名
- **PUT** `/domains/:id`
- **Headers**: `Authorization: Bearer <token>`
- **权限**: 管理员

### 删除域名
- **DELETE** `/domains/:id`
- **Headers**: `Authorization: Bearer <token>`
- **权限**: 管理员

### 获取DNS记录
- **GET** `/domains/:domain/dns`
- **Headers**: `Authorization: Bearer <token>`
- **权限**: 管理员

**响应**:
```json
{
  "success": true,
  "data": {
    "dns_records": {
      "mx": "example.com. 3600 IN MX 10 mail.example.com.",
      "spf": "example.com. 3600 IN TXT \"v=spf1 mx a ~all\"",
      "dkim": "default._domainkey.example.com. 3600 IN TXT \"v=DKIM1; k=rsa; p=...\"",
      "dmarc": "_dmarc.example.com. 3600 IN TXT \"v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com\""
    }
  }
}
```

## ❌ 错误代码

| 状态码 | 说明 |
|--------|------|
| 400 | 请求参数错误 |
| 401 | 未认证/令牌无效 |
| 403 | 权限不足 |
| 404 | 资源未找到 |
| 409 | 资源冲突（如重复创建） |
| 500 | 服务器内部错误 |

## 📝 使用示例

### JavaScript/Node.js
```javascript
const axios = require('axios');

// 登录获取令牌
const login = async () => {
  const response = await axios.post('http://localhost:3000/api/auth/login', {
    email: 'user@example.com',
    password: 'password123'
  });
  return response.data.data.token;
};

// 获取邮件列表
const getEmails = async (token) => {
  const response = await axios.get('http://localhost:3000/api/emails', {
    headers: {
      'Authorization': `Bearer ${token}`
    },
    params: {
      folder: 'inbox',
      page: 1,
      limit: 20
    }
  });
  return response.data.data.emails;
};
```

### curl示例
```bash
# 登录
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

# 获取邮件列表
curl -X GET "http://localhost:3000/api/emails?folder=inbox&page=1&limit=20" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 发送邮件
curl -X POST http://localhost:3000/api/emails \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alias_id": 1,
    "to": ["recipient@example.com"],
    "subject": "测试邮件",
    "body_text": "这是一封测试邮件"
  }'
```