# Wrapping versioned admin/REST APIs into custom web tools

This is the core pattern behind "custom web tools for environment
management" — building a typed Python client (and optionally a CLI and/or
a thin web dashboard on top of it) around a versioned admin REST API such
as Cloudera Manager, Kubernetes, Terraform Cloud, Ansible Tower, or any
internal ops API.

**Cloudera Manager API (v40 → latest) is the running example throughout,
generalized.** Cloudera Manager exposes a path-versioned REST API
(`/api/vN/...`) with a version-discovery endpoint and resource-oriented
paths (clusters, services, roles, hosts). The specific endpoint paths,
payload schemas, and the exact current max version number are **not**
hardcoded here deliberately — training data can be stale or subtly wrong,
and this is exactly the kind of detail that must be confirmed against the
target cluster's own live API (its `/api/version` response and the
official docs for whatever version that cluster actually runs) before
being relied on. What's below is the methodology that pattern-matches
onto Cloudera Manager and any API shaped like it.

## 1. Version discovery and negotiation

Versioned admin APIs typically expose either:
- a dedicated version-discovery endpoint returning the min/max API
  version the server supports (Cloudera Manager's `/api/version` style),
  or
- a version embedded in the URL path (`/api/v40/...`), or a header
  (`Accept: application/vnd.api+json;version=40`).

Client design:
- On client construction (or lazily, cached), call the discovery endpoint
  once to learn the server's supported version range.
- Pick the highest version the client code was written/tested against
  that the server also supports — don't blindly request the server's
  max version if the client's request/response models were written
  against an older version; don't pin to an old version forever either.
  Make the target version an explicit, overridable parameter, not a
  buried constant.
- Fail loudly and specifically if the server's version is below what the
  client requires (a clear `UnsupportedApiVersionError`, not a generic
  KeyError three calls later from a missing field).

## 2. Auth and credentials

- Never hardcode credentials. Read them from environment variables, a
  secrets manager, or an explicit config object passed in by the caller.
- Support whatever the target API actually uses: HTTP Basic auth (common
  for on-prem admin APIs like Cloudera Manager), bearer/API tokens, or
  session-cookie login flows. Isolate this behind one
  `_authenticated_session()`/`_get_headers()` method so swapping auth
  mechanisms later doesn't ripple through every call site.
- For CLI/local-dev ergonomics, `keyring` (OS credential store) or a
  `.netrc`-style local config file is preferable to a plaintext config
  file with a password in it — flag it if you see credentials being read
  from or written to plaintext files, and prefer env vars/secrets
  managers for anything server-side.
- Mask credentials in logs and error messages unconditionally.

## 3. Client architecture

Structure as a thin, resource-oriented layer over a single HTTP session,
not a pile of ad-hoc functions each opening their own connection:

```
client/
  __init__.py        # public client entry point, e.g. ClouderaManagerClient
  _http.py           # session management, auth, retries, error mapping
  _pagination.py      # generic pagination helper
  clusters.py         # resource submodule: cluster-related calls
  services.py          # resource submodule: service-related calls
  hosts.py             # resource submodule: host-related calls
  models.py            # typed request/response models (dataclasses or Pydantic)
  errors.py            # typed exception hierarchy
```

- One shared `requests.Session`/`httpx.Client` instance per client object
  — connection pooling and consistent headers/auth come for free.
- Resource submodules expose typed methods (`clusters.list()`,
  `clusters.get(name)`, `clusters.restart(name)`), not a single generic
  `client.call("GET", "/clusters")` escape hatch as the primary API
  (an escape hatch is fine to *also* have, for endpoints the typed layer
  hasn't caught up to yet).
- Model responses with dataclasses or Pydantic models rather than passing
  raw `dict`s around past the HTTP boundary — this is where most of the
  "expert" value is: callers get autocomplete and type-checking instead
  of guessing dict keys.

## 4. Pagination

Admin APIs commonly paginate list endpoints (offset/limit,
cursor/continuation-token, or link-header style). Write one generic
pagination helper (an iterator/generator that yields items and handles
fetching the next page transparently) and reuse it across every list
endpoint rather than duplicating pagination logic per resource.

## 5. Retries, timeouts, and error handling

- Always set an explicit timeout on every request — an admin API hanging
  should not hang the calling tool forever.
- Retry with exponential backoff + jitter on transient failures (network
  errors, 502/503/504, and 429 if the API rate-limits) — `urllib3.Retry`
  via `requests`, or a small hand-rolled backoff loop if going
  dependency-light. Do **not** blindly retry non-idempotent
  state-changing calls (POST that triggers a restart, a delete) without
  understanding whether the API is safe to retry — check for an
  idempotency-key mechanism or confirm the operation is safe to repeat
  before retrying it automatically.
- Map HTTP status codes to a typed exception hierarchy
  (`ApiClientError` → `ApiAuthError`, `ApiNotFoundError`,
  `ApiRateLimitedError`, `ApiServerError`, `UnsupportedApiVersionError`)
  so callers can handle specific failure modes instead of catching a
  generic exception and guessing.
- Distinguish "the operation failed" from "the operation's result is
  unknown" (e.g. a timeout after a POST that may or may not have applied
  server-side) — for state-changing ops against infrastructure, surface
  this ambiguity to the caller/UI rather than silently treating a
  timeout as a clean failure.

## 6. Testing without hitting the real environment

- Record real interactions once (via `vcrpy` or the `responses` /
  `respx` libraries for `requests`/`httpx`) and replay them as fixtures
  in tests — don't require a live Cloudera Manager (or equivalent)
  instance to run the test suite, and don't mock so deeply that the
  tests stop exercising real request/response shapes.
- Test version-negotiation and error-mapping paths explicitly (server
  returns an unsupported version, a 401, a 429) — these are exactly the
  paths that don't get exercised by happy-path manual testing and are
  where env-management tools tend to fail silently in production.

## 7. Putting a CLI and/or web UI on top

Keep the client library UI-agnostic; build thin surfaces on top rather
than duplicating logic:

- **CLI**: `argparse`/`click`/`typer` calling straight into the client
  library. Good for scripted/automated use and for engineers who live in
  a terminal.
- **Web dashboard**: FastAPI (best fit — auto-generated OpenAPI docs
  double as living documentation of the wrapped API, see
  `frameworks.md`) or Flask for a lighter footprint. The web layer should
  do essentially nothing but: call the client library, render
  status/data, and gate state-changing actions behind an explicit
  confirmation step.
- **Audit logging**: log every state-changing call (who, what, when,
  against which resource) separately from general app logs — this is
  often the actual point of building a custom tool instead of using the
  vendor's raw API/UI directly: a clean audit trail for infrastructure
  changes.
- **Background/long-running operations**: cluster restarts, rolling
  upgrades, and similar operations are often asynchronous on the server
  side (the API returns a "command" or "job" ID to poll). Model this
  explicitly — a background poller (APScheduler, a Celery task, or a
  simple asyncio task) that updates status, rather than a request
  handler blocking on a long-poll for a multi-minute operation.
- **Config per environment**: separate client instances/config
  (`dev`/`stage`/`prod` clusters or accounts) via `pydantic-settings` or
  explicit named profiles — never let a tool default silently to whichever
  environment happens to be configured, when the whole point of the tool
  is managing potentially-destructive infrastructure operations. Make the
  target environment explicit and visible in the UI/CLI output at all
  times.

## Summary checklist for a new env-management tool

1. Confirm the target API's actual current version/schema against its
   live docs or discovery endpoint — don't assume from memory.
2. Build the typed client library first, independent of any UI.
3. Get auth, version negotiation, pagination, retries, and error mapping
   right in the client before building anything on top of it.
4. Add tests against recorded fixtures, not the live system.
5. Add a thin CLI and/or FastAPI/Flask UI that only orchestrates the
   client — no business logic duplicated in the web layer.
6. Add audit logging and explicit environment targeting for anything
   state-changing.
