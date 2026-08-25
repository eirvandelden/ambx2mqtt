module Ambx2mqtt
  # What Home Assistant asked a lamp to do.
  class LampCommand
    def self.parse(payload)
      new(JSON.parse(payload))
    end

    def initialize(asked)
      @asked = asked
    end

    def colour
      Colour.from_home_assistant(@asked.fetch("color"))
    end
  end
end
