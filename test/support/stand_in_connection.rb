# Stands in for the USB connection to one amBX set, remembering every command it
# was asked to send.
class StandInConnection
  attr_reader :commands

  def initialize
    @commands = []
  end

  def write(bytes)
    @commands << bytes

    true
  end
end

# A set that has just been unplugged: the driver says the command did not land.
class UnpluggedConnection
  def write(_bytes)
    false
  end
end

# Some drivers raise instead of answering, which must not be fatal either.
class VanishedConnection
  def write(_bytes)
    raise "the device is no longer there"
  end
end
