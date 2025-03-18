require 'sinatra'
require 'slim'
require 'json'
require 'sinatra/reloader' if development?
require 'fileutils'

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


# Load game state or initialize it
def load_game_state
  if File.exist?(STATE_FILE) && !File.zero?(STATE_FILE)
    begin
      JSON.parse(File.read(STATE_FILE), symbolize_names: true)
    rescue JSON::ParserError
      puts "⚠️ Corrupt game_state.json detected, resetting..."
      initialize_default_game_state
    end
  else
    initialize_default_game_state
  end
end

def initialize_default_game_state
  default_state = {
    player1: { name: 'Player 1', cp: 1, primary: 0, secondary: 0, role: 'Attacker', army: '', detachment: '' },
    player2: { name: 'Player 2', cp: 1, primary: 0, secondary: 0, role: 'Defender', army: '', detachment: '' },
    turn: 1,
    phase: 'Top',
    winner: nil,
    deployment: nil,
    mission_rule: nil,
    primary_mission: nil
  }
  save_game_state(default_state)
  default_state
end


def save_game_state(state)
  # Replace nil values with empty strings
  state.each do |key, value|
    if value.is_a?(Hash)
      value.each { |k, v| value[k] = "" if v.nil? }
    else
      state[key] = "" if value.nil?
    end
  end
  File.write(STATE_FILE, JSON.pretty_generate(state))
end


# Routes
get '/' do
  slim :index, locals: { game_state: load_game_state }
end

get '/player' do
  slim :player, locals: { game_state: load_game_state }
end

get '/admin' do
  slim :admin, locals: { game_state: load_game_state, factions: FACTIONS, mission_rules: MISSION_RULES, primary_missions: PRIMARY_MISSIONS }
end


post '/reset_game' do
  default_state = {
    player1: { name: 'Player 1', cp: 1, primary: 0, secondary: 0, role: 'Attacker', army: '', detachment: '' },
    player2: { name: 'Player 2', cp: 1, primary: 0, secondary: 0, role: 'Defender', army: '', detachment: '' },
    turn: 1,
    phase: 'Top',
    winner: nil,
    deployment: nil,
    mission_rule: nil,  # ✅ Ensure it resets properly
    primary_mission: nil # ✅ Also reset primary mission
  }
  save_game_state(default_state)
  content_type :json
  { success: true }.to_json
end



post '/pass_turn' do
  game_state = load_game_state

  if game_state[:turn] <= 5
    if game_state[:phase] == 'Top'
      game_state[:phase] = 'Bottom'
    else
      game_state[:phase] = 'Top'
      game_state[:turn] += 1
    end

    # Increase CP for both players *ONLY* if the game isn't over
    if game_state[:turn] <= 5
      game_state[:player1][:cp] += 1
      game_state[:player2][:cp] += 1
    end
  end

  # Determine winner only if game is over
  if game_state[:turn] > 5 && !game_state[:winner]
    p1_total = game_state[:player1][:primary] + game_state[:player1][:secondary]
    p2_total = game_state[:player2][:primary] + game_state[:player2][:secondary]

    game_state[:winner] = if p1_total > p2_total
                            game_state[:player1][:name]
                          elsif p2_total > p1_total
                            game_state[:player2][:name]
                          else
                            "Draw"
                          end
  end

  save_game_state(game_state)
  content_type :json
  { success: true, game_state: game_state }.to_json
end

get '/game_state.json' do
  content_type :json
  if File.exist?(STATE_FILE) && !File.zero?(STATE_FILE)
    File.read(STATE_FILE)
  else
    status 500
    { error: "Invalid game state" }.to_json
  end
end

get '/secondary_missions.json' do
  content_type :json
  if File.exist?(SECONDARY_FILE) && !File.zero?(SECONDARY_FILE)
    File.read(SECONDARY_FILE)
  else
    status 500
    { error: "Missing Secondaries" }.to_json
  end
end

post '/update_score' do
  game_state = load_game_state
  data = JSON.parse(request.body.read) rescue {}

  player_key = data['player'] == 'Player 1' ? :player1 : :player2
  field = data['field'].to_sym
  value = data['value'].to_i

  if game_state[player_key].key?(field)
    game_state[player_key][field] += value
    save_game_state(game_state)
  end

  content_type :json
  { success: true, game_state: game_state }.to_json
end

