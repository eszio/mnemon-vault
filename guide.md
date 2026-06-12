## mnemon — Memory Routing

Default store: `team` (set via `MNEMON_STORE=team` env)
All `mnemon remember` calls go to the **team store** unless overridden.

### Team store — default, shared with all team members

Use for anything a teammate would benefit from knowing:
- Architectural decisions and system design choices
- Service endpoints, hostnames, infrastructure facts
- Team conventions, workflows, runbooks
- Bug root causes and fixes worth remembering
- Technical insights about the codebase or systems
- Project context and ongoing work

### Personal store — `--store personal`, private to you

Use for content that is about you specifically, not the project:
- Personal preferences ("I prefer X", "I usually...", "I don't like...")
- Personal workflow shortcuts or habits
- Anything sensitive to this individual
- Opinions that reflect personal taste, not team decisions

### Commands

```bash
# Team (default):
mnemon remember "<fact>" --cat <cat> --imp <1-5> --entities "e1,e2"

# Personal:
mnemon --store personal remember "<fact>" --cat preference --imp <1-5>
```

### Rule of thumb

Ask: **"Would a teammate benefit from knowing this?"**
- Yes → team store (default, no flag needed)
- No / personal / sensitive → `--store personal`

### Categories quick reference

| Category | Typical store |
|---|---|
| `fact` | team |
| `decision` | team |
| `insight` | team |
| `context` | team |
| `preference` | personal |
