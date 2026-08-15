---
name: python-engineer
description: "TRIGGER — read BEFORE writing or reviewing non-trivial Python, whenever: a Python web framework is involved (Django, Flask, FastAPI, Starlette, Tornado, aiohttp, Sanic, Quart, Bottle, Pyramid, Litestar); stdlib-only web/server code (http.server, wsgiref, socketserver, asyncio servers, urllib/http.client); general systems engineering (CLI tools, packaging/venv management, concurrency, subprocess/OS automation, profiling); building a tool/dashboard/CLI/client wrapping a versioned REST/admin API for env or infra management (Cloudera Manager, Kubernetes, Terraform Cloud, Ansible Tower, internal ops APIs); OR the Cloudera/Hadoop big-data stack (Spark/PySpark, Hive, Impala, HDFS, YARN, Kafka, HBase, Oozie/Airflow). SKIP when a non-Python stack is named (Node/Express, Rails, Laravel, Go, Java/Spring) or the task is pure ML/data-science modeling with no systems/web/big-data/tooling component. Never commits/pushes/does VCS actions; defers to token-economy for context/output/reasoning economy."
---

This skill covers full-stack Python engineering: web frameworks (Django, Flask,
FastAPI/Starlette, and alternatives), stdlib-only web/server code, general
systems engineering (CLI tools, packaging, concurrency, subprocess/OS
automation, profiling), the Cloudera/Hadoop big-data stack (Spark/PySpark,
Hive, Impala, HDFS, YARN, Kafka, HBase, Oozie/Airflow), and building custom
tools, dashboards, and CLIs wrapping versioned admin/REST APIs (Cloudera
Manager, Kubernetes, Terraform Cloud, Ansible Tower, internal ops APIs). Web
frameworks are one domain among several — not the whole scope.

## Scope

This is a single, self-contained, "all in one" skill covering:

1. **Full-featured web frameworks** — Django (with Django REST Framework),
   Flask, FastAPI/Starlette.
2. **Other web frameworks worth knowing** — Tornado, aiohttp, Sanic, Quart,
   Bottle, Pyramid, Litestar, and when each beats the "big three."
3. **stdlib-only web/site/tool building** — for locked-down environments,
   zero-dependency requirements, or genuinely small tools where a
   framework is overhead, not help.
4. **General Python systems engineering** — CLI tooling, packaging and
   dependency/virtualenv management, concurrency, subprocess/OS
   automation, testing, and performance profiling — the non-web, non-data
   backbone of being a full Python systems engineer, not just a web
   engineer.
5. **Cloudera/Hadoop big-data stack specialization** — Spark/PySpark,
   Hive, Impala, HDFS, YARN, Kafka, HBase, and Oozie/Airflow
   orchestration, including cluster resource tuning and data-engineering
   patterns.
6. **Custom tools for environment/infrastructure management** — building
   admin dashboards, CLIs, and typed client libraries around versioned
   REST/admin APIs (Cloudera Manager API v40+ is the running example, but
   the pattern is deliberately generic — it applies equally to
   Kubernetes, Terraform Cloud, Ansible Tower, or any internal ops API).

Areas 5 and 6 are the Cloudera specialization in practice: 5 is *running
workloads on* the cluster, 6 is *managing/automating the cluster itself*
via its admin API — most real Cloudera tooling tasks touch both.

**On the Cloudera Manager example specifically:** the methodology below
is the *generic* approach for wrapping a versioned admin REST API
(version discovery, auth, pagination, retry/backoff, resource-oriented
client design, testing via recorded fixtures). It deliberately does not
hardcode specific Cloudera Manager v40+ endpoint paths or response
schemas — those should always be confirmed against the live/current
official API docs or the target cluster's own `/api/version` and
`/api/vN/` discovery output before being relied on, not assumed from
training data.

## Reasoning workflow (follow in order)

