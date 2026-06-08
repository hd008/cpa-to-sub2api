# cpa-to-sub2api

一个 Windows 单文件 BAT 工具，把多个 CPA 格式的 Codex/OpenAI OAuth JSON 转成一个可导入 Sub2API 的 `sub2api.json`。

只需要下载/复制 **一个文件**：

```text
CpaToSub2Api.bat
```

下载地址：

https://github.com/hd008/cpa-to-sub2api/releases/download/v1.0.0/CpaToSub2Api.bat

把它放到 CPA JSON 所在文件夹，双击运行即可。

运行后会生成：

```text
sub2api.json
cpa-to-sub2api-summary.csv
```

## 快速使用

1. 把所有 CPA JSON 文件放到同一个文件夹。
2. 把 `CpaToSub2Api.bat` 复制到这个文件夹。
3. 双击 `CpaToSub2Api.bat`。
4. 到 Sub2API 后台导入生成的 `sub2api.json`。

BAT 会固定处理“BAT 自己所在的文件夹”，不是命令行当前目录。

## 输入格式

每个 CPA JSON 文件大概长这样：

```json
{
  "id_token": "...",
  "client_id": "...",
  "access_token": "...",
  "refresh_token": "...",
  "account_id": "...",
  "email": "user@example.com",
  "type": "codex",
  "expired": "2026-06-17T10:08:12Z",
  "plan_type": "team"
}
```

工具会读取文件夹里的所有 `*.json`，并自动跳过已生成的输出文件。

## 输出格式

生成的 `sub2api.json` 使用 Sub2API 的导入结构：

```json
{
  "type": "sub2api-data",
  "version": 1,
  "exported_at": "2026-06-07T00:00:00Z",
  "proxies": [],
  "accounts": []
}
```

每个账号会生成：

- `platform`: `openai`
- `type`: `oauth`
- `credentials.access_token`
- `credentials.refresh_token`
- `credentials.id_token`
- `credentials.client_id`
- `credentials.email`
- `credentials.chatgpt_account_id`
- `credentials.chatgpt_user_id`，如果 JWT 里能解析到
- `credentials.organization_id`，如果 JWT 里能解析到
- `credentials.plan_type`
- `credentials.expires_at`
- 账号级 `expires_at`，Unix 秒级时间戳

## 汇总文件

`cpa-to-sub2api-summary.csv` 不包含 token，用来检查：

- 读取了多少 JSON
- 有多少账号可导入
- 是否包含 `access_token`
- 是否包含 `refresh_token`
- 是否包含 `id_token`
- 账号过期时间

## 安全提醒

`sub2api.json` 包含真实 OAuth 凭证，请当作密码一样保管。

不要把以下文件提交到 GitHub：

- CPA 源 JSON
- 生成的 `sub2api.json`
- 任何包含 token 的文件

本仓库不会提供真实 token 示例。

## 环境要求

- Windows
- Windows PowerShell 5.1 或更高版本

不需要单独的 `.ps1` 文件。转换逻辑已经内嵌在 BAT 文件里。

---

## English

A one-file Windows BAT tool for converting multiple CPA-style Codex/OpenAI OAuth JSON files into one Sub2API import file.

Download/copy one file only:

```text
CpaToSub2Api.bat
```

Download:

https://github.com/hd008/cpa-to-sub2api/releases/download/v1.0.0/CpaToSub2Api.bat

Put it in the folder containing your CPA JSON files, then double-click it.

It generates:

```text
sub2api.json
cpa-to-sub2api-summary.csv
```

Quick steps:

1. Put all CPA JSON files in one folder.
2. Copy `CpaToSub2Api.bat` into that folder.
3. Double-click `CpaToSub2Api.bat`.
4. Import the generated `sub2api.json` in Sub2API.

The BAT always processes the folder where the BAT itself is located.

`sub2api.json` contains real OAuth credentials. Treat it as a secret and never commit it to GitHub.

## License

MIT
