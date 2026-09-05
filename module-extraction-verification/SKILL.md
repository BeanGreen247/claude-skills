---
name: module-extraction-verification
description: Verify a code extraction (splitting a function/class/block out of a large file into a new module, or into a mixin class) is complete and behavior-preserving. Use whenever moving code between Python files during a refactor — extracting a class into its own module, pulling a mixin out of a monolith, splitting a package. Use before trusting that a newly-extracted file "just works".
---

# Module Extraction Verification

When you move code from file A into new file B (a refactor extraction — pulling
a class, function, or block of methods out of a monolith), the two failure
modes that actually bite are:

1. **Missing imports in B.** The moved code references names (`shutil`,
   `some_module`, a constant defined elsewhere in A) that existed in A's
   namespace but aren't imported into B. Python resolves a bare name in a
   function body against the module where that function is *defined* — not
   where its class is instantiated or used — so this breaks at runtime, often
   only on a rarely-hit code path, not at import time.
2. **Silent content drift.** Retyping or reformatting the block during the
   move introduces a subtle behavior change — a dropped line, a reordered
   condition, a "cleaned up" comment that actually documented a real
   constraint.

Both are cheap to catch mechanically. Don't rely on eyeballing the diff for
either.

## The verification sequence

For every extraction, in this order:

1. **Cut the block precisely.** Use line-range extraction (`sed -n
   'START,ENDp' file.py > /tmp/block.txt`) rather than retyping from memory or
   reconstructing from a Read-tool view. Retyping is exactly how content drift
   happens — confirmed in practice: a `resolve_real_user()` extraction once
   picked up extra logic from a *different, similarly-named* function seen
   earlier in the session, because it was written from memory instead of
   copied.

2. **Diff the moved block against the original** before wiring anything up:

   ```bash
   diff /tmp/block.txt <(tail -n +N new_module.py)   # N = first line of the real code, after your new header/imports
   ```

   The only differences should be the header/import lines you added. Anything
   else is unintended drift — fix it before proceeding, don't rationalize it.

3. **Write minimal plausible imports** for the new module based on what the
   block obviously needs (stdlib modules it calls, sibling project modules it
   references).

4. **Run `ruff check` (or your linter's undefined-name/unused-import check) on
   BOTH the new file and the file you cut it from.** This is the single most
   reliable step:
   - `F821` (undefined name) on the new file means you missed an import —
     it will find names like a stray `shutil.which(...)` call that manual
     grepping for "obviously used modules" skipped. This has happened in
     practice even after a careful manual scan.
   - `F401` (unused import) on the file you cut *from* means you can now
     drop an import there, or it means you left something behind that the
     new module actually owns.
   - Iterate: fix, re-run, repeat until both files are clean. Do not move on
     while `ruff check` reports anything in either file.

5. **Only after steps 1–4 are clean**, run the rest of your normal gate:
   compile check, full test suite, type checker, and — if the code has any
   runtime/GUI/live behavior that a headless run can't exercise — an actual
   live run of the changed path (not just an import-and-hope). A headless
   smoke test using `Tk.update()` in a loop, for example, can miss thread-
   timing bugs that only surface under a real `mainloop()` — if that
   distinction matters for what you're extracting, test both.

## Why this order

Steps 1–4 are nearly free (seconds) and catch the two failure modes that
would otherwise surface much later — sometimes only in production, on a code
path the test suite doesn't hit. Running the full test/build gate first and
debugging failures by inspection is slower than just linting the new file
immediately after writing it.

## Mixin-based extraction (splitting a big class's methods across files)

If you're extracting *methods* of a class (not free functions) into a mixin
so the original class multiply-inherits from several smaller ones:

- You can move a contiguous block of methods verbatim into `class SomeMixin:`
  in a new file, and have the original class inherit from it
  (`class Big(SomeMixin, OtherMixin): ...`) — method bodies don't need to
  change at all, because `self.foo()` and `self.some_attr` resolve through
  Python's normal attribute/MRO lookup at call time, regardless of which
  file physically defines the method.
- This means you do **not** need to extract cross-cutting helper methods
  first just because other methods call them — as long as every method
  ends up *somewhere* in the class's MRO, call sites keep working unchanged.
- The import-completeness problem (step 4 above) still applies per-file:
  each mixin file needs its own imports for whatever module-level names its
  methods reference, even though `self.*` access needs nothing extra.
- Never split a single method's body across two files, and never let the
  same method name land in two mixins the same class inherits — silent
  MRO shadowing is much harder to notice than an import error.
