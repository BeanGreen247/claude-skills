---
name: site-crawl
description: |
  Crawls an entire website (not just one page) and pulls its content into
  clean text/markdown for use in the conversation — for competitive research,
  rebuilding a site's structure, or extracting docs. Use when asked to
  "crawl", "scrape the whole site", "pull every page from", or "get all the
  docs from" a domain. Local reimplementation of the Firecrawl MCP's
  crawl/scrape tools using wget/curl only — no API key, no per-page billing.
metadata:
  origin: "local reimplementation, inspired by https://github.com/firecrawl/firecrawl-mcp-server"
---

# Site Crawl

Firecrawl's MCP server crawled a whole site through a hosted, metered API and returned clean markdown per page. This skill gets the same output locally with `wget`/`curl`, entirely offline-capable and free — never substitute a paid crawling API for this.

## Single page → clean markdown

For one known URL, prefer the existing `websearch` skill's page-fetch path (lynx/links2/curl) first — it already produces clean text. Reach for this skill specifically when you need **more than one page**.

## Whole-site crawl

1. **Scope it before running.** Ask/confirm: which domain or path prefix, how deep (link depth), and roughly how many pages — an unscoped crawl of a large site is slow and mostly waste. Default to a conservative depth (2) and same-domain-only unless told otherwise.
2. **Respect the site.** Check `https://<domain>/robots.txt` first and stay within what it allows. Rate-limit requests (wget's `--wait` / `-w`) instead of hammering the server — this is a courtesy crawl, not a stress test.
3. **Mirror with wget:**
   ```bash
   wget --mirror --convert-links --adjust-extension --page-requisites \
        --no-parent --domains=<domain> --wait=1 --random-wait \
        -P /tmp/claude-*/scratchpad/site-crawl/<domain> \
        https://<domain>/<start-path>
   ```
   Drop `--page-requisites` if you only need text, not images/CSS (much faster).
4. **Convert to markdown per page.** Use `lynx -dump -nolist` or `pandoc -f html -t markdown` (whichever is installed) over each fetched `.html` file rather than shipping raw HTML into context — raw HTML wastes tokens.
5. **Extract structure, not just text**, when the goal is "rebuild this site's IA": list the discovered URL tree first so the user/you can see the shape before pulling every page's content into context.
6. Store crawl output in the scratchpad directory, and only Read the specific pages actually needed into the conversation — don't dump an entire mirrored site into context at once.

## When this isn't enough

Some sites are JS-rendered and `wget`/`lynx` will only capture an empty shell. For those, fall back to the `browser` skill (Playwright CDP) to render each page and extract the DOM text — same "no paid API" constraint applies, this is still free.
