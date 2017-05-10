#! /usr/bin/env ruby
require 'sinatra/base'
require 'json'
require 'cinch'
require 'ostruct'
require 'recursive-open-struct'
require 'yaml'
Thread.abort_on_exception = true

# @note Load the plugins
require './lib/chancontrol.rb'
require './lib/admin.rb'
#require './lib/logger.rb'

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
      c.plugins.plugins = [ChanControl, Admin]
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

# *getFormat*
#
# Returns the message format for the received
#   hook type.
# @param kind [String] event type
# @param json [JSON] json hash
def getFormat(kind, json)
  kinds = [
    "push",
    "note",
    "wiki_page",
    "merge_request"
  ]
  j = RecursiveOpenStruct.new(json)
  case kind
  when 'push' # comes to
    # shove
    branch = j.ref
    commits = j.commits
    owner = j.project.namespace
    project = j.project.name
    pusher = j.user_name
    commit_count = j.total_commits_count
    repo_url = j.project.web_url
    before_list = []
    before_list << "[#{owner}/#{project}] #{pusher} pushed #{commit_count} commit(s) to #{branch} <#{repo_url}>"
    push_list = []
    if commits.length > 3
      coms = commits[0..2]
      coms.each do |n|
        id = n[:id]
        msg = n[:message]
        push_list << "#{}"
      end
    else
      commits.each do |n|
        id = n[:id]
        msg = n[:message]
        push_list << "#{}"
      end
    end
    return [before_list, push_list]
  end
end
# @note POST ME DADDY
class MyApp < Sinatra::Base
  # ... app code here ...
  set :port, 8008
  set :bind, "0.0.0.0"
  set :environment, 'production'
  disable :traps
  post '/gitlab/?' do
    channel = nil
    network = nil
    channels = []
    tokens = []
    $cfg["networks"].each do |net, nethash|
      nethash["channels"].each do |chan, chanhash|
        channels << chan
        tokens << chanhash["token"]
      end
    end
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
      json = JSON.parse(request.env["rack.input"].read)
      kind = json['object_kind']
      format = getFormat(kind, json)
      format.each do |n|
        $bots[network].Channel(channel).send("#{n}")
      end
      erb "Received! Thanks."
    else
      erb "Invalid Token"
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
