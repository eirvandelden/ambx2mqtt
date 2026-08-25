module Ambx2mqtt
  # One of the five lights on an amBX set. Knows the six bytes the hardware wants
  # and how to describe itself to Home Assistant.
  class Lamp
    PACKET_HEADER = 0xA1
    SET_COLOUR = 0x03

    attr_reader :name

    def initialize(name:, address:)
      @name = name
      @address = address
      @colour = Colour::BLACK
    end

    def topic_name
      name.tr(" ", "_")
    end

    def show(colour)
      @colour = colour
    end

    def command_bytes
      [ PACKET_HEADER, @address, SET_COLOUR, @colour.red, @colour.green, @colour.blue ]
    end

    def state
      { state: "ON", color: @colour.to_home_assistant }
    end
  end
end
