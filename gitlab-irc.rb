#! /usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'json'
require 'cinch'
require 'ostruct'
require 'recursive-open-struct'
require 'yaml'

# @note Load the plugins
require './lib/chancontrol.rb'
require './lib/logger.rb'

$cfg = RecursiveOpenStruct.new(YAML.load_file(`echo ~/.gitlab-rc.yml`.chomp!))
$bots = Hash.new
$threads = Array.new

$cfg.networks.each do |name|
  ncfg = $cfg.dig(:networks, name)
  puts name
  bot = Cinch::Bot.new do
    configure do |c|
      c.server = ncfg.server
      c.port = ncfg.port
      c.nick = ncfg.nickname
      c.username = ncfg.username
      c.realname = ncfg.realname
      #c.sasl.username = ncfg.sasl_username
      #c.sasl.password = ncfg.sasl_password
      c.ssl.use = ncfg.ssl
      c.ssl.verify = ncfg.sslverify
      c.messages_per_second = ncfg.mps
      c.plugins.plugins = ncfg.plugins
    end
  end
  bot.loggers.clear
  bot.loggers << RequestLogger.new(name, File.open("log/irc-#{name}.log", "a"))
  bot.loggers << RequestLogger.new(name, STDOUT)
  bot.loggers.level = :error
  $bots[name] = bot
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
  Thread.new do
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
          id = n.id
          msg = n.message
          push_list << "#{}"
        end
      else
        commits.each do |n|
          id = n.id
          msg = n.message
          push_list << ""
        end
      end
      return [before_list, push_list]
    end
  end
  Thread.stop
end
# @note POST ME DADDY
post '/gitlab/?' do
  if headers['X-Gitlab-Token'] == config.token
    Thread.new do
      json = JSON.parse(request.env["rack.input"].read)
      kind = json['object_kind']
      format = getFormat(kind, json)
      bot.channels.each do |m|
        format.each do |n|
          bot.Channel(m).send("#{n}")
        end
      end
    end
    Thread.stop
  end
end
