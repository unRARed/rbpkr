#!/usr/bin/env ruby -I ../lib -I lib
# frozen_string_literal: true

require "sinatra/base"
require "sinatra/reloader"
require "sinatra/namespace"
require "sinatra/cookies"

require "slim"
require "yaml"
# require "fileutils"
require "securerandom"
require "byebug"
Dir.glob(Dir.pwd + '/lib/**/*.rb').each do |file_path|
  require file_path
end

CABLE_URL = ENV.fetch("CABLE_URL", "/cable")

class Flash
  attr_reader :is_read
  attr_accessor :message

  def initalize(is_read: false, message: "")
    @is_read = is_read
  end


  def read
    @is_read = true
    @message
  end
end

class App < Sinatra::Base
  configure :development do
    register Sinatra::Namespace

    register Sinatra::Reloader
    also_reload Dir.pwd + '/lib/**/*.rb'
  end

  helpers Sinatra::Cookies
  enable :sessions
  set :session_secret,
    "secret_key_with_size_of_32_bytes_dff054b19c2de43fc406f251376ad40"

  # Returns the full path to the root folder for
  # the :game_id value given
  #
  #   Example: /Users/some_user/audio-images/games/2fgdaf"
  #
  def self.game_root(game_id)
    Dir.pwd + "/games/#{game_id}"
  end

  # Loads, reads and parses /games/:game_id/state.yml
  # for keeping track of game-specific metadata.
  #
  def self.load_state_for_game(game_id)
    YAML.load(
      File.open("#{App.game_root(game_id)}/state.yml")
    )
  end

  # Writes the game state to the system so we can resume
  # from errors and prevent having redundant requests.
  #
  def self.write_state(state)
    unless Dir.exist?(App.game_root(state[:id]))
      Dir.mkdir(App.game_root(state[:id]))
    end
    File.write(
      "#{App.game_root(state[:id])}/state.yml",
      state.to_yaml
    )
    state
  end

  def self.server_url(request)
    env = request.env
    parts = ["http://"]
    parts << env["SERVER_NAME"]
    parts << ":#{env["SERVER_PORT"]}" if env["SERVER_PORT"]
    parts.join
  end

  before do
    if session[:flash].nil? || session[:flash]&.is_read
      session[:flash] = Flash.new
    end
  end

  get '/' do
    slim :index
  end

  get "/login" do
    slim :login
  end

  post "/login" do
    if params["user"]
      session[:user] = params["user"]
      cookies["user"] = params["user"]
      redirect "/"
    else
      slim :login
    end
  end

  namespace '/games' do
    post "/new" do
      puts "Creating new game"
      # TODO: check if game id is already taken
      game = Poker::Game.new(
        manager: session[:user],
        password: params["password"],
        url: App.server_url(request),
      )
      game.deck.reset
      game.deck.shuffle
      App.write_state(game.to_hash)
      redirect "/games/#{game.state[:id]}/community"
    end

    namespace '/:game_id' do
      get "" do
        state = App.load_state_for_game(params["game_id"])
        @game = Poker::Game.new(state)
        slim :game
      end

      post "/join" do
        state = App.load_state_for_game(params["game_id"])
        game = Poker::Game.new(state)

        # TODO: handle name already taken
        game.add_player Poker::Player.new(
          { name: session[:user] }
        )

        App.write_state(game.to_hash)
        redirect "/games/#{params["game_id"]}"
      end

      get "/community" do
        state = App.load_state_for_game(params["game_id"])

        puts "Loading community cards for #{params["game_id"]}"
        @game = Poker::Game.new(state)
        slim :community
      end

      post "/advance" do
        state = App.load_state_for_game(params["game_id"])
        game = Poker::Game.new(state)
        if session[:user] == game.state[:manager]
          game.advance
          App.write_state(game.to_hash)
        else
          session[:flash].message =
            "Only the manager can advance the game"
        end
        redirect "/games/#{game.state[:id]}/community"
      end
    end
  end


  get '/assets/:asset_filename' do
    path = "#{Dir.pwd}/images/cards/#{params["asset_filename"]}"
    send_file path, :type => :png
  end

  run!
end