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
def getFormat(kind, json)
  j = RecursiveOpenStruct.new(json)
  case kind
  when 'note'
    repo = j.project.path_with_namespace
    ntype = j.object_attributes.noteable_type
    response = []
    case ntype
    when 'MergeRequest'
      mr_note  = j.object_attributes.note
      mr_url   = shorten(j.object_attributes.url)
      mr_title = j.merge_request.title
      mr_id    = j.merge_request.iid
      mr_user  = j.user.name
      response << "[#{repo}] #{mr_user} commented on Merge Request ##{mr_id} \u2014 #{mr_note}"
      response << "'#{mr_title}' => #{mr_url}"
      ]
    when 'Commit'
      c_message = j.commit.message
      c_note    = j.object_attributes.note
      c_sha     = j.commit.id[0...7]
      c_url     = shorten(j.object_attributes.url)
      c_user    = j.user.name
      response << "[#{repo}] #{c_user} commented on commit (#{c_sha}) \u2014 #{c_note} <#{c_url}>"
    when 'Issue'
      i_id    = j.issue.iid
      i_url   = shorten(j.object_attributes.url)
      i_msg   = j.object_attributes.note
      i_title = j.issue.title
      i_user  = j.user.name
      response << "[#{repo}] #{i_user} commented on Issue ##{i_id} (#{i_title}) \u2014 #{i_msg} <#{i_url}>"
    end
    return response
  when 'merge_request'
    mr_name      = j.user.name
    mr_user      = j.user.username
    mr_url       = shorten(j.url)
    mr_spath     = j.object_attributes.source.path_with_namespace
    mr_sbranch   = j.object_attributes.source_branch
    mr_tpath     = j.object_attributes.target.path_with_namespace
    mr_tbranch   = j.object_attributes.target_branch
    mr_lcmessage = j.last_commit.message
    mr_lcsha     = j.last_commit.id[0...7]
    response = []
    response << "#{mr_name}(#{mr_user}) opened a merge request. #{mr_spath}[#{mr_sbranch}] ~> #{mr_tpath}[#{mr_tbranch}]"
    response << "[#{mr_lcsha}] \u2014 #{mr_lcmessage} <#{mr_url}>"
  when 'push' # comes to
    # shove
    branch = j.ref.split('/')[-1]
    commits = j.commits
    added = 0
    removed = 0
    modified = 0
    commits.each do |h|
      added    += h["added"].length
      removed  += h["removed"].length
      modified += h["modified"].length
    end
    owner = j.project.namespace
    project = j.project.name
    pusher = j.user_name
    commit_count = j.total_commits_count
    repo_url = shorten(j.project.web_url)
    before_list = []
    before_list << "[#{owner}/#{project}] #{pusher} pushed #{commit_count} commit(s) [+#{added}/-#{removed}/±#{modified}] to [#{branch}] at <#{repo_url}>"
    push_list = []
    if commits.length > 3
      coms = commits[0..2]
      coms.each do |n|
        id = n["id"]
        msg = n["message"]
        author = n["author"]["name"]
        timestamp = n["timestamp"]
        ts = DateTime.parse(timestamp)
        time = ts.strftime("%b/%d/%Y %T")
        push_list << "#{author} — #{msg} [#{id[0...7]}]"
      end
      push_list << "and #{commits.from(3).length} commits..."
    else
      commits.each do |n|
        id = n['id']
        msg = n['message']
        author = n['author']['name']
        timestamp = n['timestamp']
        ts = DateTime.parse(timestamp)
        time = ts.strftime("%b/%d/%Y %T")
        push_list << "#{author} — #{msg} [#{id[0...7]}]"
      end
    end
    return [before_list, push_list].flatten!
  end
end
class MyApp < Sinatra::Base
  # ... app code here ...
  set :port, 8008
  set :bind, "127.0.0.1"
  set :environment, 'production'
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