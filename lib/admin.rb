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
    $threads.each do |bot|
      bot.quit msg
    end
  end

end
