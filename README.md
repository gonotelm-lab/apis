# gonotelm-lab/apis

Protobuf 源仓。只改本仓库；Go/Node client 由 CI 自动生成并推送到：

- https://github.com/gonotelm-lab/apis-go-client
- https://github.com/gonotelm-lab/apis-nodejs-client

## 本地生成

```bash
buf dep update
buf generate
```

产物在 `.generated/`（已 gitignore），勿提交。

<!-- smoke -->