1. Identify what's actually being built: a website/app (pick a framework
   per "Choosing a framework" below), a constrained/embedded tool
   (consider stdlib-only per "stdlib-only web/site tooling"), a general
   systems/CLI tool ("General Python systems engineering"), a big-data
   workload on the Cloudera/Hadoop stack ("Cloudera/Hadoop big-data stack
   specialization"), or an API-wrapper/admin tool ("Wrapping versioned
   admin/REST APIs") — many "env management" tasks are actually that last
   category wearing a web-framework costume: a thin FastAPI/Flask layer
   over a proper typed API client.
2. Inspect existing conventions, dependencies, and architecture before
   writing anything — read the relevant files, don't assume a framework
   or pattern the project doesn't already use.
3. Prefer the smallest correct dependency footprint: don't reach for
   Django when Flask or even stdlib suffices; don't reach for stdlib when
   it means reimplementing what a framework already does safely (routing,
   CSRF, request parsing).
4. Preserve existing style and architecture unless the user explicitly
   asks for a redesign or framework change.
5. Implement the smallest correct change.
6. Verify: run the test suite / type checker / linter available in the
   project. State plainly what you could not verify (e.g. behavior against
   a live external API, browser-rendered UI) rather than claiming success.

## Coding standards (all frameworks, all tools)

- Type hints on all new/touched function signatures; run the project's
  type checker (mypy/pyright) if configured.
- PEP 8 / the project's existing formatter (black/ruff format) — match
  what's already there, don't introduce a second style.
- Meaningful names; avoid unnecessary abstraction. Three similar lines
  beats a premature helper.
- Comment only when the *why* is genuinely non-obvious — a workaround, a
  non-obvious invariant, a subtlety in an external API's behavior.
- Never hardcode secrets, tokens, or credentials. Read them from
  environment variables, a secrets manager, or an explicit config object
  — never commit them, never log them, mask them in error output.
- Validate all external input (HTTP request bodies, query params, CLI
  args, API responses) at the boundary; trust internal code past that
  boundary.
- Prefer structured logging (`logging` with extra fields, or `structlog`
  if the project already uses it) over print statements in anything that
  isn't a one-off script.

## External API constraint

Never write, run, or suggest code that calls the Anthropic/Claude API
(`api.anthropic.com` or any Claude/Anthropic-branded SDK/wrapper), for any
reason — including as an example client for the "Wrapping versioned
admin/REST APIs" pattern below. No exceptions unless the user's current
request is explicitly about building a Claude API integration on purpose.

## Version control rules

- Do not commit, amend, squash, or create commits.
- Do not push, tag, or perform any other version-control action.
- Leave all commits and releases to the user, even if the change is
  complete and verified. Report what's ready instead of committing it.

---

# Python web frameworks

Read this before writing non-trivial code in any of these frameworks.
Covers the "big three" in depth, then the rest of the field and when each
one actually beats the big three.

## Choosing a framework

| Situation | Pick |
|---|---|
| Content-heavy site, need admin panel, ORM, auth, batteries included | **Django** |
| Small-to-medium app/API, full control, minimal ceremony | **Flask** |
| API-first service, need speed, async, auto-generated OpenAPI docs, strict typing | **FastAPI** |
| Long-lived connections, WebSockets, heavy async I/O, non-blocking custom protocols | **Tornado** or **aiohttp** |
| Flask-shaped app but must be async (e.g. calling async clients) | **Quart** |
| Modern typed ASGI service, want stricter DI/typing than FastAPI | **Litestar** |
| Single-file tool/microservice, near-zero footprint | **Bottle** |
| Highly composable/pluggable app, unusual routing/auth needs | **Pyramid** |
| No framework at all is justified | see "stdlib-only web/site tooling" below |

Do not default to Django "because it's the big one" for a 200-line
internal tool, and do not default to Flask "because it's simple" for a
project that clearly needs Django's ORM/migrations/admin/auth stack.
Match the tool to the actual shape of the problem.

### Django

- **App structure**: one project, multiple apps; keep apps focused and
  reusable. `settings.py` split per environment (`settings/base.py`,
  `dev.py`, `prod.py`) or driven by `django-environ`/`pydantic-settings`
  reading from env vars — never hardcode per-environment config.
- **ORM**: prefer the ORM over raw SQL; use `select_related`/
  `prefetch_related` deliberately to avoid N+1 queries — this is the
  single most common Django performance bug. Use `only()`/`defer()` for
  wide tables when you don't need every column.
- **Migrations**: one logical change per migration; never hand-edit an
  already-applied migration — write a new one. Run
  `makemigrations --check` in CI to catch missing migrations. Be careful
  with migrations that lock large tables in production (adding a
  NOT NULL column, adding an index without `CONCURRENTLY` on Postgres);
  flag this rather than silently generating a blocking migration.
- **Views**: class-based views for CRUD-shaped resources, function-based
  views for anything unusual — don't force everything into CBVs.
- **Django REST Framework (DRF)**: the default choice for building APIs
  on Django. Use `ModelSerializer` for straightforward CRUD, explicit
  `Serializer` for anything with computed/nested logic. Use
  `ViewSet`/`ModelViewSet` + routers for REST resources, explicit
  `APIView` for one-off endpoints. Version APIs explicitly
  (`URLPathVersioning` or a custom header scheme) from day one — retrofitting
  versioning later is painful.
- **Admin**: `django.contrib.admin` is a legitimate, fast way to build an
  internal environment-management UI — register models, customize
  `list_display`/`list_filter`/actions, and you have a working ops
  console with auth and audit-friendly change history for a fraction of
  the effort of a bespoke dashboard. Don't build a custom admin UI when
  the built-in one, customized, would do.
- **Auth**: use Django's built-in auth/permissions system
  (`django.contrib.auth`, `PermissionRequiredMixin`,
  `@permission_required`) rather than rolling custom session handling.
  For APIs, DRF's `TokenAuthentication`/`SessionAuthentication`, or
  `djangorestframework-simplejwt` for JWT.
- **Security defaults**: Django's ORM parameterizes queries — never
  build raw SQL with string interpolation (`.raw()`/`.extra()` with
  unsanitized input is a real injection vector). Keep `DEBUG = False` and
  `ALLOWED_HOSTS` set correctly in prod. CSRF protection is on by
  default for form-based views — don't disable it to "make things work"
  without understanding why it's failing.
- **Async**: Django supports async views/middleware since 4.1 — use them
  when a view is genuinely I/O-bound and calling async clients, but
  don't reach for async Django just because "async is faster"; the ORM
  itself is still primarily sync (`sync_to_async` bridges exist but add
  overhead).
- **Background work**: Celery (with Redis/RabbitMQ broker) is the
  standard for anything beyond trivial background jobs; `django-q2` or
  APScheduler for lighter needs. Don't do slow work (emails, external API
  calls, report generation) inline in a request/response cycle.
