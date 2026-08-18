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

## Public export safety

- Treat `config.env`, logs, serial captures, and release binaries as private-only unless explicitly sanitized.
- Before publishing, redact usernames, passwords, API keys, Wi-Fi SSIDs/PSKs, IP addresses, hostnames, and device identity data.
- Keep the public repository limited to sanitized source, templates, and approved release artifacts.
- Assume the workspace is unstable and may close at any time; preserve durable notes in tracked files, not live session state.
