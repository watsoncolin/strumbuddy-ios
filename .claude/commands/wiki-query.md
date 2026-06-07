---
description: Answer a question from the Obsidian wiki memory (docs/wiki)
argument-hint: <question>
---
Answer the question using the project's long-term memory wiki at `docs/wiki/` as the
primary source — recall before re-deriving.

1. Start from `docs/wiki/Home.md` (the map of content) and open the most relevant
   notes, following `[[wikilinks]]`.
2. Synthesize a grounded answer, citing the notes you drew on (e.g. "per [[The Coach]]").
3. If the wiki doesn't cover it, say so plainly, then fall back to reading the code —
   and suggest running `/wiki-update` to capture what's missing for next time.

Question: $ARGUMENTS
