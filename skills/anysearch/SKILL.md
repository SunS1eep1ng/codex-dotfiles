---
name: anysearch
description: >-
  AnySearch 公开互联网实时搜索、跨来源比较、垂直领域检索、批量搜索和公开 URL 正文提取。Use when the user explicitly asks for AnySearch, or when broad public-web research is needed and no authoritative first-party source or purpose-built connector is more appropriate. Do not use for private or authenticated data, local files, sensitive information, official product documentation with a dedicated source, or interactive browser tasks.
---

# AnySearch

Use AnySearch only for public-internet retrieval. Keep official first-party documentation, purpose-built connectors, local search tools, and interactive browser tools on their own preferred routes.

Upstream source: `anysearch-ai/anysearch-skill`, pinned from commit `b1a1bae6b257f1326d2e6ed51f64b36be75065e7` under Apache-2.0.

## Privacy boundary

- Treat every query and extraction URL as data sent to `https://api.anysearch.com`.
- Follow AnySearch's published policy: API call logs may be retained for 12 months, and the first 100 characters of a query may be retained for troubleshooting and service improvement. Never claim that the service performs no logging.
- Never send passwords, tokens, private repository content, unpublished work, trade secrets, health details, or other sensitive personal information.
- Use anonymous access by default. `ANYSEARCH_API_KEY` is optional and only raises limits.
- Never register an account, submit the user's email address, save a returned key, create `.env`, or edit credentials unless the user explicitly requests that exact action and approves the write.

## Runtime

1. Read `runtime.conf` in this skill directory.
2. Use its `Command` value directly for routine calls.
3. If the configured command fails, use an available Node.js runtime with `scripts/anysearch_cli.js`.
4. Run `doc` only after installation/update or when the command schema is unclear. For one subcommand, prefer `<cmd> <subcommand> --help`.

Routine forms:

```text
<cmd> search "query" --max_results 5
<cmd> batch_search --queries '[{"query":"q1","max_results":5},{"query":"q2","max_results":5}]'
<cmd> get_sub_domains --domain finance
<cmd> extract "https://example.com/page"
```

Do not invent output-format flags. `extract` already returns Markdown and accepts only a positional URL or `--url`/`-u`.

## Routing workflow

1. Prefer an authoritative first-party source for named product or API documentation.
2. Prefer a purpose-built connector for private, authenticated, or workspace data.
3. Prefer local tools such as `rg` for files and repositories.
4. Prefer Browser or Chrome when visual state, interaction, login state, or screenshots matter.
5. Use AnySearch for broad public discovery, current public information, cross-source comparison, vertical-domain research, or public HTML extraction.

For a general public query, call `search` directly. For a supported vertical domain, call `get_sub_domains` first and use only returned domain, sub-domain, and parameter names. Include every required parameter; use an empty value only when the API schema requires the key but no applicable value exists.

Use `batch_search` for two to five independent searches. Preserve source URLs, distinguish retrieved facts from synthesis, and verify high-impact claims against primary sources.

## Failure handling

If AnySearch is unavailable, rate-limited, or out of quota, report that briefly and use another safe in-scope public source when available. Do not create an account or persist credentials as an automatic recovery step.
