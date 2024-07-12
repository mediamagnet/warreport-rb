#!/usr/bin/env ruby
# frozen_string_literal = true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/js'
require 'sinatra-websocket'
require 'slim'
require 'tilt'
require 'sassc'
require 'json'

# Server Settings
set :server, 'thin', connections: []
set :bind, '0.0.0.0'
set :port, '4567'
set :public_folder, File.dirname(__FILE__) + '/public'
set :sockets, []

get '/' do
  slim :index
end

get '/overlay' do
  slim :overlay
end

get '/players' do
  slim :players
end

get '/application.css' do
  scss :application
end

get '/application.js' do
  content_type 'text/javascript'
  send_file File.join('views', 'application.js')
end

get '/websocket' do
  if !request.websocket?
    halt 400, "WebSocket endpoint"
  else
    request.websocket do |ws|
      ws.onopen do
        ws.send 'hello web'
        settings.sockets << ws
      end
      ws.onmessage do |msg|
        EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
      end
      ws.onclose do
        settings.sockets.delete(ws)
      end
    end
  end
end