---
description: Update the Obsidian long-term-memory wiki (docs/wiki) from recent changes
argument-hint: [optional focus, e.g. "the coach" or "since HEAD~3"]
---
Update the project's long-term memory — the Obsidian wiki at `docs/wiki/` — so it
reflects the current state of the codebase. The wiki is the durable memory of *why*
the app is the way it is; code is the source of truth for *how*.

Do this:

1. **Find what changed.** Run `git log --oneline -15` and `git diff --stat HEAD~5..HEAD`
   (or narrow to the focus in `$ARGUMENTS` if given). Skim the relevant changed files
   so you're recording reality, not assumptions.

2. **Update the affected notes** in `docs/wiki/`:
   - New subsystem/feature → create or update its note, and link it from `Home.md`.
   - A decision or trade-off → prepend a dated bullet to `docs/wiki/Decisions.md`
     (newest first) with the *why*.
   - Status or scope change → update the Status section in `Home.md` and `Roadmap.md`.
   - Changed tuning constants or behavior → update the relevant note and the
     constants block in `Decisions.md`.

3. **Keep it Obsidian-idiomatic and concise:** `[[wikilinks]]` between notes,
   frontmatter with `tags` and an `updated:` date, link to code paths rather than
   pasting code. Don't duplicate the design doc — link to it.

4. **Don't invent.** Record only what the commits/code actually show. If something is
   uncertain or undecided, write it as an open question, not a fact.

5. **Summarize, then commit.** Print a short list of what you changed, then commit the
   wiki edits with a clear message (wiki-only commit unless I say otherwise).
