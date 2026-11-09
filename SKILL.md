---
name: idempotent-demo-seeds
description: Write deterministic, idempotent demo seed data for a Rails app so the dataset can be replanted safely — natural keys instead of appends, fixed dates instead of now, every role and workflow state represented, plus the test-environment pairing that keeps CI green. Use when adding demo data, a new seeded record type, or when seeds break the test suite.
version: 2.0.0
---

# Idempotent demo seeds

A seed file is a **fixture for humans**: the reviewer, the demo, and the screenshot all depend on it. It
runs on every fresh clone and again after every `db:seed:replant`, so it must produce the same database
every time — no duplicates, no `created_at` drift, no orphan rows.

## When to activate

- Adding a seeded record type, account, or workflow state.
- A demo dataset needs a new role, team, or edge case.
- `RAILS_ENV=test bin/rails db:seed:replant` breaks the test suite.
- Reviewing a seeds diff.

## The four rules

### 1. Upsert on a natural key, never append

```ruby
workspace = Workspace.find_or_create_by!(name: DemoData::WORKSPACE_NAME) do |record|
  record.plan = "standard"
  record.currency = "IDR"
end

user = User.find_or_initialize_by(email_address: DemoData::AGENT_EMAIL)
user.assign_attributes(name: DemoData::AGENT_NAME, role: "agent", workspace: workspace)
user.password = DemoData::PASSWORD if user.new_record?
user.save!
```

`create!` twice is a duplicate; `find_or_create_by!` twice is a no-op. Every seeded row gets a key a human
would use to identify it: e-mail address for people, name for teams and categories, a ticket number for
tickets.

### 2. Dates are constants, not `Time.current`

```ruby
# no: every replant shifts every row, and no test can assert on a date
Ticket.create!(…, created_at: Time.current)

# yes: fixed window, reproducible findings
SEED_START = Date.new(2026, 1, 1)
SEED_END   = Date.new(2026, 11, 1)
```

A relative date is fine only when the *feature* is relative (a ticket resolved 3 days ago so a reopen
window is open). Write it as `3.days.ago` and say so in a comment; do not derive the whole dataset from
`now`.

### 3. Constants live in one module

```ruby
# lib/helpdesk_demo_data.rb
module HelpdeskDemoData
  PASSWORD = "helpdesk123"
  REQUESTER_EMAIL = "mahasiswa@example.test"
  AGENT_EMAIL = "agen@example.test"
  LEADER_EMAIL = "ketuatim@example.test"
  SUPERVISOR_EMAIL = "supervisor@example.test"
  ADMIN_EMAIL = "admin@example.test"

  TICKETS = [
    { number: "CMP-2026-000001", title: "Tidak bisa masuk email kampus", status: "in_progress", priority: "high" },
    { number: "CMP-2026-000002", title: "Aplikasi gagal menyimpan data", status: "waiting_requester", priority: "normal" }
  ].freeze
end
```

The seed file, the sign-in hint on the landing page, and the tests all read the same constants, so a
password change cannot leave the README lying.

### 4. Cover the states the product has, not just the happy one

A demo dataset that only contains `open` tickets cannot show a supervisor, a reopen, or a resolution.
Seed at minimum:

- one account per role, plus a role scoped to a subset (a team leader who leads exactly one team);
- one record in **every** status, including the terminal ones;
- one restricted/sensitive record, so the 404 path is demonstrable;
- one internal-only note **and** one public reply on the same record, so the isolation is visible;
- one attachment owned by each audience;
- one record with no assignee and one assigned, so the picker has meaning;
- one record older than a policy window, so a refusal is demonstrable.

## The test-environment trap

```bash
RAILS_ENV=test bin/rails db:seed:replant
```

Replanting truncates and re-seeds, but rows committed outside the seed's own transaction survive as
orphans. The next `bin/rails test` then fails fixture foreign-key validation on rows nobody created.
**Always pair it** — exactly as CI does:

```ruby
step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant db:test:prepare"
```

The order matters: replant, then prepare. Reversed, the prepare runs before the orphans exist.

## The seeds test

```ruby
class SeedsTest < ActiveSupport::TestCase
  test "seeding twice produces the same dataset" do
    counts = -> { [ Workspace.count, User.count, Ticket.count, TicketEvent.count ] }

    Rails.application.load_seed
    first = counts.call
    Rails.application.load_seed

    assert_equal first, counts.call
  end

  test "every role and every status is represented" do
    Rails.application.load_seed

    assert_equal User::ROLES.sort, User.pluck(:role).uniq.sort
    assert_equal Ticket::STATUSES.sort, Ticket.pluck(:status).uniq.sort
  end

  test "the internal note and the public reply share a record" do
    Rails.application.load_seed

    ticket = Ticket.find_by!(ticket_number: "CMP-2026-000001")
    assert_equal %w[internal public], ticket.comments.pluck(:visibility).uniq.sort
  end
end
```

The double-seed assertion is the one that catches an accidental `create!` in a new block.

## References

- [references/seeding.md](references/seeding.md) — aggregate seeds, idempotent counters, and verification tasks
- [assets/seeds_skeleton.rb](assets/seeds_skeleton.rb) — a seed file to adapt
