# stdlib-only Python web/site tooling

When a framework is overhead, not help: locked-down environments where
installing dependencies is restricted or slow to approve, genuinely small
internal tools, or situations where the user explicitly wants zero
third-party dependencies. Know these well enough to reach for them
confidently rather than defaulting to Flask "just because."

## Serving HTTP

- **`http.server`**: fine for a quick local static file server or a
  trivial handler (`BaseHTTPRequestHandler` subclass overriding
  `do_GET`/`do_POST`). Not production-grade on its own — single-threaded
  by default (`ThreadingHTTPServer` fixes that for light concurrent
  load, but there's no real hardening: no built-in TLS termination
  config beyond wrapping the socket, no request size limits, no timeout
  handling worth trusting). Use it for internal/dev tooling, not
  anything internet-facing.
- **`socketserver`**: the layer `http.server` is built on. Reach for it
  directly only when building a non-HTTP protocol server, or when you
  need `ForkingMixIn`/`ThreadingMixIn` composition that `http.server`
  doesn't expose conveniently.
- **`wsgiref`**: the stdlib's reference WSGI implementation
  (`wsgiref.simple_server.make_server`). Useful for two things: (1)
  serving a hand-rolled WSGI app with zero dependencies, and (2) as the
  thing to actually understand if you want to know what Flask/Django are
  built on top of. Like `http.server`, not meant for production traffic
  — pair with a real WSGI server (gunicorn) once it needs to be real.
- **`asyncio` (`asyncio.start_server`, or a raw `asyncio` + a minimal
  hand-rolled HTTP parser)**: for a genuinely dependency-free async
  server. In practice, if you need real async HTTP semantics (keep-alive,
  chunked encoding, proper header parsing) without a framework, this
  gets painful fast — that's usually the signal to accept a dependency
  (`aiohttp`/`uvicorn`+`starlette`) rather than reimplementing HTTP/1.1
  parsing correctly by hand.

## Building a "site" with zero framework

- **Routing**: a `dict[str, Callable]` or a small `match`-based dispatcher
  on `self.path` inside a `BaseHTTPRequestHandler` is enough for a
  handful of routes. Beyond ~10-15 routes with path params, this is the
  signal to bring in Bottle or Flask rather than growing a bespoke
  router.
- **Templating**: `string.Template` for trivial substitution;
  `html.escape()` religiously on anything user-supplied before it hits a
  response body — stdlib gives you zero XSS protection by default, unlike
  Jinja2's autoescaping. If you're building actual HTML pages (not just
  JSON), and the escaping discipline is getting hard to maintain by hand,
  that's the signal to bring in Jinja2 (it can be used standalone,
  without Flask/Django) rather than a framework at all.
- **JSON APIs**: `json` module + manual `Content-Type` headers is
  entirely sufficient for a small stdlib-only JSON API — this is
  actually a very reasonable zero-dependency choice for an internal
  env-management endpoint that just needs to return status/data.
- **Forms/multipart**: `urllib.parse` for query strings and
  `application/x-www-form-urlencoded` bodies; `cgi.FieldStorage` for
  multipart form parsing is deprecated (removed in 3.13) — do not use it
  in new code. For real multipart handling without a framework, this is
  a case where a small dependency (`python-multipart`) or a framework is
  the right call rather than hand-parsing multipart bodies.
- **Sessions/auth without a framework**: `secrets.token_urlsafe()` for
  session tokens/CSRF tokens, `hashlib`/`hmac` for signing (or
  `hmac.compare_digest` for constant-time comparison — never `==` on
  secrets), `http.cookies.SimpleCookie` for cookie handling. Store
  session state server-side (a dict keyed by token, or sqlite) rather
  than trusting an unsigned client-side value.
- **Storage**: `sqlite3` is the natural zero-dependency datastore for a
  small stdlib tool — always use parameterized queries (`?` placeholders),
  never string-format SQL.
- **CLI half of the tool**: `argparse` for the command-line surface that
  usually accompanies a small internal tool (e.g. `mytool serve` vs
  `mytool status`).

## Making HTTP requests without `requests`

- **`urllib.request`**: entirely capable for a stdlib-only API client —
  `urllib.request.Request` with headers, `urlopen()`, read the response.
  Handles redirects and basic auth via `HTTPBasicAuthHandler` if needed.
  The rough edges vs. `requests`: no automatic JSON handling (do it
  yourself with the `json` module), connection pooling isn't automatic,
  and error handling is via `urllib.error.HTTPError`/`URLError`
  exceptions rather than a `.raise_for_status()`-style method — wrap
  these cleanly rather than leaking raw `urllib` exceptions to callers.
- **`http.client`**: lower-level than `urllib.request`; reach for it only
  when you need connection-level control `urllib.request` doesn't give
  you (e.g. manual keep-alive management).
- For anything that needs connection pooling, retries with backoff, or
  streaming uploads/downloads at a serious volume, that's the signal to
  accept `requests` or `httpx` as a dependency rather than reimplementing
  that reliability layer — see `versioned-api-clients.md` for the
  reasoning on when a real HTTP client dependency earns its place in an
  otherwise-stdlib tool.

## When to stop using only stdlib

Be honest about the crossover point rather than dogmatically staying
dependency-free:

- Hand-rolling HTTP/1.1 parsing, multipart parsing, or TLS handling
  correctly is a real security and correctness risk — these are exactly
  the areas where a small, well-audited dependency beats bespoke code.
- If routing, templating, or auth logic is growing past what fits
  comfortably in one or two files, that complexity is a sign a
  microframework (Bottle) or full framework will be *less* code and
  fewer bugs than the stdlib version, not more dependencies for their
  own sake.
- Zero-dependency is a means (deployability, security review overhead,
  restricted environments), not an end — say so plainly if a task's
  "no frameworks" constraint is starting to cost more in hand-rolled
  bugs than it saves in dependency footprint, and let the user decide.
