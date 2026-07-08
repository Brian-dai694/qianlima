# EverOS Memory Playbook

EverOS is the optional cloud recall layer for 千里马计划. It does not replace local governance files, reports, or task cards. Use it to recover long-running preferences, prior decisions, and reusable agent lessons across sessions.

## Setup

```powershell
pip install everos-cloud
$env:EVEROS_API_KEY = "<set outside git>"
```

The checked-in dependency is also listed in `requirements.txt`.

## Default Loop

1. Before a task, search EverOS with the user's request:

```powershell
python .qianlima/scripts/everos_memory.py search "Japan welding accessories legal red line"
```

2. Use retrieved memories as hints. For business conclusions, reload the local source files named in the task card, report, or registry.

3. After a meaningful boundary, store a short reusable lesson only with user intent or explicit value:

```powershell
python .qianlima/scripts/everos_memory.py add-agent --role assistant --content "Lesson: Panasonic/SUZUKID-compatible listings must use 互換品 and 純正品ではありません disclaimers."
python .qianlima/scripts/everos_memory.py flush --agent
```

## Safety Rules

- Do not commit `EVEROS_API_KEY`.
- Do not automatically import `MEMORY.md`, `SESSION-STATE.md`, reports, marketplace exports, or credentials.
- Do not store tokens, cookies, passwords, raw customer data, or account credentials.
- EverOS memories are recall context, not authoritative evidence.
- For high-risk actions, reload local source sections before deciding.

## Useful Commands

Search user memories:

```powershell
python .qianlima/scripts/everos_memory.py search "keyword ranking recovery"
```

Search agent lessons:

```powershell
python .qianlima/scripts/everos_memory.py search --agent "what did the agent learn about keyword demand reports"
```

Store one memory item:

```powershell
python .qianlima/scripts/everos_memory.py add --role user --content "I prefer Japan market reports to separate Amazon-only and all-channel conclusions."
```

Retrieve recent episodes:

```powershell
python .qianlima/scripts/everos_memory.py get --memory-type episodic_memory --page-size 5
```
