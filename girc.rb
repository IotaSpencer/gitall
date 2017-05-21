#! /usr/bin/env ruby
require 'sinatra/base'
require 'json'
require 'cinch'
require "cinch/plugins/basic_ctcp"
require 'ostruct'
require 'recursive-open-struct'
require 'yaml'
require 'unirest'
require 'active_support/all'
Thread.abort_on_exception = true

# @note Load the plugins
require './lib/chancontrol.rb'
require './lib/admin.rb'
#require './lib/logger.rb'

# @note Load the parsers
require './lib/gitlab.rb'
require './lib/github.rb'

# Cinch
$cfg = YAML.load_file("/home/bots/.gitlab-rc.yml")
$bots = Hash.new
$threads = Array.new

$cfg["networks"].each do |name, ncfg|
  bot = Cinch::Bot.new do
    configure do |c|
      c.server = ncfg.fetch('server')
      c.port = ncfg.fetch('port')
      c.nick = ncfg.fetch('nickname')
      c.user = ncfg.fetch('username')
      c.realname = ncfg.fetch('realname')
      #c.sasl.username = ncfg.sasl_username
      #c.sasl.password = ncfg.sasl_password
      c.channels = ncfg.fetch('channels').keys
      c.ssl.use = ncfg.fetch('ssl')
      c.ssl.verify = ncfg.fetch('sslverify')
      c.messages_per_second = ncfg.fetch('mps')
      c.authentication          = Cinch::Configuration::Authentication.new
      c.authentication.strategy = :channel_status # or :list / :login
      c.authentication.level    = :o
      c.plugins.plugins << Cinch::Plugins::BasicCTCP
      c.plugins.options[Cinch::Plugins::BasicCTCP][:replies] = {
        :version => 'GitLab Hook Bot v1.0',
        :source  => 'https://gitlab.com/IotaSpencer/gitlab-irc'
      }
      c.plugins.plugins << ChanControl
      c.plugins.plugins << Admin
    end
  end
  #bot.loggers.clear
  #bot.loggers << RequestLogger.new(name, File.open("log/request-#{name}.log", "a"))
  #bot.loggers << RequestLogger.new(name, STDOUT)
  #bot.loggers.level = :error
  $bots[name] = bot
end
$bots.each do |key, bot|
  puts "Starting IRC connection for #{key}..."
  $threads << Thread.new { bot.start }
end

# Shortener 

def shorten(url)
  domain = 
  url = "https://api.rebrandly.com/v1/links"
  params = {
    :apikey => $cfg["apikey"],
    :destination => url,
    :domain => {
      "id" => "f266d3cddc0347aca001395249c067f6",
      "ref" => "/domains/f266d3cddc0347aca001395249c067f6"
    }
  }
  response = Unirest.post url,
              headers:{"Content-Type" => "application/json"}, 
              parameters:params.to_json

  return response.body["shortUrl"]
end

# Hook

# *getFormat*
#
# Returns the message format for the received
#   hook type.
# @param kind [String] event type
# @param json [JSON] json hash

class MyApp < Sinatra::Base
  # ... app code here ...
  set :port, 8008
  set :bind, "127.0.0.1"
  set :environment, 'production'
  post '/hook/?' do
    json = JSON.parse(request.env["rack.input"].read)
    channel = nil
    network = nil
    channels = []
    tokens = []
    signatures = []
    kind = nil
    $cfg["networks"].each do |net, nethash|
      nethash["channels"].each do |chan, chanhash|
        channels << chan
        tokens << chanhash["token"]
        digest = OpenSSL::Digest.new('sha1')
        tokens.each do |token|
          hmac = OpenSSL::HMAC.hexdigest(digest, token, request.env["rack.input"].read)
          signatures << hmac
      end
    end

    if request.env.fetch('HTTP_X_HUB_SIGNATURE', "")
      sent_token = request.env['HTTP_X_HUB_SIGNATURE']
      networks = $cfg["networks"]
      digest = OpenSSL::Digest.new('sha1')
      hmac = OpenSSL::HMAC.hexdigest(digest, , json.to_json)
      networks.each do |name, nethash|
        channels = nethash.fetch('channels', nil)
        channels.each do |c, chash|
          signatures.each do |sig|
            if sig == sent_token
              channel = c
              network = name

            end
          end
        end
      end
      format = GitHubParser.parse json, request.env['HTTP_X_GITHUB_EVENT']
      format.each do |n|
        $bots[network].Channel(channel).send("#{n}")
      end
    elsif request.env.fetch('HTTP_X_GITLAB_TOKEN', "")
      if tokens.include? request.env['HTTP_X_GITLAB_TOKEN']
        sent_token = request.env['HTTP_X_GITLAB_TOKEN']
        networks = $cfg["networks"]
        networks.each do |name, nethash|
          channels = nethash.fetch('channels', nil)
          channels.each do |c, chash|
            if chash['token'] == sent_token
              channel = c
              network = name
            end
          end
        end
        format = GitLabParser.parse json
        format.each do |n|
          $bots[network].Channel(channel).send("#{n}")
        end
      else
        [403, erb :_403]
      end
    else
      status 403
      erb 
    end
  end
end
# start the server if ruby file executed directly
$threads << Thread.new { MyApp.run! if __FILE__ == $0 }
$threads.each { |t| t.join }

at_exit do
  puts "Lets clear our window"
  print %x{clear}
  exit 0
end