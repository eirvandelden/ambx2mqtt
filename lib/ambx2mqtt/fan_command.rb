module Ambx2mqtt
  # What Home Assistant asked a fan to do. A fan has no JSON schema to lean on,
  # so its two topics carry plain payloads: one saying whether to run, one asking
  # for a speed. Nothing at all comes back from a payload that cannot be read.
  class FanCommand
    def self.switching(payload)
      return unless [ ON, OFF ].include?(payload)

      new(on: payload == ON)
    end

    # Asking for a speed starts the fan, and asking for no speed stops it rather
    # than leaving it crawling at the slowest it can go.
    def self.at_speed(payload)
      asked = Integer(payload, exception: false)
      return unless asked
      return new(on: false) if asked <= Fan::STILL

      new(on: true, speed: [ asked, Fan::FASTEST ].min)
    end

    def self.remembered(asked)
      new(on: asked["state"] == ON, speed: asked["speed"])
    end

    attr_reader :speed

    def initialize(on:, speed: nil)
      @on = on
      @speed = speed
    end

    def on?
      @on
    end
  end
end
