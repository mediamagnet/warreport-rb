#!/usr/bin/env ruby
# frozen_string_literal = true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/js'
require 'slim'
require 'tilt'
require 'sassc'

# Server Settings
set :server, 'thin', connections: []
set :bind, '0.0.0.0'
set :port, '4567'

get '/' do
  slim :index
end

get '/overlay' do
  slim :overlay
end

get '/application.css' do
  scss :application
end
