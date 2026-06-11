---
name: ddg-search
description: Web search via DuckDuckGo — zero API keys, no authentication. Use when native WebSearch/WebFetch is unavailable (locally-hosted models, restricted environments) or as a lightweight search fallback.
disable-model-invocation: false
---

# DuckDuckGo Search

## When to use this skill

- Native WebSearch or WebFetch tools are unavailable (locally-hosted models, air-gapped setups)
- You need current web data and no other search mechanism exists in the session
- Grounding a response with live results without any API key or account requirement
- As a supplemental search layer alongside the `last30days` skill

## How to invoke

Run the bundled script via Bash:

```bash
python3 ~/.claude/skills/ddg-search/duckduckgo_search.py "<your query>"
```

Returns up to 10 results with title, URL, and full body text per result.

## Requirements

- Python 3.12+
- `ddgs` package — installed automatically by `install.sh` via `pip install ddgs`

## Usage patterns

```bash
# Single concept
python3 ~/.claude/skills/ddg-search/duckduckgo_search.py "latest claude model pricing 2026"

# Comparison query
python3 ~/.claude/skills/ddg-search/duckduckgo_search.py "openai vs anthropic context window 2026"

# Lookup with site scope
python3 ~/.claude/skills/ddg-search/duckduckgo_search.py "site:github.com pydantic v3 migration"
```

## Notes

- Each call hits DuckDuckGo fresh — results are not cached
- No rate limit tracking required; DuckDuckGo is free and unauthenticated
- For richer multi-source research (Reddit, HN, YouTube, GitHub), use the `last30days` skill instead