post '/update_admin' do
  game_state = load_game_state
  data = JSON.parse(request.body.read) rescue {}

  if data["player"]
    player_key = data["player"] == "Player 1" ? :player1 : :player2
    game_state[player_key][:name] = data["name"] if data["name"]
    game_state[player_key][:role] = data["role"] if data["role"]
    game_state[player_key][:army] = data["army"] if data["army"]
    game_state[player_key][:detachment] = data["detachment"] if data["detachment"]
  end

  # Prevent resetting the entire game state when updating deployment
  if data["field"] == "deployment" && data["value"]
    game_state[:deployment] = data["value"]  # Only update this field, leave everything else untouched
  end

  if data["field"] == "mission_rule" && data["value"]
    game_state[:mission_rule] = data["value"]
  end

  save_game_state(game_state)
  content_type :json
  { success: true, game_state: game_state }.to_json
end


post '/end_game' do
  game_state = load_game_state

  if !game_state[:winner]
    p1_total_vp = game_state[:player1][:primary] + game_state[:player1][:secondary]
    p2_total_vp = game_state[:player2][:primary] + game_state[:player2][:secondary]

    game_state[:winner] = if p1_total_vp > p2_total_vp
                            game_state[:player1][:name]
                          elsif p2_total_vp > p1_total_vp
                            game_state[:player2][:name]
                          else
                            "Draw"
                          end

    game_state[:game_over] = true
    save_game_state(game_state)
  end

  content_type :json
  { success: true, game_state: game_state }.to_json
end

post '/draw_missions' do
  game_state = load_game_state
  request.body.rewind
  data = JSON.parse(request.body.read) rescue {}
  player_key = data["player"].downcase.to_sym

  missions = JSON.parse(File.read(SECONDARY_FILE))["cards"]
  selected_missions = missions.keys.sample(2)

  game_state[player_key][:missions] ||= [] # Ensure missions array exists
  game_state[player_key][:missions] = selected_missions

  save_game_state(game_state)

  content_type :json
  { success: true, missions: selected_missions.map { |m| { name: m, description: missions[m] } } }.to_json
end

post '/discard_mission' do
  game_state = load_game_state
  request.body.rewind
  data = JSON.parse(request.body.read) rescue {}
  player_key = data["player"].downcase.to_sym
  slot = data["slot"].to_i - 1

  missions = JSON.parse(File.read(SECONDARY_FILE))["cards"]
  available_missions = missions.keys - game_state[player_key][:missions]

  if available_missions.any?
    new_mission = available_missions.sample
    game_state[player_key][:missions][slot] = new_mission
  else
    puts "⚠️ No more missions available to draw!"
  end

  save_game_state(game_state)

  content_type :json
  { success: true, missions: game_state[player_key][:missions].map { |m| { name: m, description: missions[m] } } }.to_json
end

post '/update_game_state' do
  game_state = load_game_state
  data = JSON.parse(request.body.read) rescue {}

  puts "🔍 Received Data: #{data}"  # Debugging log

  if data["player"]
    # Update player-specific fields
    player_key = data["player"] == "Player 1" ? :player1 : :player2
    field = data["field"].to_sym

    if game_state[player_key].key?(field)
      game_state[player_key][field] = data["value"]
      puts "✅ Player Update: #{player_key} => #{field} = #{data["value"]}"
    else
      puts "❌ Invalid Player Field: #{field}"
    end
  elsif data["field"] && data["value"]
    # Update global game state fields (ensure they exist)
    allowed_global_fields = ["deployment", "primary_mission", "mission_rule"]
    if allowed_global_fields.include?(data["field"])
      game_state[data["field"].to_sym] = data["value"]
      puts "✅ Updated #{data["field"]}: #{game_state[data["field"].to_sym]}"
    else
      puts "❌ Invalid Global Field: #{data["field"]}"
    end
  else
    puts "❌ No valid field found in request!"
  end

  # Ensure all game state fields exist
  game_state[:deployment] ||= ""
  game_state[:primary_mission] ||= ""
  game_state[:mission_rule] ||= ""

  save_game_state(game_state)

  puts "✅ Final Game State: #{game_state}"  # Debugging log

  content_type :json
  { success: true, game_state: game_state }.to_json
end

get '/overlay' do
  slim :overlay, locals: { game_state: load_game_state }
end

get '/application.css' do
  scss :application
end

set :environment, :production
set :bind, '0.0.0.0'
set :port, 4567
set :views, File.dirname(__FILE__) + '/views'
