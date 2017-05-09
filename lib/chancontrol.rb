require "cinch"
require "yaml"
require "recursive-open-struct"
# @note ChanControl Plugin
class ChanControl
  include Cinch::Plugin
  include Cinch::Extensions::Authentication
  # Write to the config
  # @param [Hash] the data to write
  def toFile(msg)
      data = msg
      File.open(`echo ~/.gitlab-rc.yml`.chomp!, "w") {|f| f.write(data.to_yaml) }
  end
  # Load the config
  # @return [Hash] load the current config
  def deFile()
    begin
      parsed = YAML.load(File.open(`echo ~/.gitlab-rc.yml`.chomp!, "r"))
    rescue ArgumentError => e
      puts "Could not parse YAML: #{e.message}"
    end
  end

  match /add (\S)/, :method => :add
  def add(m, channel)
    return unless authenticated? m

  end
end
