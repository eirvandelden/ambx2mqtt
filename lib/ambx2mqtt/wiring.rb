module Ambx2mqtt
  # How one amBX set is put together: which socket each side unit ended up in,
  # and whether the optional fans are there at all.
  class Wiring
    def initialize(sides_swapped: false, fans: false, fans_swapped: false)
      @sides_swapped = sides_swapped
      @fans = fans
      @fans_swapped = fans_swapped
    end

    def sides_swapped?
      @sides_swapped ? true : false
    end

    def fans?
      @fans ? true : false
    end

    def fans_swapped?
      @fans_swapped ? true : false
    end
  end
end
