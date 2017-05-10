require "cinch"
require 'cinch/extensions/authentication'
require "yaml"
require "recursive-open-struct"
# @note Admin Plugin

class Admin
  include Cinch::Plugin
  include Cinch::Extensions::Authentication

  match /quit/, :method => :doQuit

  def doQuit(m, msg = nil)
    return unless authenticated? m
    m.reply "Quitting"
    $bots.each do |bot|
      bot.quit msg
    end
    $threads.each do |thr|
      thr.exit
    end
  end
end
