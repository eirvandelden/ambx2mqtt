module Ambx2mqtt
  # Tells the time, and marks the rounds the daemon does while it runs.
  class Clock
    SECONDS_BETWEEN_ROUNDS = 30

    def initialize(seconds_between_rounds: SECONDS_BETWEEN_ROUNDS)
      @seconds_between_rounds = seconds_between_rounds
    end

    def now
      Time.now
    end

    def every_round(&doing)
      Thread.new do
        loop do
          sleep(@seconds_between_rounds)
          doing.call
        end
      end
    end
  end
end
