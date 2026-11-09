# Idempotent demo seeds

Write deterministic, idempotent demo seed data for a Rails app so the dataset can be replanted safely — natural keys instead of appends, fixed dates instead of now, every role and workflow state represented, plus the test-environment pairing that keeps CI green. Use when adding demo data, a new seeded record type, or when seeds break the test suite.

One skill, one repository. Part of a twelve-skill pack extracted from a production Rails 8 +
Inertia + React helpdesk monolith — the opinionated layer no public Rails or shadcn skill can know.
Version `2.0.0` tracks the source constitution.

## Install

```jsonc
// skills-lock.json
{
  "version": 1,
  "skills": {
    "idempotent-demo-seeds": {
      "source": "mahardikalgw/idempotent-demo-seeds",
      "sourceType": "github",
      "skillPath": "SKILL.md"
    }
  }
}
```

Or clone and symlink:

```bash
git clone git@github.com:mahardikalgw/idempotent-demo-seeds.git
ln -s "$PWD/idempotent-demo-seeds" .claude/skills/idempotent-demo-seeds
```

## When to activate

- Adding a seeded record type, account, or workflow state.
- A demo dataset needs a new role, team, or edge case.
- `RAILS_ENV=test bin/rails db:seed:replant` breaks the test suite.
- Reviewing a seeds diff.

## What's inside

```
idempotent-demo-seeds/
  SKILL.md
  assets/seeds_skeleton.rb
  references/seeding.md
```

`SKILL.md` is a router (kept under 250 lines) — the depth lives in `references/`, and the
copy-in code lives in `assets/`.

## Validate

```bash
./bin/check-skill
```

Checks frontmatter, the activation section, link resolution, orphaned references, script
executability, leftover placeholders, and — when the source app is checked out next to this
repository — that vendored scripts still match it byte for byte. Runs in CI on every push.

## Related skills

- [`postgres-pgvector-baseline`](https://github.com/mahardikalgw/postgres-pgvector-baseline) — PostgreSQL 16 + pgvector everywhere, Solid stores, the fresh-clone traps
- [`merge-gate-parity`](https://github.com/mahardikalgw/merge-gate-parity) — one gate list in every file, a script contract, and local/CI triage

## Licence

MIT — see [LICENSE](LICENSE).
