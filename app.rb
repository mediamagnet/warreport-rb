require 'sinatra'
require 'slim'
require 'json'
require 'sinatra/reloader' if development?
require 'fileutils'
require 'faye/websocket'
require 'thread'

STATE_FILE = 'game_state.json'
SECONDARY_FILE = 'secondary_missions.json'

FACTIONS = {
  "Imperium" => [
    "Adepta Sororitas", "Adeptus Custodes", "Adeptus Mechanicus", "Adeptus Titanicus",
    "Astra Militarum", "Grey Knights", "Imperial Agents", "Imperial Knights", "Adeptus Astartes"
  ],
  "Chaos" => [
    "Chaos Daemons", "Chaos Knights", "Chaos Space Marines", "Death Guard", "Thousand Sons", "World Eaters"
  ],
  "Xenos" => [
    "Aeldari", "Drukhari", "Genestealer Cults", "Leagues of Votann", "Necrons", "Orks", "T'au Empire", "Tyranids"
  ],
  "Unaligned" => ["Unaligned Forces"]
}

MISSION_RULES = {
  "Inspired Leadership" => "While a player’s WARLORD is not within their deployment zone, each time a unit from that player’s army takes a Battle-shock test...",
  "Rapid Escalation" => "In the first battle round, each player can set up BATTLELINE units from Strategic Reserves...",
  "Smoke and Mirrors" => "After both players have deployed their armies, starting with the Attacker, each player can place one unit from their army...",
  "Hidden Supplies" => "Reconnaissance units have uncovered a hidden cache of ammunition, fuel and rations in this war zone...",
  "Raise Banners" => "At the end of each player’s turn, if a BATTLELINE unit from their army is within range of an objective marker...",
  "Stalwarts" => "BATTLELINE units that perform an Action are still eligible to shoot in that turn...",
  "Adapt or Die" => "Once per battle, at the end of that player’s turn, after scoring any VP, they can discard one of their Secondary Mission cards...",
  "Swift Action" => "BATTLELINE units that Advance or Fall Back are still eligible to perform an Action in that turn...",
  "Fog of War" => "In the first battle round, units have the Benefit of Cover, and players cannot use Core Stratagems...",
  "Prepared Positions" => "Players can target their BATTLELINE units with the Go to Ground and Heroic Intervention Stratagems for 0CP..."
}

PRIMARY_MISSIONS = {
  "PURGE THE FOE" => "Each player scores 4VP if one or more enemy units were destroyed this battle round...",
  "LINCHPIN" => "If the player whose turn it is does not control the objective marker in their deployment zone...",
  "SCORCHED EARTH" => "What cannot be secured must be burned to ash...",
  "UNEXPLODED ORDNANCE" => "Volatile undetonated material lies in your path...",
  "SUPPLY DROP" => "Supplies are inbound. Secure the drop coordinates...",
  "TERRAFORM" => "Victory here lies in dominating not only the foe, but also the landscape of the battlefield itself...",
  "BURDEN OF TRUST" => "The strategic prizes in this region must be guarded at all costs...",
  "TAKE AND HOLD" => "Several strategic locations have been identified in your vicinity...",
  "THE RITUAL" => "Bitter foes clash in a race to finish a ritual to either sanctify or corrupt the battlefield..."
}

$connections = []


# WebSocket endpoint
get '/ws' do
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)

    ws.on :open do |_|
      $connections << ws
      puts "🟢 WebSocket connected (#{$connections.size} total)"
    end

    ws.on :close do |_|
      $connections.delete(ws)
      puts "🔴 WebSocket disconnected (#{$connections.size} remaining)"
    end

    ws.rack_response
  else
    status 426
    body "WebSocket connection required."
  end
end

# Broadcast helper
def broadcast_state(state)
  puts "📡 Broadcasting state to #{$connections&.size || 0} connections"
  $connections ||= []
  $connections.each do |ws|
    ws.send(state.to_json)
  end
end

# Game state loading/saving
def load_game_state
  if File.exist?(STATE_FILE) && !File.zero?(STATE_FILE)
    begin
      File.open(STATE_FILE, 'r') do |file|
        file.flock(File::LOCK_SH)
        data = file.read
        file.flock(File::LOCK_UN)
        return JSON.parse(data, symbolize_names: true)
      end
    rescue JSON::ParserError
      puts "⚠️ Corrupt game_state.json detected!"
      return restore_from_backup
    end
  else
    initialize_default_game_state
  end
end

def restore_from_backup
  backup_file = "#{STATE_FILE}.bak"
  if File.exist?(backup_file) && !File.zero?(backup_file)
    begin
      backup_data = File.read(backup_file)
      parsed_backup = JSON.parse(backup_data, symbolize_names: true)
      puts "✅ Recovered from backup."
      save_game_state(parsed_backup)  # Rewrite current state
      return parsed_backup
    rescue JSON::ParserError
      puts "❌ Backup file also corrupt. Resetting to default state..."
    end
  else
    puts "❌ No backup available. Resetting to default state..."
  end

  initialize_default_game_state
end

def initialize_default_game_state
  default_state = {
    player1: { name: 'Player 1', cp: 1, primary: 0, secondary: 0, role: 'Attacker', army: '', detachment: '', missions: [] },
    player2: { name: 'Player 2', cp: 1, primary: 0, secondary: 0, role: 'Defender', army: '', detachment: '', missions: [] },
    turn: 1,
    phase: 'Top',
    winner: nil,
    game_over: false,
    deployment: '',
    mission_rule: '',
    primary_mission: ''
  }
  save_game_state(default_state)
  default_state
end

