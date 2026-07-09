# Python web frameworks — detailed reference

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
| No framework at all is justified | see `stdlib-web.md` |

Do not default to Django "because it's the big one" for a 200-line
internal tool, and do not default to Flask "because it's simple" for a
project that clearly needs Django's ORM/migrations/admin/auth stack.
Match the tool to the actual shape of the problem.

---

## Django

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

---

## Flask

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
  API client (see `versioned-api-clients.md`) — thin routes that call
  into a well-tested client library, render status, and gate
  state-changing actions behind confirmation + audit logging.
- **Testing**: `app.test_client()` + pytest fixtures for the app/client;
  avoid hitting real external services in tests — mock/patch the API
  client layer.

---

## FastAPI / Starlette

- **Pydantic models** define request/response shapes; let FastAPI
  generate validation and OpenAPI docs from them rather than hand-rolling
  validation. Use Pydantic v2 idioms (`model_config`, `field_validator`)
  for new code.
- **Dependency injection** (`Depends`) for shared concerns — DB sessions,
  auth, the versioned API client instance (see
  `versioned-api-clients.md`) — rather than importing globals into every
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

---

## The rest of the field

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
  dependency tree. If even Bottle feels heavy, see `stdlib-web.md`.
- **Pyramid**: highly configurable, "pay for what you use" — good fit
  for apps with unusual auth/traversal/routing needs that fight Django's
  or Flask's conventions. Rare to reach for fresh in 2026 unless the
  project already uses it.

Across all of these: don't introduce a second framework into a project
that has already standardized on one without an explicit reason and the
user's buy-in — consistency across a codebase beats any framework's
individual merits.
