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
  matters (matches the stdlib-first philosophy in `stdlib-web.md`).
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
  the fixture-based testing approach in `versioned-api-clients.md`).
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
  `/healthz` endpoint per `frameworks.md`) rather than being a black box
  once deployed.
