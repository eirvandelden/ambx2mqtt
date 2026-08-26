module Ambx2mqtt
  class CannotReadCommand < StandardError; end

  # What Home Assistant asked a lamp to do. Colour and brightness are absent when
  # they should stay as they are, but a command that never says whether to light
  # up is no command at all.
  class LampCommand
    def self.parse(payload)
      asked = JSON.parse(payload)
      return new(asked) if asked.is_a?(Hash) && asked.key?("state")

      raise CannotReadCommand, unreadable(payload)
    rescue JSON::ParserError
      raise CannotReadCommand, unreadable(payload)
    end

    def self.unreadable(payload)
      "there is no lamp command in #{payload.inspect}"
    end
    private_class_method :unreadable

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