- **Testing**: `pytest-django` over the built-in `TestCase` runner for
  new projects if the project already uses pytest elsewhere;
  `TestCase`/`TransactionTestCase` are fine and idiomatic if the project
  already uses them. Use factories (`factory_boy`) over fixture files for
  test data that needs to vary.

### Flask

- **App factory pattern**: `create_app()` function that builds and
  configures the app, rather than a module-level `app = Flask(__name__)`
  — this is what makes testing, multiple configs, and multiple instances
  possible. Use it even for small apps if they're likely to grow.
- **Blueprints**: split routes by feature/resource area once the app
  grows past a handful of routes. Don't over-fragment a 5-route tool into
  5 blueprints.
- **Extensions**: `Flask-SQLAlchemy` + `Flask-Migrate` (Alembic under the
  hood) for DB-backed apps; `Flask-Login` for session auth;
  `Flask-RESTful`, `flask-smorest`, or plain blueprints + manual
  marshalling for APIs — `flask-smorest` (built on `marshmallow` +
  `apispec`) is the strongest choice when you also want OpenAPI docs out
  of Flask, which is common for internal env-management tools.
  `Flask-WTF` for form handling + CSRF on server-rendered forms.
- **Config**: `app.config.from_object()` / `from_envvar()` per
  environment; never hardcode secrets in `config.py` — read from env vars
  or a `.env` file loaded via `python-dotenv` in dev only.
- **Templating**: Jinja2, autoescaping is on by default for `.html` —
  never disable it or use `| safe` on untrusted input (XSS vector).
- **WSGI deployment**: Flask's dev server is not for production. Serve
  via `gunicorn` (sync/gthread workers) or `uwsgi` behind a reverse
  proxy (nginx) for anything real. For async needs, that's `Quart`, not
  Flask (Flask 2.x has limited native async view support but is still
  fundamentally WSGI/sync underneath).
- **Good fit for env-management tools**: Flask's low ceremony makes it a
  strong choice for a small internal dashboard sitting on top of a REST
  API client (see "Wrapping versioned admin/REST APIs" below) — thin
  routes that call into a well-tested client library, render status, and
  gate state-changing actions behind confirmation + audit logging.
- **Testing**: `app.test_client()` + pytest fixtures for the app/client;
  avoid hitting real external services in tests — mock/patch the API
  client layer.

### FastAPI / Starlette

- **Pydantic models** define request/response shapes; let FastAPI
  generate validation and OpenAPI docs from them rather than hand-rolling
  validation. Use Pydantic v2 idioms (`model_config`, `field_validator`)
  for new code.
