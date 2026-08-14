---
name: websearch
description: |
  Local, zero-API-cost web search using lynx/links2/curl as primary methods, with
  Playwright CDP (browser skill) as fallback for JS-heavy pages. Always activate
  alongside the browser skill. Use whenever the user asks to search the web, look
  something up online, fetch a URL, or research a topic. Never calls any paid/metered
  API. If no network tool is available, say so and work from local knowledge.
---

# Web Search — local tools + browser fallback

Zero-cost web search stack. No API billing risk. Methods tried in order:
**lynx/links2 → curl+grep → Playwright CDP (browser skill)**

---

## ⚠️ Hard constraints (always enforced)

- **Never** call the Anthropic API, OpenAI, Bing API, Google Search API, SerpAPI,
  or any metered/paid search endpoint.
- **Never** use the WebSearch or WebFetch assistant tools — those are billed calls.
- `curl`/`wget` only against public HTTP endpoints. Never against `api.anthropic.com`,
  `api.openai.com`, or any LLM/data-API host.
- If a method would result in a charge → stop, say "This would trigger a billable
  API call. I won't execute it.", and fall back to local knowledge.

---

## Step 0 — detect available tools

Run once at start of any search task:

```bash
echo "lynx:    $(command -v lynx    || echo MISSING)"
echo "links2:  $(command -v links2  || echo MISSING)"
echo "curl:    $(command -v curl    || echo MISSING)"
echo "wget:    $(command -v wget    || echo MISSING)"
echo "python3: $(command -v python3 || echo MISSING)"
```

Pick the first available method below.

---

## Method 1 — lynx (preferred)

Renders HTML to clean plain text locally. No JS execution. Fastest for text content.

```bash
# Search DuckDuckGo HTML endpoint (no JS required, no API key)
lynx -dump -nolist -accept_all_cookies=no \
  "https://html.duckduckgo.com/html/?q=YOUR+QUERY+HERE" 2>/dev/null \
  | sed '/^\s*$/d' | head -80

# Fetch a specific URL
lynx -dump -nolist "https://example.com/page" 2>/dev/null | head -120
```

**Tips:**
- Replace spaces with `+` in query strings.
- `head -80` keeps output tight — increase only if needed.
- `-nolist` suppresses the link-number index at the bottom.
- Add `-width=120` for wider terminal output on dense pages.

**Install if missing:**
```bash
sudo apt-get install -y lynx
```

---

## Method 2 — links2

Nearly identical to lynx; use when lynx is absent.

```bash
links2 -dump "https://html.duckduckgo.com/html/?q=YOUR+QUERY+HERE" 2>/dev/null \
  | sed '/^\s*$/d' | head -80

links2 -dump "https://example.com/page" 2>/dev/null | head -120
```

**Install if missing:**
```bash
sudo apt-get install -y links2
```

---

## Method 3 — curl + grep (fallback when no text browser)

Fetches raw HTML; grep extracts useful text fragments.

```bash
# DuckDuckGo search snippets
curl -sA "Mozilla/5.0 (X11; Linux x86_64)" \
  "https://html.duckduckgo.com/html/?q=YOUR+QUERY+HERE" \
  | grep -oP '(?<=class="result__snippet">)[^<]+' \
  | head -20

# Result titles
curl -sA "Mozilla/5.0 (X11; Linux x86_64)" \
  "https://html.duckduckgo.com/html/?q=YOUR+QUERY+HERE" \
  | grep -oP '(?<=class="result__title">)[^<]+' \
  | head -10

# Fetch a page and strip tags to readable text
curl -sA "Mozilla/5.0 (X11; Linux x86_64)" "https://example.com/page" \
  | sed 's/<[^>]*>//g' \
  | sed '/^\s*$/d' \
  | head -100
```

**wget variant:**
```bash
wget -qO- "https://html.duckduckgo.com/html/?q=YOUR+QUERY+HERE" \
  | grep -oP '(?<=class="result__snippet">)[^<]+' \
  | head -20
```

---

## Method 4 — Playwright CDP (browser skill fallback)

Use when:
- The target page requires JavaScript to render content.
- `lynx`/`links2`/`curl` return empty or garbled results.
- The user explicitly asks to "open in browser" or "show me the page".

Activate the **browser skill** in full, then extract text:

```python
# After connecting per browser skill Step 2–3:
page.goto("https://html.duckduckgo.com/html/?q=YOUR+QUERY", wait_until="networkidle", timeout=30000)
text = page.inner_text("body")
print(text[:3000])  # cap output — don't dump the whole DOM
page.screenshot(path="/tmp/browser_shot.png", full_page=True)
```

For search results, prefer extracting structured nodes over dumping `body`:
```python
results = page.query_selector_all(".result__snippet")
for r in results[:10]:
    print(r.inner_text())
```

Always take a screenshot and view it to verify what rendered before reading text.

---

## Search engine endpoints (no API key needed)

| Engine | URL pattern |
|---|---|
| DuckDuckGo HTML | `https://html.duckduckgo.com/html/?q=QUERY` |
| DuckDuckGo lite | `https://lite.duckduckgo.com/lite/?q=QUERY` |
| Wiby (text sites) | `https://wiby.me/?q=QUERY` |

Always prefer **DuckDuckGo HTML** — it requires no JS, no cookies, and returns clean result snippets.
Never use Google search URLs directly (they block curl/lynx quickly and the API is paid).

---

## Token efficiency and output discipline

- Never dump raw HTML into the conversation — always strip or grep first.
- Cap extracted output: `head -80` for searches, `head -120` for single-page fetches.
- Detect available tools once at session start; don't re-check each query.
- Summarise findings in your own words; never paste walls of scraped text.
- Stop after the first method that produces usable results — don't try all
  methods sequentially when one already answered the question.
- If a page returns a CAPTCHA or bot-block → say so and try DuckDuckGo lite or Wiby instead.

---

## Integration with browser skill

This skill and the browser skill are always active together. Decision matrix:

| Situation | Use |
|---|---|
| Text search, any query | lynx/links2/curl → DDG HTML endpoint |
| Specific URL, text content | lynx/links2 dump |
| Specific URL, JS-rendered | Playwright (browser skill) |
| Screenshots / visual verify | Playwright (browser skill) |
| Form interaction / login | Playwright (browser skill) — human-in-loop rules apply |
| Result requires API key | **STOP** — do not execute |

---

## Error handling

| Symptom | Fix |
|---|---|
| `lynx: command not found` | Try links2, then curl, then Playwright |
| Empty curl output | Add `-L` flag for redirects; check if page needs JS → Playwright |
| DDG returns CAPTCHA | Switch to `lite.duckduckgo.com/lite/` |
| Playwright page blank | Use `wait_until="networkidle"`, increase timeout to 45000 |
| All methods blocked | Work from local knowledge; tell the user |
| Would need a paid API | **STOP** — say "This would trigger a billable API call. I won't execute it." |

$ARGUMENTS