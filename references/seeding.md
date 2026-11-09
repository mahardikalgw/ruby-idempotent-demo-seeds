# Seeding details

## Aggregates and analytics

A metric row per day is the trap: `Metric.create!(date: date, value: ...)` inside a loop appends a second
year of rows on every replant. Key the row by the pair a human would use:

```ruby
(SEED_START..SEED_END).each do |date|
  metric = DailyMetric.find_or_initialize_by(workspace: workspace, recorded_on: date)
  metric.assign_attributes(page_views: 200, revenue_cents: 900, sessions_count: 500)
  metric.save!
end
```

Distributing a total across dates must be deterministic too:

```ruby
# put the remainder on the earliest days so the same total always lands the same way
distribute = lambda do |dates, total|
  base, remainder = total.divmod(dates.length)
  dates.each_with_index.map { |date, index| [ date, base + (index < remainder ? 1 : 0) ] }
end
```

## Counters and sequences

A ticket number comes from a counter table. Seeding must advance the counter past the seeded numbers, or
the first real ticket after a demo collides:

```ruby
HelpdeskDemoData::TICKETS.each do |attrs|
  ticket = Ticket.find_or_initialize_by(ticket_number: attrs[:number])
  ticket.assign_attributes(attrs.except(:number), workspace: workspace, requester: requester, created_by: requester)
  ticket.save!
end

# move the counter to the highest seeded sequence, never past it
highest = Ticket.maximum(:ticket_number).to_s.split("-").last.to_i
TicketCounter.where(workspace: workspace).update_all(value: highest) if highest.positive?
```

Or, simpler and safer: create seeded tickets through the real service, so the counter is advanced by the
code that owns it. Seed data that bypasses the domain is seed data that can create a state the product
cannot produce.

## Notifications and events

A seeded ticket with no timeline looks broken on the detail page. Seed the events the workflow would have
written:

```ruby
create_event(ticket: ticket, event_type: "ticket_created", actor: requester)
create_event(ticket: ticket, event_type: "status_changed", actor: agent,
             previous: { from_status: "open" }, new: { to_status: "in_progress" })
```

Idempotency: `TicketEvent.find_or_create_by!(ticket: ticket, event_type: "ticket_created")` — events are
append-only in production, so the seed must not append a second one.

## Files and attachments

```ruby
unless ticket.files.attached?
  ticket.files.attach(io: StringIO.new("Bukti tangkapan layar"), filename: "bukti.txt", content_type: "text/plain")
end
```

`attach` appends. Guard on `attached?`, and always pass `content_type` explicitly so a validator that
checks it is exercised by the demo data too.

## Replant versus idempotent

Two different guarantees, both worth having:

| Command | Guarantee |
|---|---|
| `bin/rails db:seed` (twice) | the dataset is unchanged |
| `bin/rails db:seed:replant` | the dataset is rebuilt from empty, identically |
| `db:seed:replant db:test:prepare` | the test database is clean afterwards |

`replant` truncates first, which hides a non-idempotent seed. That is why the double-`db:seed` test is the
one that matters.

## Verification task

```ruby
namespace :demo do
  desc "Report the seeded demo dataset (counts by role and status)"
  task verify: :environment do
    puts "users:   #{User.group(:role).count}"
    puts "tickets: #{Ticket.group(:status).count}"
    puts "notes:   #{TicketComment.group(:visibility).count}"
    puts "files:   #{ActiveStorage::Attachment.count}"
  end
end
```

A report beats a screenshot: after replanting a month later, the counts tell you whether the dataset still
covers every role and state.

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| Duplicate rows after a second `db:seed` | `create!` in a loop | `find_or_initialize_by` on a natural key |
| `PG::UniqueViolation` on replant | a natural key collides with a survivor row | seed inside a transaction, or replant then prepare |
| Dates shifted between runs | `Time.current` in the seed | fixed date constants |
| First real ticket collides with a demo one | counter not advanced | seed through the service, or advance the counter |
| Test suite fails after `seed:replant` | orphans left in the test database | `db:test:prepare` at the end of the step |
| Detail page looks broken on demo data | no events or notifications seeded | seed the timeline the workflow would have written |
