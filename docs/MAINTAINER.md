# Maintainer notes (private workflow)

## Dual repository workflow

| Remote | Purpose |
|--------|---------|
| **Private** (`origin`) | Full development tree, probe scripts, local configs |
| **Public** (`public`) | Sanitized export for community use |

```bash
git push origin main              # private: all work
bash tools/push-to-public.sh      # public: scrubbed export
```

Set `PRIVATE_REPO_URL` and `PUBLIC_REPO_URL` in `config.env`.

Discord build notifications (`tools/notify-discord.sh`) read `DISCORD_WEBHOOK_URL` from `config.env` and are **not** exported to the public repo.
