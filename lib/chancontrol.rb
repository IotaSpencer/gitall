require "cinch"
require 'cinch/extensions/authentication'
require "yaml"
require "recursive-open-struct"
# @note ChanControl Plugin

class ChanControl
  include Cinch::Plugin
  include Cinch::Extensions::Authentication
  set :prefix, /^`/
  # Write to the config
  # @param [Hash] the data to write

  def toFile(msg)
    data = msg
    File.open(`echo ~/.gitlab-rc.yml`.chomp, "w") {|f| f.write(data.to_yaml) }
  end

  # Load the config
  # @return [Hash] load the current config

  def deFile()
    begin
      parsed = YAML.load(File.open(`echo ~/.gitlab-rc.yml`.chomp, "r"))
    rescue ArgumentError => e
      puts "Could not parse YAML: #{e.message}"
    end
    return parsed
  end

  match /add (\S)/, :method => :add
  match /rem (\S)/, :method => :rem
  match /list/, :method => :listchans

  def add(m, network, channel)
    return unless authenticated? m
    networks = ['electrocode', 'buddyim']
    config = deFile
    unless networks.include? network
      m.reply "Error: That's not a valid network to me."
      return
    end
    if config.has_key? "#{channel}"
      if Channel(channel)
        m.reply "#{channel} already exists in the config."
      else
        m.reply "Wasn't joined to #{channel}, joining now."
        Channel(channel).join
      end
    else
      m.reply "Joining #{channel}"
      Channel(channel).join
      config['channels'] << channel
      toFile
    end
  end

  # @param [Message] Message Object
  # @param [String] name of channel
  def rem(m, channel)
    return unless authenticated? m
    config = deFile
    config['channels'].delete channel
    Channel(channel).part
    m.reply "Channel Removed."
    toFile(config)
  end

  def listchans(m)
    return unless authenticated? m
    config = deFile
    channels = config['channels']
    channels.each do |n|
      def joined (chan)
        if Channel(chan)
          return true
        else
          return false
        end
      end
      m.reply "Channel: #{n} / Joined? #{joined(n)}"
    end
  end
end
