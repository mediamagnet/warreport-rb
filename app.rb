#!/usr/bin/env ruby
# frozen_string_literal = true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/js'
require 'slim'
require 'tilt'
require 'sassc'
require 'json'

# Server Settings
set :server, 'thin', connections: []
set :bind, '0.0.0.0'
set :port, '4567'
set :public_folder, File.dirname(__FILE__) + '/public'

get '/' do
  slim :index
end

get '/overlay' do
  atkVPstr = params[:vpATK]
  @atkVParray = JSON.parse(atkVPstr)
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

