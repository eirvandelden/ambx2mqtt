module Ambx2mqtt
  # One of the five lights on an amBX set. Holds what it was last asked for, and
  # knows the six bytes the hardware wants.
  class Lamp
    PACKET_HEADER = 0xA1
    SET_COLOUR = 0x03

    attr_reader :name

    def initialize(name:, address:)
      @name = name
      @address = address
      @colour = Colour::BLACK
      @brightness = FULL_BRIGHTNESS
      @on = false
    end

    def topic_name
      name.tr(" ", "_")
    end

    def asked_for(command)
      @on = command.on?
      @colour = command.colour || @colour
      @brightness = command.brightness || @brightness
    end

    def command_bytes
      [ PACKET_HEADER, @address, SET_COLOUR, shown.red, shown.green, shown.blue ]
    end

    def state
      { state: @on ? ON : OFF, brightness: @brightness, color: @colour.to_home_assistant }
    end

    private

    # Off is black on the wire; the colour itself is kept for the next time the
    # lamp is switched on.
    def shown
      return Colour::BLACK unless @on

      @colour.dimmed_to(@brightness)
    end
  end
end