def save_game_state(state)
  state.each do |key, value|
    if value.is_a?(Hash)
      value.each { |k, v| value[k] = "" if v.nil? }
    else
      state[key] = "" if value.nil?
    end
  end

  json_data = JSON.pretty_generate(state)

  File.open(STATE_FILE, 'w') do |file|
    file.flock(File::LOCK_EX)
    file.write(json_data)
    file.flock(File::LOCK_UN)
  end

  # Also write to a backup
  File.write("#{STATE_FILE}.bak", json_data)
end

# Routes
get '/' do
  slim :index, locals: { game_state: load_game_state }
end

get '/player' do
  slim :player, locals: { game_state: load_game_state }
end

get '/admin' do
  slim :admin, locals: {
    game_state: load_game_state,
    factions: FACTIONS,
    mission_rules: MISSION_RULES,
    primary_missions: PRIMARY_MISSIONS
  }
end

get '/overlay' do
  slim :overlay, locals: { game_state: load_game_state }
end

get '/application.css' do
  scss :application
end

get '/game_state.json' do
  content_type :json
  File.read(STATE_FILE)
end

post '/reset_game' do
  state = initialize_default_game_state

  # Explicitly clear any leftover fields
  state[:winner] = nil
  state[:game_over] = false

  save_game_state(state)
  broadcast_state(state)

  content_type :json
  { success: true }.to_json
end

post '/pass_turn' do
  state = load_game_state

  if state[:turn] <= 5
    if state[:phase] == 'Top'
      state[:phase] = 'Bottom'
    else
      state[:phase] = 'Top'
      state[:turn] += 1
      # Add CP only at the top of a turn
      if state[:turn] <= 5
        state[:player1][:cp] += 1
        state[:player2][:cp] += 1
      end
    end
  end

  # ✅ Only declare winner at end of Turn 5 Bottom phase or beyond
  if (state[:turn] > 5 || (state[:turn] == 5 && state[:phase] == "Bottom")) && !state[:winner]
    p1 = state[:player1][:primary] + state[:player1][:secondary]
    p2 = state[:player2][:primary] + state[:player2][:secondary]

    state[:winner] = if p1 > p2
      state[:player1][:name]
    elsif p2 > p1
      state[:player2][:name]
    else
      "Draw"
    end

    state[:game_over] = true
  end

  save_game_state(state)
  broadcast_state(state)
  content_type :json
  { success: true, game_state: state }.to_json
end

post '/update_score' do
  state = load_game_state
  data = JSON.parse(request.body.read) rescue {}
  key = data['player'] == 'Player 1' ? :player1 : :player2
  field = data['field'].to_sym
  state[key][field] += data['value'].to_i
  save_game_state(state)
  broadcast_state(state)
  content_type :json
  { success: true, game_state: state }.to_json
end

post '/update_admin' do
  state = load_game_state
  data = JSON.parse(request.body.read) rescue {}

  if data["player"]
    player_key = data["player"] == "Player 1" ? :player1 : :player2
    field = data["field"]
    value = data["value"]

    # Only allow known fields to be written to player block
    if [:name, :role, :army, :detachment].include?(field&.to_sym)
      state[player_key][field.to_sym] = value
    else
      puts "⚠️ Ignored unrecognized player field: #{field}"
    end
  elsif data["field"] && data["value"]
    # Global fields like mission_rule, deployment
    allowed_global_fields = %w[deployment mission_rule primary_mission]
    if allowed_global_fields.include?(data["field"])
      state[data["field"].to_sym] = data["value"]
    else
      puts "⚠️ Ignored unrecognized global field: #{data["field"]}"
    end
  end

  save_game_state(state)
  broadcast_state(state)
  content_type :json
  { success: true, game_state: state }.to_json
end

post '/update_game_state' do
  state = load_game_state
  data = JSON.parse(request.body.read) rescue {}

  if data["player"]
    key = data["player"] == "Player 1" ? :player1 : :player2
    field = data["field"].to_sym
    state[key][field] = data["value"]
  elsif data["field"] && data["value"]
    state[data["field"].to_sym] = data["value"]
  end

  save_game_state(state)
  broadcast_state(state)
  content_type :json
  { success: true, game_state: state }.to_json
end

post '/draw_missions' do
  state = load_game_state
  data = JSON.parse(request.body.read) rescue {}
  player = data["player"].downcase.to_sym
  cards = JSON.parse(File.read(SECONDARY_FILE))["cards"]
  draw = cards.keys.sample(2)
  state[player][:missions] = draw
  save_game_state(state)
  broadcast_state(state)
  content_type :json
  { success: true, missions: draw.map { |m| { name: m, description: cards[m] } } }.to_json
end

post '/discard_mission' do
  state = load_game_state
  data = JSON.parse(request.body.read) rescue {}
  player = data["player"].downcase.to_sym
  index = data["slot"].to_i - 1
  cards = JSON.parse(File.read(SECONDARY_FILE))["cards"]
  available = cards.keys - state[player][:missions]
  if available.any?
    state[player][:missions][index] = available.sample
  end
  save_game_state(state)
  broadcast_state(state)
  content_type :json
  { success: true, missions: state[player][:missions].map { |m| { name: m, description: cards[m] } } }.to_json
end

post '/end_game' do
  state = load_game_state
  unless state[:winner]
    p1 = state[:player1][:primary] + state[:player1][:secondary]
    p2 = state[:player2][:primary] + state[:player2][:secondary]
    state[:winner] = p1 > p2 ? state[:player1][:name] : (p2 > p1 ? state[:player2][:name] : "Draw")
    state[:game_over] = true
  end
  save_game_state(state)
  broadcast_state(state)
  content_type :json
  { success: true, game_state: state }.to_json
end

# Sinatra settings
set :environment, :production
set :bind, '0.0.0.0'
set :port, 4567
set :views, File.dirname(__FILE__) + '/views'