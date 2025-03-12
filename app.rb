require 'sinatra'
require 'slim'
require 'json'
require 'sinatra/reloader' if development?
require 'fileutils'

STATE_FILE = 'game_state.json'
FACTIONS = {
  "Imperium" => [
    "Adepta Sororitas", "Adeptus Custodes", "Adeptus Mechanicus", "Adeptus Titanicus",
    "Astra Militarum", "Grey Knights", "Imperial Agents", "Imperial Knights", "Space Marines"
  ],
  "Chaos" => [
    "Chaos Daemons", "Chaos Knights", "Chaos Space Marines", "Death Guard", "Thousand Sons", "World Eaters"
  ],
  "Xenos" => [
    "Aeldari", "Drukhari", "Genestealer Cults", "Leagues of Votann", "Necrons", "Orks", "T\'au Empire", "Tyranids"
  ],
  "Unaligned" => ["Unaligned Forces"]
}


# Initialize game state file if not present
def load_game_state
  if File.exist?(STATE_FILE)
    JSON.parse(File.read(STATE_FILE), symbolize_names: true)
  else
    default_state = {
      player1: { name: 'Player 1', cp: 0, primary: 0, secondary: 0, role: 'Attacker', army: '', detachment: '' },
      player2: { name: 'Player 2', cp: 0, primary: 0, secondary: 0, role: 'Defender', army: '', detachment: '' },
      turn: 1,
      phase: 'Top'
    }
    File.write(STATE_FILE, JSON.pretty_generate(default_state))
    default_state
  end
end

def save_game_state(state)
  File.write(STATE_FILE, JSON.pretty_generate(state))
end

game_state = load_game_state

# Home - Scoreboard UI
get '/' do
  game_state = load_game_state
  slim :index, locals: { game_state: game_state }
end

# Player Input Page
get '/player' do
  game_state = load_game_state
  slim :player, locals: { game_state: game_state }
end

# Admin Panel
get '/admin' do
  game_state = load_game_state
  slim :admin, locals: { game_state: game_state, factions: FACTIONS }
end

post '/reset_game' do
  default_state = {
    player1: { name: 'Player 1', cp: 1, primary: 0, secondary: 0, role: 'Attacker', army: '', detachment: '' },
    player2: { name: 'Player 2', cp: 1, primary: 0, secondary: 0, role: 'Defender', army: '', detachment: '' },
    turn: 1,
    phase: 'Top',
    winner: nil
  }
  
  # Completely overwrite the JSON file with default state
  File.write(STATE_FILE, JSON.pretty_generate(default_state))

  # Force browser to NOT cache the response & clean redirect
  headers 'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0',
          'Expires' => '0',
          'Pragma' => 'no-cache'

  # Redirect to /admin cleanly without query parameters
  redirect '/admin', 303
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

    # Increase CP for both players at the start of each new player's turn
    game_state[:player1][:cp] += 1
    game_state[:player2][:cp] += 1
  end

  # If turn > 5, determine the winner
  if game_state[:turn] > 5
    player1_total = game_state[:player1][:primary] + game_state[:player1][:secondary]
    player2_total = game_state[:player2][:primary] + game_state[:player2][:secondary]

    if player1_total > player2_total
      game_state[:winner] = game_state[:player1][:name]
    elsif player2_total > player1_total
      game_state[:winner] = game_state[:player2][:name]
    else
      game_state[:winner] = "Draw"
    end
  end

  # **Force Save to Ensure Overlay Updates**
  File.write(STATE_FILE, JSON.pretty_generate(game_state))

  content_type :json
  { success: true, game_state: game_state }.to_json
end


post '/end_game' do
  game_state = load_game_state

  # Prevent recalculating if the game is already ended
  unless game_state.key?(:winner)
    p1_total_vp = game_state[:player1][:primary] + game_state[:player1][:secondary]
    p2_total_vp = game_state[:player2][:primary] + game_state[:player2][:secondary]

    if p1_total_vp > p2_total_vp
      game_state[:winner] = game_state[:player1][:name]
    elsif p2_total_vp > p1_total_vp
      game_state[:winner] = game_state[:player2][:name]
    else
      game_state[:winner] = "Draw"
    end

    game_state[:game_over] = true  # Set game state to indicate the game has ended
    save_game_state(game_state)
  end

  content_type :json
  { success: true, game_state: game_state }.to_json
end

# Overlay Route for Streaming (Live Updates via Meta Refresh)
get '/overlay' do
  game_state = load_game_state
  slim :overlay, locals: { game_state: game_state }
end

# API to update admin details in real-time
post '/update_admin' do
  game_state = load_game_state
  request.body.rewind
  data = JSON.parse(request.body.read) rescue {}
  if data['player'] == 'Player 1'
    game_state[:player1][:name] = data['name'].to_s unless data['name'].nil?
    game_state[:player1][:role] = data['role'].to_s unless data['role'].nil?
    game_state[:player1][:army] = data['army'].to_s unless data['army'].nil?
    game_state[:player1][:detachment] = data['detachment'].to_s unless data['detachment'].nil?
  elsif data['player'] == 'Player 2'
    game_state[:player2][:name] = data['name'].to_s unless data['name'].nil?
    game_state[:player2][:role] = data['role'].to_s unless data['role'].nil?
    game_state[:player2][:army] = data['army'].to_s unless data['army'].nil?
    game_state[:player2][:detachment] = data['detachment'].to_s unless data['detachment'].nil?
  end
  save_game_state(game_state)
  content_type :json
  { success: true, game_state: game_state }.to_json
end

post '/update_score' do
    game_state = load_game_state
    request.body.rewind
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

post '/update_factions' do
  game_state = load_game_state

  request.body.rewind
  data = JSON.parse(request.body.read) rescue {}

  game_state[:player1][:army] = data['player1_faction'] unless data['player1_faction'].nil?
  game_state[:player2][:army] = data['player2_faction'] unless data['player2_faction'].nil?

  save_game_state(game_state)

  content_type :json
  { success: true, game_state: game_state }.to_json
end

post '/update_game_state' do
  game_state = load_game_state
  request.body.rewind
  data = JSON.parse(request.body.read) rescue {}

  if data['player'] == 'Player 1'
    game_state[:player1][:name] = data['name'] if data.key?('name')
    game_state[:player1][:role] = data['role'] if data.key?('role')
    game_state[:player1][:army] = data['army'] if data.key?('army')
    game_state[:player1][:detachment] = data['detachment'] if data.key?('detachment')
  elsif data['player'] == 'Player 2'
    game_state[:player2][:name] = data['name'] if data.key?('name')
    game_state[:player2][:role] = data['role'] if data.key?('role')
    game_state[:player2][:army] = data['army'] if data.key?('army')
    game_state[:player2][:detachment] = data['detachment'] if data.key?('detachment')
  end

  # Save updates to game_state.json
  save_game_state(game_state)

  content_type :json
  { success: true, game_state: game_state }.to_json
end


get '/application.css' do
    scss :application
end

# Start Sinatra server
set :bind, '0.0.0.0'
set :port, 4567

# Use external Slim templates
set :views, File.dirname(__FILE__) + '/views'