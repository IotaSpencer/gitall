require 'cinch'

class RequestLogger < Cinch::Logger::FormattedLogger
  def initialize(network, *args)
    @network = network
    super(*args)
  end

  def format_general(message)
    message.gsub!(/[^[:print:][:space:]]/) do |m|
      colorize(m.inspect[1..-2], :bg_white, :black)
    end
    "[#{@network}] #{message}"
  end
end
