module Ambx2mqtt
  # One of the two fans an amBX set may have. Optional accessories: a set only
  # has them when it was said to. The hardware takes a single speed byte, so a
  # fan is asked for a speed rather than a colour.
  class Fan
    SLOWEST = 1
    FASTEST = 255

    attr_reader :name

    def initialize(name:, address:)
      @name = name
      @address = address
    end

    def topic_name
      name.tr(" ", "_")
    end
  end
end