- **Dependency injection** (`Depends`) for shared concerns — DB sessions,
  auth, the versioned API client instance (see "Wrapping versioned
  admin/REST APIs" below) — rather than importing globals into every
  route.
- **Async by default**: routes should be `async def` when they call
  async I/O (httpx async client, async DB driver). A sync `def` route
  still works (FastAPI runs it in a threadpool) — use that for routes
  wrapping sync-only libraries rather than forcing a fake async wrapper.
- **Background tasks**: FastAPI's `BackgroundTasks` for lightweight
  fire-and-forget work tied to a request; a real task queue (Celery/RQ/
  arq) for anything that needs retries, scheduling, or to survive a
  process restart.
- **ASGI server**: `uvicorn` for dev and most prod deployments (often
  behind `gunicorn -k uvicorn.workers.UvicornWorker` for multi-process);
  `hypercorn` if HTTP/2 or trio is needed.
- **Auto-generated docs (`/docs`, `/openapi.json`)** are a major reason
  FastAPI is a strong fit for internal env-management tools/API wrappers
  — the tool becomes self-documenting and testable via Swagger UI with
  near-zero extra effort. Lean into this for admin/ops tooling.
- **WebSockets**: native support (`@app.websocket`) — useful for
  streaming long-running operation status (e.g. a cluster restart) to a
  dashboard instead of polling.
- **Starlette directly**: reach for bare Starlette instead of FastAPI
  when you don't need Pydantic validation/OpenAPI and want less
  overhead — e.g. a lightweight internal proxy or webhook receiver.
- **Testing**: `TestClient` (sync, wraps httpx) or `httpx.AsyncClient`
  with `ASGITransport` for async test flows. Override dependencies
  (`app.dependency_overrides`) to inject fakes for the API client layer
  in tests instead of hitting real external systems.

### The rest of the field

- **Tornado**: mature async framework predating `asyncio` itself (has
  its own event loop, now asyncio-compatible). Good for apps needing
  fine-grained control over long-lived connections and non-blocking I/O
  at scale. Heavier/older idioms than FastAPI; only reach for it if the
  project already uses it or needs Tornado-specific features (e.g. its
  WebSocket/long-polling patterns).
- **aiohttp**: both an async web server *and* the most common async HTTP
  *client* in the Python ecosystem. Frequently shows up not as "the web
  framework" but as the async client library used inside a FastAPI/Flask
  app to call an external API — know it for that role even on projects
  that don't use aiohttp-the-server.
- **Sanic**: async, Flask-like API, historically prioritized raw speed.
  Reasonable choice if a project already standardized on it; don't
  introduce it fresh over FastAPI/Litestar without a specific reason.
- **Quart**: Flask's API surface, but ASGI/async — the right move when
  an existing Flask app needs to become async without a full rewrite to
  FastAPI.
- **Litestar**: modern, strictly-typed ASGI framework, FastAPI-adjacent
  but with stronger opinions on DI, layered architecture, and plugin
  structure. Worth choosing over FastAPI for larger, longer-lived
  services where that extra structure pays off; overkill for a small
  tool.
- **Bottle**: single-file, zero-dependency-beyond-itself microframework.
  Legitimate choice for a genuinely tiny internal tool that needs *a*
  framework's routing/templating but can't or shouldn't pull in Flask's
  dependency tree. If even Bottle feels heavy, see "stdlib-only web/site
  tooling" below.
- **Pyramid**: highly configurable, "pay for what you use" — good fit
  for apps with unusual auth/traversal/routing needs that fight Django's
  or Flask's conventions. Rare to reach for fresh in 2026 unless the
  project already uses it.

Across all of these: don't introduce a second framework into a project
that has already standardized on one without an explicit reason and the
user's buy-in — consistency across a codebase beats any framework's
individual merits.

---

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
  that reliability layer — see "Wrapping versioned admin/REST APIs" below
  for the reasoning on when a real HTTP client dependency earns its place
  in an otherwise-stdlib tool.

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

---

# General Python systems engineering

The non-web, non-big-data backbone of being a full Python systems
engineer: environment/dependency management, CLI tooling, concurrency,
OS/subprocess automation, testing, and performance work. This is what
separates "writes Python web apps" from "full Python systems engineer" —
apply it to any custom tool regardless of whether it also has a web/API
layer.

## Environment and dependency management

- **`uv`** is the fastest-moving modern default (single tool for venv
  creation, dependency resolution/locking, and running scripts with
  inline dependency metadata) — prefer it for new projects unless the
  project has already standardized on something else.
- **`poetry`**: still very common, especially on projects started before
  `uv` matured — full dependency + packaging + venv management with a
  lockfile. Don't migrate an existing Poetry project to `uv` without the
  user asking.
- **`pip-tools`** (`pip-compile`/`pip-sync`): a lighter-weight
  lockfile-over-plain-`pip` approach — common on older/simpler projects
  that don't want a full alternate package manager.
- **`pyenv`**: Python *version* management (which interpreter), separate
  from and complementary to the above (which manage *dependencies* within
  a given interpreter).
- **Never** install packages into the system/global Python on a shared
  or production host — always a venv (or the project's chosen tool's
  equivalent isolation) per project/tool.
- **`pyproject.toml`** is the standard modern packaging manifest
  (PEP 621) — prefer it over a bare `setup.py` for new packages.
- Pin dependencies for anything deployed (a lockfile or exact-pinned
  `requirements.txt`), keep ranges looser only for a library meant to be
  installed alongside other people's dependency trees.

## CLI tooling

- **`argparse`**: stdlib, zero dependencies, entirely sufficient for
  small-to-medium CLIs — the right default when dependency footprint
  matters (matches the stdlib-first philosophy above).
- **`click`**: the long-standing ergonomic choice for larger CLIs with
  subcommands, option groups, and shell completion — reach for it when
  `argparse` boilerplate is genuinely getting in the way.
- **`typer`**: type-hint-driven, built on Click — a strong choice when
  the project is already leaning on type hints everywhere (pairs
  naturally with FastAPI-style code) and wants CLI definitions to read
  like plain typed function signatures.
- Give every real CLI tool: `--help` that actually explains itself,
  non-zero exit codes on failure, `--version`, and structured
  (`--json`) output as an option when the tool's output might ever be
  piped into another program or CI step.

## Concurrency

- **`threading`**: right for I/O-bound work (network calls, file I/O)
  where the GIL isn't the bottleneck — many small concurrent HTTP
  requests, for instance.
- **`multiprocessing`**: right for CPU-bound work that needs to actually
  use multiple cores, since the GIL serializes CPU-bound threads. Mind
  pickling costs for large objects passed between processes; use shared
  memory (`multiprocessing.shared_memory`) or a worker-pool-with-small-
  payloads design when that becomes the bottleneck.
- **`asyncio`**: right for high-concurrency I/O-bound work, especially
  many-way fan-out (hundreds/thousands of concurrent network calls) where
  thread-per-call overhead would be too high. Don't mix sync blocking
  calls into an async codebase without offloading them
  (`asyncio.to_thread`) — one blocking call stalls the entire event loop.
- **Free-threaded Python (PEP 703, no-GIL builds)**: exists as of recent
  CPython versions but is not yet the default build most environments
  run — don't assume it's available; check the target interpreter before
  relying on true multi-core threading without `multiprocessing`.
- Pick the concurrency model based on what's actually the bottleneck
  (I/O wait vs CPU), not by default habit.

## Subprocess and OS automation

- **`subprocess.run`** with `capture_output=True`, explicit `timeout`,
  and `check=True` (or explicit return-code handling) — never
  `shell=True` with any input that isn't a fully-trusted, hardcoded
  string; that's a command-injection vector the instant any part of the
  command comes from user input, a file, or an API response. Pass args
  as a list instead.
- **`pathlib`** over raw string path manipulation/`os.path` for new code
  — more readable, less error-prone across platforms.
- **`shutil`** for file/directory copy, move, and disk-usage operations
  rather than hand-rolling them.
- Treat any destructive filesystem operation (delete, overwrite,
  recursive remove) in a tool the same way the top-level "executing
  actions with care" rules do — confirm before anything hard to reverse,
  especially in a tool that will run unattended/on someone else's
  machine.

## Testing

- **`pytest`** is the de facto standard; use fixtures for setup/teardown
  and parametrization over copy-pasted near-identical test functions.
- Mock/patch external boundaries (network calls, subprocess calls,
  filesystem where appropriate) — don't let unit tests depend on a real
  external service, cluster, or API being reachable (same principle as
  the fixture-based testing approach under "Wrapping versioned
  admin/REST APIs" below).
- For CLI tools, test the actual entry point (via `click.testing.CliRunner`,
  or by invoking the `argparse`-parsed function directly) rather than only
  testing internal helper functions and hoping the CLI wiring is correct.

## Performance profiling

- **`cProfile` + `snakeviz`/`pstats`** for CPU profiling — profile before
  optimizing; don't guess at the bottleneck.
- **`memory_profiler`** or `tracemalloc` (stdlib) for memory profiling —
  `tracemalloc` is the right first reach since it needs no extra
  dependency.
- **`timeit`** for microbenchmarking a specific function/expression, not
  for timing a whole program (use `time`/profiling for that).
- Optimize the actual measured bottleneck, not the line of code that
  looks slow — Python performance intuition is frequently wrong,
  especially around string concatenation, list vs generator use, and
  attribute-lookup cost in tight loops.

## Logging and observability for long-running tools

- Structured logging (stdlib `logging` with `extra={}` fields, or
  `structlog`) over `print()` for anything that runs unattended or needs
  to be grepped/aggregated later.
- Give long-running tools/daemons a clear liveness signal (a heartbeat
  log line, a health-check file, or — if it's also serving HTTP — a
  `/healthz` endpoint per the frameworks section above) rather than being
  a black box once deployed.

---

# Cloudera / Hadoop big-data stack specialization

Deep-dive for building and running workloads on a Cloudera Data Platform
(CDP)/CDH-style cluster, and for building custom Python tooling around
it. This is the "big data mastery" half of the Cloudera specialization —
for *managing the cluster itself* via its admin API, see "Wrapping
versioned admin/REST APIs" below.

As with the Cloudera Manager API guidance: this teaches durable
methodology and idiom, not a snapshot of exact current version numbers,
config defaults, or CLI flag names for a specific CDP/CDH release —
confirm those against the target cluster's actual installed version and
its official docs before relying on them.

## Spark / PySpark

- **Session setup**: one `SparkSession` per job, configured via
  `spark-submit` args / `SparkConf`, not hardcoded in application code —
  keep cluster-specific tuning (executor memory/cores, dynamic
  allocation) out of the Python source so the same job runs unmodified
  across dev/staging/prod cluster sizes.
- **DataFrame API over RDDs** for virtually all new code — the Catalyst
  optimizer and Tungsten execution engine only apply their optimizations
  to the DataFrame/SQL API, not raw RDD transformations. Drop to RDDs
  only for genuinely low-level control Catalyst can't express.
- **Avoid Python UDFs when a native/SQL expression exists** — a regular
  (non-vectorized) PySpark UDF forces row-by-row serialization between
  the JVM and a Python worker process, which is often the single biggest
  performance cliff in a PySpark job. Prefer built-in `pyspark.sql.functions`;
  if a UDF is unavoidable, use a **pandas UDF** (`@pandas_udf`, vectorized
  via Arrow) instead of a plain UDF.
- **Partitioning and shuffles**: understand where a job shuffles
  (`groupBy`, `join`, `repartition`, wide transformations) and size
  `spark.sql.shuffle.partitions` deliberately rather than leaving the
  200-partition default on both tiny and huge jobs. Watch for data skew
  (a few massively oversized partitions) as the usual cause of "one task
  never finishes" — salting keys or using `skewJoin` hints are the fix.
- **Caching**: `.cache()`/`.persist()` a DataFrame only when it's reused
  across multiple actions — caching something used once just burns
  executor memory for nothing. Unpersist when done with it in
  long-running jobs/notebooks.
- **File formats**: Parquet (columnar, predicate pushdown, schema
  evolution support) is the default choice for anything analytical;
  ORC is the traditional Hive-native alternative and still common on
  older CDH estates. Avoid CSV/JSON as the storage format for anything
  beyond small interchange files — no columnar pruning, no compression
  efficiency, fragile schema inference.
- **Resource tuning on YARN**: executor memory + `spark.yarn.executor.memoryOverhead`
  sized to avoid YARN killing containers for exceeding physical memory;
  executor count/cores balanced against the queue's YARN capacity, not
  maxed out against the whole cluster. Dynamic allocation
  (`spark.dynamicAllocation.enabled`) is usually right for shared
  multi-tenant clusters so a job doesn't hold idle executors.
- **Testing**: keep transformation logic in plain functions that take/return
  DataFrames so they're unit-testable with `pytest` + a local
  `SparkSession` (`master="local[*]"`), rather than testing only by
  submitting to a real cluster.

## Hive and Impala

- **Hive**: the batch SQL engine, backed by MapReduce/Tez/Spark execution
  engines depending on cluster config — good for large, less
  latency-sensitive batch/ETL SQL. Use `pyhive` or `impyla`
  (`impyla` also speaks Hive) or a JDBC/ODBC bridge to query from
  Python; for orchestrated pipeline SQL, prefer submitting via the
  cluster's job orchestration (Oozie/Airflow) over ad-hoc scripted
  connections where the project already has that infrastructure.
- **Impala**: MPP SQL engine for low-latency interactive queries over
  the same Hive Metastore-registered tables — same data, different
  engine, chosen for latency not throughput. `impyla` is the standard
  Python client. Impala requires `COMPUTE STATS` on tables after
  significant data changes for its cost-based optimizer to make good
  join-order decisions — a very common cause of "Impala is slow" that
  has nothing to do with the query itself.
- **Shared Metastore**: Hive and Impala (and often Spark SQL) typically
  share the Hive Metastore (HMS) as the table catalog on a Cloudera
  cluster — schema changes made through one engine are visible to the
  others, but each engine has its own query planner/optimizer, so
  performance characteristics differ even against identical tables.
- **Partitioning**: partition large Hive/Impala tables on low-cardinality,
  frequently-filtered columns (date is the classic case) — unpartitioned
  full-table scans on multi-terabyte tables are the most common
  first-week mistake.

## HDFS

- **Access from Python**: `hdfs`/`hdfs3`/`pyarrow.fs.HadoopFileSystem`
  for direct file-level access; WebHDFS REST API (via `requests` or the
  `hdfs` package's client) when you want HTTP-based access without the
  native libhdfs dependency — useful for lightweight tooling that
  shouldn't need a full Hadoop client install.
- **Small-files problem**: HDFS is optimized for large blocks (default
  128MB); a directory full of many small files degrades NameNode memory
  and read performance. Batch/compact small files (e.g. via a Spark
  `coalesce`/`repartition` write) rather than writing one file per
  record.
- **Permissions**: HDFS has a Unix-like permission model plus, on
  Kerberized clusters, real authentication — don't assume an
  unauthenticated/anonymous HDFS client will work against a production
  Cloudera cluster; see Kerberos note below.

## YARN

- **Resource model**: containers requested with memory + vCores against
  a queue; queue capacity/scheduler config (Capacity Scheduler or Fair
  Scheduler) determines how jobs share the cluster. When a job hangs in
  `ACCEPTED` state, that's almost always queue capacity/priority, not
  the job itself.
- **Programmatic interaction**: the YARN ResourceManager REST API
  (`/ws/v1/cluster/apps`, etc.) is how custom tooling queries running
  jobs, kills a stuck application, or checks queue utilization — same
  versioned-REST-API wrapping pattern as "Wrapping versioned admin/REST
  APIs" below applies directly here.

## Kafka

- **Client libraries**: `confluent-kafka-python` (librdkafka-backed, the
  performance-preferred choice) or `kafka-python` (pure Python, simpler
  to install, historically slower/less maintained) — prefer
  `confluent-kafka-python` for anything throughput-sensitive.
- **Consumer groups**: understand partition assignment and offset commit
  semantics (`enable.auto.commit` vs manual commit) before writing a
  consumer — auto-commit-before-processing is a common cause of silent
  data loss on consumer crash; commit after successful processing for
  at-least-once semantics.
- **Schema management**: use Avro/Protobuf with a Schema Registry
  (`confluent-kafka-python`'s `AvroSerializer` or similar) for anything
  beyond a toy pipeline — raw untyped JSON on a Kafka topic becomes an
  unversioned schema nightmare at scale.

## HBase

- **Access from Python**: `happybase` (Thrift-based, simple, widely used
  though the underlying HBase Thrift1 gateway is legacy in newer
  releases) or the REST gateway via `requests` for lighter-weight/
  cross-language access. Check what the target cluster actually exposes
  (Thrift server, REST gateway) before picking a client.
- **Row key design is the single highest-leverage HBase decision** —
  HBase only really supports efficient range scans on the row key;
  design it around the actual read pattern (and watch for
  monotonically-increasing keys like timestamps causing region
  hotspotting — salt/hash-prefix the key if writes are heavily skewed to
  one region).

## Orchestration: Oozie and Airflow

- **Oozie**: XML-workflow-based, tightly integrated with the
  Hadoop/Cloudera ecosystem, still common on older CDH estates. Python
  involvement is usually indirect (generating/templating the workflow
  XML, or calling the Oozie REST API to submit/monitor jobs).
- **Airflow**: the modern default for new pipeline orchestration,
  including on Cloudera-adjacent stacks — DAGs are plain Python, and
  there are first-class operators/hooks for Spark, Hive, HDFS, and
  Kafka. Prefer Airflow over new Oozie workflows for anything greenfield;
  don't migrate an entire working Oozie estate without a specific reason
  and the user's buy-in.

## Kerberos and security

- Cloudera clusters are very commonly Kerberized. Python clients
  connecting to HDFS/Hive/Impala/HBase/YARN need a valid Kerberos
  ticket (`kinit` beforehand, or `python-gssapi`/`requests-kerberos` for
  SPNEGO-authenticated HTTP endpoints like WebHDFS or the YARN/Cloudera
  Manager REST APIs). A client that "can't connect" or gets silent
  auth failures against a Cloudera cluster is very often a Kerberos
  ticket/keytab issue before it's a code issue — check that first.
- Never embed keytabs or Kerberos credentials in source control; read
  keytab paths from config/environment and handle ticket renewal
  (`kinit -R` on a timer, or a scheduled renewal job) for long-running
  processes rather than assuming a single `kinit` lasts forever.

## Putting it together: a typical custom Cloudera tool

A real "custom web tool for env management" on this stack is usually a
composite of pieces already covered:

1. A typed client wrapping the Cloudera Manager API for cluster/service
   status and admin actions ("Wrapping versioned admin/REST APIs" below).
2. Direct engine clients (`impyla`, `pyhive`, `happybase`, WebHDFS) for
   data-plane queries the dashboard needs to show (row counts, job
   status, recent partitions).
3. A thin FastAPI/Flask layer (see the frameworks section above)
   presenting both as one dashboard/API, with Kerberos-aware auth end to
   end.
4. Background polling (APScheduler/Celery) for anything that queries a
   YARN/Oozie/Airflow job's async status rather than blocking a request
   on it.

---

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
  double as living documentation of the wrapped API, see the frameworks
  section above) or Flask for a lighter footprint. The web layer should
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

---

## Quiet operation (silent-executor, merged)

This skill defaults to context-economical, quiet execution. Chatter costs
real tokens and crowds out work product, so by default (the globally-active
`token-economy` skill governs the deeper context/reasoning-effort economy
rules that apply across all work; this section is this skill's own output
discipline, merged in from `silent-executor`):

1. Treat the user's request as the only goal; do the work directly.
2. Do not narrate steps between tool calls ("Let me check X" / "Now I'll
   do Y") — batch independent tool calls together instead.
3. Do not provide progress updates or filler while working.
4. Do not ask unnecessary clarification questions unless the task is
   genuinely impossible without an answer.
5. Do not summarize the plan unless explicitly asked.
6. Do not produce a trailing recap/explanation after finishing — the
   final response *is* the deliverable, not a report about it.
7. On completion, respond with exactly:

   ```
   FINISHED
   YYYY-MM-DD HH:MM:SS TIMEZONE
   ```

   Use the current local completion time, no extra text before or after,
   no markdown block unless the platform requires one.
8. On failure, give the smallest possible failure message — state the
   blocker in one short sentence, nothing more.
9. For long multi-step tasks: work internally, don't narrate milestones,
   only emit the `FINISHED` block once everything is done.

### Destructive Action Exception (overrides quiet mode)

Silence never extends to actions that are destructive, hard to reverse,
or affect shared/external state — deleting files or branches, `rm -rf`,
force-push, `reset --hard`, dropping tables, overwriting uncommitted
work, sending messages, or posting/pushing to external systems. (Note
"do not commit" above already forbids commits/pushes outright — this
exception covers everything else destructive that isn't already banned.)
For any such action:

1. Break silence and briefly state what the action is and its impact.
2. Ask for explicit confirmation before proceeding.
3. Only resume quiet mode after the user confirms.

This exception overrides every other rule in this section and cannot be
waived by "work silently" instructions elsewhere in the task.

## When uncertain

Ask targeted clarifying questions only when a wrong guess would mean real
rework (e.g. framework choice for a new project, or whether an external
admin API's exact schema matters for this task) — otherwise proceed with
the smallest reasonable interpretation per the reasoning workflow above.

## Environment compatibility

Everything above — framework/tool selection, coding standards, the
detailed reference sections — applies the same way whether this runs in
Claude Code (CLI/desktop/web) or the claude.ai web app's Skills feature.
One thing does vary by environment:

- **File access and verification**: "run the test suite / type checker"
  in the reasoning workflow assumes a shell (Claude Code). In an
  environment without one, apply the same coding standards to whatever
  code is shown/edited inline, and say plainly that running
  tests/type-checks wasn't possible rather than claiming it was done.

## Commit message formatting (standing rule)

Commit messages are always a single line in conventional-commit format:
`type(scope): message` (e.g. `feat(input.cpp): add launcher keybind`) -- never
multi-line prose subject+body. No Co-Authored-By trailers unless asked.

When just reporting what the commit message *would be* (not executing the
commit), give the plain oneliner text only -- never wrap it in a
`git commit -m "$(cat <<'EOF' ... EOF)"` heredoc block; that form is for
actually running the commit, not for displaying the message as text.
