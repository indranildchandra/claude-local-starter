# Custom Skills

Place custom SKILL.md files here to distribute them across machines.

Each skill lives in its own subdirectory:

```
skills/
  my-skill/
    SKILL.md         required -- instructions for Claude
    reference.md     optional -- detailed reference Claude can read on demand
    scripts/         optional -- helper scripts the skill can invoke
```

Running `bash install.sh` will sync all skills here into `~/.claude/skills/`
using `cp -rn` (no overwrites of existing skills you've already customised locally).

## Naming convention

- Use lowercase-kebab-case for directory names
- The directory name becomes the skill name
- Skills installed from this repo are enabled by default
- Community skills installed by install.sh are disabled by default

## Example

```
skills/
  commit-discipline/
    SKILL.md    # teaches Claude your commit message format
  api-conventions/
    SKILL.md    # teaches Claude your internal API naming rules
```
