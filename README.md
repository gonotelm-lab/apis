# gonotelm-lab/apis

Protobuf 源仓。只改本仓库；Go/Node client 由 CI 自动生成并推送到：

- https://github.com/gonotelm-lab/apis-go-client
- https://github.com/gonotelm-lab/apis-nodejs-client

- `main`：仅允许通过 Pull Request 合入；下游 commit 会带 PR 号  
- 其它开发分支：可直接 push，不强制 PR  
- 所有同步：下游 commit message 都会带上 apis 的完整 commit SHA；并写入根目录 `APIS_SOURCE`

示例：

```text
chore: sync from apis@<sha> (main, PR #12)
chore: sync from apis@<sha> (feat/foo)
```

## 本地生成

```bash
buf dep update
buf generate
```

产物在 `.generated/`（已 gitignore），勿提交。

<!-- smoke -->
