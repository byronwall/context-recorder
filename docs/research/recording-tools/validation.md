# Research validation

Checked October 14, 2026, against baseline `6c74158ca96abd36819d2a58f75bacdc44107bb0`.
The app source still matches that baseline. This run changes research and planning files only.

## Collected evidence

The [collection manifest](collection-manifest.json) records eight original files and their hashes.
ZIP CRC, paths, duplicate entries, symlink exclusion, and extracted bytes passed checks.
All seven standalone companions equal the corresponding archive members.

The [package validation](package-validation.json) records these independent checks:

- 32 unique product IDs, 18 detailed profiles, and six categories.
- 46 feature columns with valid states and source references for resolved cells.
- 99 external source IDs, 16 gap IDs, and ten complete recommendation records.
- Recommendation dependency, gap, proof, and source IDs resolve.
- Seventy repository path/range/symbol locators resolve.
- All 48 source packet files match their recorded hashes. Baseline files were checked against Git objects.
- All six scoped searches reproduce the reported matching-line counts.

The checker lived at `tmp/recording-tools/verify-package.py` during this run.
These checks establish package consistency, not the truth of every product claim.
Independent decisive-claim checks are listed in [research-review.md](research-review.md).

## Sleuth and document checks

The canonical skill template initialized the map. All map edits used `scripts/update-map.mjs`.

Commands:

```sh
node /Users/byronwall/.agents/skills/software-design-sleuth-full/scripts/validate-sleuth.mjs docs/intent/recording-tools
node /Users/byronwall/.agents/skills/software-design-sleuth-full/scripts/audit-sleuth.mjs docs/intent/recording-tools
git diff main --check -- . ':!docs/research/recording-tools/pro-output'
git -c core.whitespace=-blank-at-eol,cr-at-eol diff main --check -- docs/research/recording-tools/pro-output
```

The validator passed with zero warnings. The heuristic audit scored 9.6/10.
Its remaining suggestion concerns a reproducible local proof command. The plan explicitly identifies that command as future, nonexistent work.
Implementing the fixture runner belongs to a later authorized application change.
The score is a document heuristic, not proof of buildability or user value.

Local Markdown links resolve. The three milestone titles match the map and the plan.
All milestones and the initiative remain planned. Their observed-product-evidence arrays are empty.
All ten recommendations have explicit adopt, investigate, or defer dispositions; broader expansion proposals are rejected by default.
Seven brainstorming options retain distinct premises. The main shape includes a scope tree and a rejectable first proof.

Authored files pass ordinary whitespace checks.
Unrestricted `git diff main --check` reports original Markdown hard breaks and CSV CRLF endings.
The originals remain byte-identical. The second scoped command permits their preserved format and passes other whitespace checks.
No repository-wide whitespace setting was changed.

## Semantic review

The plan does not silently select personal review as Byron's goal.
It details two repairs to existing behavior and a focused decision spike.
Detailed search/export architecture waits for the primary-job and content-scope choices.
The stronger no-build alternative includes existing marks, native notes, and editor Find.

Original media and context remain authoritative. Intentional review edits remain permitted in the existing mutable mark file.
Source-kind labels, approximate time, and unverified feature cells retain their limits.
The prior video-to-canvas vision remains separate and unapproved by this research.

## Not run

No Swift build, native UI harness, capture, permission change, speech inference, PGM export, or timed comparison ran.
No product installation, purchase, or vendor message occurred.
No proposed canary, recovery, performance, or source-mapping test ran.
No application change, merge, deployment, or planning-file retirement occurred.

Git and PR completion evidence is recorded in [run.md](run.md).
