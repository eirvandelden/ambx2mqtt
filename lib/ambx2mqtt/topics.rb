module Ambx2mqtt
  # Where one set's commands arrive and its state is reported.
  class Topics
    def self.daemon_availability
      "#{NAME}/availability"
    end

    def initialize(identity)
      @identity = identity
    end

    def availability
      "#{NAME}/#{@identity}/availability"
    end

    def command_for(part)
      "#{for_part(part)}/set"
    end

    def state_for(part)
      "#{for_part(part)}/state"
    end

    def speed_command_for(fan)
      "#{for_part(fan)}/speed/set"
    end

    def speed_state_for(fan)
      "#{for_part(fan)}/speed/state"
    end

    private

    def for_part(part)
      "#{NAME}/#{@identity}/#{part.topic_name}"
    end
  end
end
