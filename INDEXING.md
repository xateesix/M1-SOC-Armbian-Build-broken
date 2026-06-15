# Indexed reference material (Cursor codebase indexing)

Updated: 2026-06-13

## In this repo (C:\Workspaces\Armbian-M1-SOC)

| Path | Purpose |
|------|---------|
| factory_fresh/ | Factory partitions, DTS, EXTRACTION_SUMMARY |
| tools/ | Build/pack scripts, patch-parameter-boot-size.py |
| FLASH_GPT_DEBUG.md | GPT unnamed-partition boot failure analysis |
| FLASH_RKDEVTOOL.md | Flash procedure and log checks |
| RESUME_HERE.md | Session pickup |

Large binaries (*.img) are excluded from indexing but available via shell/WSL.

## Sibling reference repos (C:\Workspaces\reference)

| Path | Purpose |
|------|---------|
| CB1/ | BTT CB1 README, system.cfg, overlays |
| BTT-build/ | BTT Armbian build fork (bpi-main) |

## Outside Workspaces (requires policy install)

| Path | Purpose |
|------|---------|
| Downloads/RKDevTool_Release_v3.32/.../Log/ | Flash logs |
| .cursor/projects/c/agent-transcripts/ | Prior chat sessions |

## Activate indexing after policy update

1. PowerShell **as Administrator**: install.ps1
2. Cursor: Developer -> Reload Window
3. Cursor: Resync Index (or Settings -> Codebase Indexing -> Refresh)
