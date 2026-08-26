# Stands in for the USB connection to one amBX set, remembering every command it
# was asked to send.
class StandInConnection
  attr_reader :commands

  def initialize
    @commands = []
  end

  # Truthy says the bytes reached the box, as the driver contract asks.
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

# A driver that says nothing at all about the write: falsy, so the box is gone.
class SilentConnection
  def write(_bytes)
    nil
  end
end

# Some drivers raise instead of answering, which must not be fatal either.
class VanishedConnection
  def write(_bytes)
    raise "the device is no longer there"
  end
end
