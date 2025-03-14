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

# Load game state or initialize it
def load_game_state
  if File.exist?(STATE_FILE)
    JSON.parse(File.read(STATE_FILE), symbolize_names: true)
  else
    default_state = {
      player1: { name: 'Player 1', cp: 1, primary: 0, secondary: 0, role: 'Attacker', army: '', detachment: '' },
      player2: { name: 'Player 2', cp: 1, primary: 0, secondary: 0, role: 'Defender', army: '', detachment: '' },
      turn: 1,
      phase: 'Top',
      winner: nil
    }
    File.write(STATE_FILE, JSON.pretty_generate(default_state))
    default_state
  end
end

def save_game_state(state)
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
  slim :admin, locals: { game_state: load_game_state, factions: FACTIONS }
end

post '/reset_game' do
  default_state = {
    player1: { name: 'Player 1', cp: 1, primary: 0, secondary: 0, role: 'Attacker', army: '', detachment: '' },
    player2: { name: 'Player 2', cp: 1, primary: 0, secondary: 0, role: 'Defender', army: '', detachment: '' },
    turn: 1,
    phase: 'Top',
    winner: nil
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

  player_key = data["player"] == "Player 1" ? :player1 : :player2
  game_state[player_key][:name] = data["name"] if data["name"]
  game_state[player_key][:role] = data["role"] if data["role"]
  game_state[player_key][:army] = data["army"] if data["army"]
  game_state[player_key][:detachment] = data["detachment"] if data["detachment"]

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
  data = JSON.parse(request.body.read)
  player_key = data["player"].downcase.to_sym

  missions = JSON.parse(File.read("secondary_missions.json"))["cards"]
  selected_missions = missions.keys.sample(2)

  game_state[player_key][:missions] = selected_missions

  save_game_state(game_state)

  content_type :json
  { success: true, missions: selected_missions.map { |m| { name: m, description: missions[m] } } }.to_json
end

post '/discard_mission' do
  game_state = load_game_state
  request.body.rewind
  data = JSON.parse(request.body.read)
  player_key = data["player"].downcase.to_sym
  slot = data["slot"].to_i - 1

  missions = JSON.parse(File.read("secondary_missions.json"))["cards"]
  new_mission = (missions.keys - game_state[player_key][:missions]).sample

  game_state[player_key][:missions][slot] = new_mission

  save_game_state(game_state)

  content_type :json
  { success: true, missions: game_state[player_key][:missions].map { |m| { name: m, description: missions[m] } } }.to_json
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
