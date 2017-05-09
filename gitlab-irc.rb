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

$config = RecursiveOpenStruct.new

# @note BuddyIM config
buddy = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.buddy.im"
    c.port = 6697
    c.nick = "GitLab"
    #c.sasl.username = "GitLab0"
    #c.sasl.password = "piepie"
    c.ssl.use = true
    c.ssl.verify = false
    c.messages_per_second = 0.1
    c.plugins.plugins = [ChanControl]
  end
end
# @note ElectroCode config
ecode = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.electrocode.net"
    c.port = 6697
    c.nick = "GitLab"
    #c.sasl.username = "GitLab0"
    #c.sasl.password = "piepie"
    c.ssl.use = true
    c.ssl.verify = false
    c.messages_per_second = 0.1
    c.plugins.plugins = [ChanControl]
  end
end
buddy.start
ecode.start
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
