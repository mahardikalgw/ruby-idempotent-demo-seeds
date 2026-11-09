# Copy into db/seeds.rb. Deterministic and idempotent: re-running must never duplicate or corrupt a
# record, so every write is keyed on a natural key and re-assigned rather than appended.
require Rails.root.join("lib/demo_data").to_s

# --- Workspace -------------------------------------------------------------
workspace = Workspace.find_or_create_by!(name: DemoData::WORKSPACE_NAME) do |record|
  record.plan = DemoData::PLAN
  record.currency = DemoData::CURRENCY
end

settings = HelpdeskSetting.for(workspace)
settings.update!(reopen_days: 14)

# --- Accounts (one per role, plus a role scoped to a subset) ---------------
DemoData::ACCOUNTS.each do |attrs|
  user = User.find_or_initialize_by(email_address: attrs[:email])
  user.assign_attributes(name: attrs[:name], role: attrs[:role], workspace: workspace, active: true)
  user.password = DemoData::PASSWORD if user.new_record?
  user.save!
end

requester = User.find_by!(email_address: DemoData::REQUESTER_EMAIL)
agent     = User.find_by!(email_address: DemoData::AGENT_EMAIL)
leader    = User.find_by!(email_address: DemoData::LEADER_EMAIL)

# --- Teams (a leader scoped to exactly one team, so the scope is demonstrable) ---
team = SupportTeam.find_or_initialize_by(workspace: workspace, name: DemoData::TEAM_NAME)
team.description = DemoData::TEAM_DESCRIPTION
team.save!

other_team = SupportTeam.find_or_initialize_by(workspace: workspace, name: DemoData::SECOND_TEAM_NAME)
other_team.save!

SupportTeamMembership.find_or_create_by!(support_team: team, user: agent)
SupportTeamMembership.find_or_create_by!(support_team: team, user: leader, team_leader: true)

# --- Categories and services ----------------------------------------------
DemoData::CATEGORIES.each do |name, security_sensitive|
  category = Category.find_or_initialize_by(workspace: workspace, name: name)
  category.security_sensitive = security_sensitive
  category.save!
end

DemoData::SERVICES.each do |name|
  Service.find_or_create_by!(workspace: workspace, name: name)
end

# --- Tickets: one per status, with the timeline the workflow would have written ---
DemoData::TICKETS.each do |attrs|
  ticket = Ticket.find_or_initialize_by(workspace: workspace, ticket_number: attrs[:number])
  next unless ticket.new_record? # seeded through the model below; never re-time a live row

  ticket.assign_attributes(
    requester: requester, created_by: requester,
    category: Category.find_by!(workspace: workspace, name: attrs[:category]),
    title: attrs[:title], description: attrs[:description],
    status: attrs[:status], priority: attrs[:priority],
    assigned_agent: (agent if attrs[:assigned]),
    support_team: (team if attrs[:assigned]),
    restricted: attrs.fetch(:restricted, false),
    resolution_summary: attrs[:resolution_summary],
    created_at: attrs[:created_at], last_activity_at: attrs[:created_at]
  )
  ticket.save!

  TicketEvent.find_or_create_by!(ticket: ticket, event_type: "ticket_created") do |event|
    event.workspace = workspace
    event.actor = requester
    event.new = { ticket_number: ticket.ticket_number }
  end
end

# --- One public reply and one internal note on the same ticket -------------
demo_ticket = Ticket.find_by!(workspace: workspace, ticket_number: "CMP-2026-000001")

{
  public: "Sudah kami coba masuk ulang, masih gagal.",
  internal: "Sudah direset lewat admin console. Menunggu konfirmasi pengguna."
}.each do |visibility, body|
  TicketComment.find_or_create_by!(ticket: demo_ticket, visibility: visibility) do |comment|
    comment.workspace = workspace
    comment.author = (visibility == :public ? requester : agent)
    comment.body = body
  end
end

puts "seed: #{User.count} users, #{Ticket.count} tickets, #{TicketComment.count} comments"
