# Stands in for the USB connection to one amBX set, remembering every command it
# was asked to send.
class StandInConnection
  attr_reader :commands

  def initialize
    @commands = []
  end

  def write(bytes)
    @commands << bytes
  end
end
