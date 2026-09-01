module Ambx2mqtt
  # One physical amBX set: five lamps, and up to two fans, sharing a single USB
  # connection.
  class Set
    LAMP_ADDRESSES = {
      "left" => 0x0B,
      "right" => 0x1B,
      "wallwasher left" => 0x2B,
      "wallwasher centre" => 0x3B,
      "wallwasher right" => 0x4B
    }.freeze

    FAN_ADDRESSES = {
      "left fan" => 0x5B,
      "right fan" => 0x6B
    }.freeze

    attr_reader :identity, :name, :lamps, :fans

    def initialize(identity:, connection:, name: identity, wiring: Wiring.new)
      @identity = identity
      @name = name
      @connection = connection
      @lamps = addresses(wiring).map { |lamp_name, address| Lamp.new(name: lamp_name, address: address) }
      @fans = fans_of(wiring)
    end

    def parts
      lamps + fans
    end

    def carry_out(part, command)
      part.asked_for(command)
      @connection.write(part.command_bytes)
    end

    private

    # The two side speakers are separate units on cables, so they can be plugged
    # into each other's socket. The wallwasher is one bar and cannot be.
    def addresses(wiring)
      return LAMP_ADDRESSES unless wiring.sides_swapped?

      the_other_way_round(LAMP_ADDRESSES, "left", "right")
    end

    # The fans are accessories: a set only has them when it was said to.
    def fans_of(wiring)
      return [] unless wiring.fans?

      fan_addresses(wiring).map { |fan_name, address| Fan.new(name: fan_name, address: address) }
    end

    # The fans hang off cables of their own, so they can be swapped whichever way
    # round the speakers happen to be.
    def fan_addresses(wiring)
      return FAN_ADDRESSES unless wiring.fans_swapped?

      the_other_way_round(FAN_ADDRESSES, "left fan", "right fan")
    end

    def the_other_way_round(addresses, left, right)
      addresses.merge(left => addresses.fetch(right), right => addresses.fetch(left))
    end
  end
end
