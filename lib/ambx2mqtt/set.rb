module Ambx2mqtt
  # One physical amBX set: five lamps sharing a single USB connection.
  class Set
    LAMP_ADDRESSES = {
      "left" => 0x0B,
      "right" => 0x1B,
      "wallwasher left" => 0x2B,
      "wallwasher centre" => 0x3B,
      "wallwasher right" => 0x4B
    }.freeze

    attr_reader :identity, :name, :lamps

    def initialize(identity:, connection:, name: identity, sides_swapped: false)
      @identity = identity
      @name = name
      @connection = connection
      @lamps = addresses(sides_swapped).map { |lamp_name, address| Lamp.new(name: lamp_name, address: address) }
    end

    def show(lamp, command)
      lamp.asked_for(command)
      @connection.write(lamp.command_bytes)
    end

    private

    # The two side speakers are separate units on cables, so they can be plugged
    # into each other's socket. The wallwasher is one bar and cannot be.
    def addresses(sides_swapped)
      return LAMP_ADDRESSES unless sides_swapped

      LAMP_ADDRESSES.merge("left" => LAMP_ADDRESSES.fetch("right"),
                           "right" => LAMP_ADDRESSES.fetch("left"))
    end
  end
end
