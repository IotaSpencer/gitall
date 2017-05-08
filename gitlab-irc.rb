#! /usr/bin/env ruby
# :markup: RDoc
require 'rubygems'
require 'sinatra'
require 'json'
require 'cinch'
require 'ostruct'
require 'recursive-open-struct'
config = RecursiveOpenStruct.new
config.token = '8cuRsS5X46MCS6DYz3f625Esue9Rqe'

# IRC Config
bot = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.buddy.im"
    c.channels = ["#IRC-Source/Private", "#IRC-Source/Dev/Priv"]
    c.nick = "GitLab"
    #c.sasl.username = "GitLab0"
    #c.sasl.password = "piepie"
    c.ssl.use = true
    c.ssl.verify = false
    c.messages_per_second = 0.1
  end
end
bot.start

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
    j.branch = j.ref
    case kind
    when 'push'
        # shove

    end
end
post '/gitlab' do
    if headers['X-Gitlab-Token'] == config.token
        Thread.new do
            json = JSON.parse(request.env["rack.input"].read)
            kind = json['object_kind']
            format = getFormat(kind, json)
            bot.channels.each do |m|
                bot.Channel(m).send("#{format()}")
            end
        end
        Thread.stop
    end
end
