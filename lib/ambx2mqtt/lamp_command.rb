module Ambx2mqtt
  # What Home Assistant asked a lamp to do. Colour and brightness are absent when
  # they should stay as they are.
  class LampCommand
    def self.parse(payload)
      new(JSON.parse(payload))
    end

    def initialize(asked)
      @asked = asked
    end

    def on?
      @asked.fetch("state") == ON
    end

    def colour
      asked_colour = @asked["color"]
      return unless asked_colour

      Colour.from_home_assistant(asked_colour)
    end

    def brightness
      @asked["brightness"]
    end
  end
end
