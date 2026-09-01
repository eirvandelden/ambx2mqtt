module Ambx2mqtt
  # One of the two fans an amBX set may have. Optional accessories: a set only
  # has them when it was said to. A fan is asked for a speed rather than a
  # colour, and remembers the speed it was last asked for.
  class Fan
    PACKET_HEADER = 0xA1

    # A fan answers the same command as a lamp, with its speed sitting where a
    # lamp's blue would be. The two bytes before it are the unused red and green.
    SET_SPEED = 0x03
    UNUSED = [ 0x00, 0x00 ].freeze

    STILL = 0
    SLOWEST = 1
    FASTEST = 255

    attr_reader :name, :speed

    def initialize(name:, address:)
      @name = name
      @address = address
      @speed = FASTEST
      @on = false
    end

    def topic_name
      name.tr(" ", "_")
    end

    def asked_for(command)
      @on = command.on?
      @speed = command.speed || @speed
    end

    def command_bytes
      [ PACKET_HEADER, @address, SET_SPEED, *UNUSED, blowing ]
    end

    def running
      @on ? ON : OFF
    end

    def state
      { "state" => running, "speed" => @speed }
    end

    def reports(topics)
      { topics.state_for(self) => running, topics.speed_state_for(self) => speed.to_s }
    end

    def command_from(remembered)
      FanCommand.remembered(remembered)
    end

    private

    # Stopped is nothing on the wire; the speed itself is kept for the next time
    # the fan is started.
    def blowing
      return STILL unless @on

      @speed
    end
  end
end
