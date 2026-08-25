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

    def initialize(identity:, connection:, name: identity)
      @identity = identity
      @name = name
      @connection = connection
      @lamps = LAMP_ADDRESSES.map { |lamp_name, address| Lamp.new(name: lamp_name, address: address) }
    end

    def show(lamp, command)
      lamp.asked_for(command)
      @connection.write(lamp.command_bytes)
    end
  end
end
