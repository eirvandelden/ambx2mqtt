module Ambx2mqtt
  # Where one set's commands arrive and its state is reported.
  class Topics
    def initialize(identity)
      @identity = identity
    end

    def command_for(lamp)
      "#{for_lamp(lamp)}/set"
    end

    def state_for(lamp)
      "#{for_lamp(lamp)}/state"
    end

    private

    def for_lamp(lamp)
      "#{NAME}/#{@identity}/#{lamp.topic_name}"
    end
  end
end
