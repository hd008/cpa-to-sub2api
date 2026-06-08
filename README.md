# cpa-to-sub2api

把多个 CPA JSON 一键合并成 Sub2API 可导入的 `sub2api.json`。

## 下载

只需要下载这一个文件：

https://github.com/hd008/cpa-to-sub2api/releases/download/v1.0.2/CpaToSub2Api.bat

## 使用

1. 把所有 CPA JSON 放到同一个文件夹。
2. 把 `CpaToSub2Api.bat` 也放进去。
3. 双击 `CpaToSub2Api.bat`。

运行后会生成：

```text
sub2api.json
```

把 `sub2api.json` 导入 Sub2API 即可。

<img width="1889" height="935" alt="Sub2API 导入示意" src="https://github.com/user-attachments/assets/7dcfc955-7bec-496e-8e24-56a2b9c460d0" />

## 说明

- 只支持 Windows。
- 不需要单独的 `.ps1` 文件。
- 工具只处理 BAT 所在文件夹里的 JSON。
- 全程本地运行，不上传 token，不请求外部 API。
- `sub2api.json` 包含真实 OAuth 凭证，请不要上传到 GitHub 或公开分享。

## English

One-click Windows BAT tool for merging multiple CPA JSON files into a Sub2API import file.

Download:

https://github.com/hd008/cpa-to-sub2api/releases/download/v1.0.2/CpaToSub2Api.bat

Put `CpaToSub2Api.bat` in the folder containing CPA JSON files, double-click it, then import the generated `sub2api.json` into Sub2API.

`sub2api.json` contains real OAuth credentials. Keep it private.

## 致谢

感谢真诚、友善、团结、专业的 [LinuxDo](https://linux.do/) 社区，让我学到那么多有关 AI 的知识。

LinuxDo

LinuxDo 学 AI，上 L 站！

## License

MIT


