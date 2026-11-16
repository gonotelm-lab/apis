# gonotelm-lab/apis

Protobuf 源仓。只改本仓库；Go/Node client 由 CI 自动生成并推送到：

- https://github.com/gonotelm-lab/apis-go-client
- https://github.com/gonotelm-lab/apis-nodejs-client

`main` 仅允许通过 Pull Request 合入。合入后同步到下游的 commit message 会带上对应 PR 号，例如：

`chore: sync from apis@<sha> (main, PR #12)`

## 本地生成

```bash
buf dep update
buf generate
```

产物在 `.generated/`（已 gitignore），勿提交。

<!-- smoke -->
