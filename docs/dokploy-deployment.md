# Dokploy 自动化部署指南 (GitHub Actions + Webhook 一键持续部署)

本指南介绍如何通过 **GitHub Actions 自动构建双架构镜像（amd64 / arm64）并推送到 GitHub Packages (ghcr.io)**，随后**自动调用 Dokploy 的 Deploy Webhook** 完成上线。

💡 **核心特性：纯环境变量驱动，零挂载卷要求（Stateless）**
所有配置（包含上游密钥、轮询模式、访问密码等）均直接通过环境变量注入，**无需在 Dokploy 中配置任何存储卷挂载 (Mounts / Volumes)**，容器任意销毁重建均不影响服务！

---

## 🌟 整体流水线架构

```
本地 git push 到 main 分支
          │
          ▼
GitHub Actions 自动触发
  ├─ 1. 构建 multi-arch 镜像 (linux/amd64, linux/arm64)
  ├─ 2. 自动免密推送到 ghcr.io/<username>/cline-pass-switcher:latest
  └─ 3. 自动向 Dokploy Webhook URL 发起 Deploy 请求
          │
          ▼
Dokploy 收到通知
  ├─ 拉取最新 ghcr.io 镜像
  ├─ 自动读取环境变量配置
  └─ 零停机热重启完成更新
```

---

## 🚀 详细配置步骤

### 第 1 步：将代码推送到你的 GitHub 仓库

如果你克隆到了本地 `D:\inde-dev-project\cline-pass-switcher`，可以推送到你的 GitHub 个人仓库：
```bash
git add .
git commit -m "feat: setup github actions build and dokploy webhook"
git branch -M main
# 关联到你的 GitHub 仓库（若未关联）
git remote set-url origin https://github.com/<你的用户名>/cline-pass-switcher.git
git push -u origin main
```

> **注意**：进入你的 GitHub 仓库，检查 **Settings -> Actions -> General -> Workflow permissions**，确保勾选了 **Read and write permissions**，以便 Actions 有权限向 ghcr.io 推送镜像。

---

### 第 2 步：在 Dokploy 中创建服务并获取 Webhook URL

1. 打开并登录你的 **Dokploy** 后台，进入目标项目。
2. 点击右上角 **Create Service** -> 选择 **Application**。
3. 基础配置：
   - **Name**：`cline-pass-switcher`
   - **Source Type**：选择 **Docker**（或 Docker Image 模式）
   - **Image**：填写 `ghcr.io/<你的github用户名全小写>/cline-pass-switcher:latest`
     > 例如：`ghcr.io/hangzhu/cline-pass-switcher:latest`
     > 如果你的 GitHub 仓库是私有的，请先在 Dokploy 的 **Registry** 页面添加 GitHub Packages 认证（Username 填 GitHub 账号，Password 填 Personal Access Token；若是公开仓库则无需添加）。
4. **获取 Webhook URL**：
   - 在 Application 的设置/概览页（**Deployments** 或 **General** 标签），找到 **Deploy Webhook** / **Webhook URL**。
   - 复制该完整地址（形如 `https://dokploy.yourdomain.com/api/deploy/webhook/xxxx-xxxx`）。

---

### 第 3 步：在 GitHub 仓库添加 Webhook Secret

1. 打开你的 GitHub 仓库，点击顶部 **Settings**。
2. 找到左侧菜单 **Secrets and variables** -> **Actions**。
3. 点击 **New repository secret**：
   - **Name**：`DOKPLOY_WEBHOOK_URL`
   - **Secret**：粘贴刚刚在 Dokploy 中复制的 Webhook URL。
4. 点击 **Add secret** 保存。

---

### 第 4 步：在 Dokploy 中配置环境变量与域名（无需挂载任何卷）

#### 1. 环境变量配置 (Environment) ⚡
在 Dokploy 应用详情页，切换到 **Environment** 标签，添加以下环境变量：

| 变量名 | 是否必填 | 说明 | 示例 |
| :--- | :--- | :--- | :--- |
| `CLINE_PASS_KEY` | **必填** | 你的 Cline Pass 密钥。**支持逗号分隔填入多个 Key 自动组建账号池** | `sk-key1,sk-key2` |
| `PROXY_KEY` | **强烈建议** | 控制台访问密码及对外 API 调用凭据（公网必填防盗刷） | `my-secure-token-123456` |
| `ACCOUNT_MODE` | 可选 | 账号池工作模式：`roundrobin`（轮询）或 `single`（单账号，默认） | `roundrobin` |
| `PUBLIC_BASE_URL` | 可选 | 当前绑定的完整公网地址（用于控制台复制客户端接入命令） | `https://pass.yourdomain.com` |
| `PORT` | 可选 | 服务内部端口（默认 `3123`） | `3123` |

> 💡 **无需挂载卷**：所有配置均由上述环境变量驱动，无需在 `Mounts / Volumes` 中添加挂载卷。

#### 2. 绑定域名与自动 SSL (Domains)
1. 切换到 **Domains** 标签，点击 **Add Domain**。
2. **Host**：输入你的二级域名（例如 `pass.yourdomain.com`，DNS A 记录指向服务器 IP）。
3. **Container Port**：`3123`。
4. 勾选 **HTTPS**（Dokploy 自动通过 Traefik 申请并维护 Let's Encrypt 证书）。

---

### 第 5 步：点击 Deploy

在 Dokploy 右上角点击 **Deploy**：
- Dokploy 拉取镜像并启动容器。
- 容器启动后自动读取环境变量注入账号池。
- 内置健康探针 `/health` 检测就绪，应用显示为绿色 Healthy。
- 打开 `https://pass.yourdomain.com` 即可直接使用！

---

## 客户端接入配置 (OpenAI 兼容)

- **Base URL**：`https://pass.yourdomain.com/v1`
- **API Key**：你在 Dokploy 环境变量里设置的 `PROXY_KEY`
- **Model**：填任意订阅模型，如：
  - `cline-pass/glm-5.3-flash`
  - `cline-pass/deepseek-v4-pro`
  - `cline-pass/kimi-k3`
  - `cline-pass/qwen3.7-max`
