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
          go_round(&doing)
        end
      end
    end

    private

    # A round that goes wrong must not be the last one. Without this the daemon
    # stays up with nothing left watching the sets, and Home Assistant goes on
    # showing whatever it was told before.
    def go_round
      yield
    rescue StandardError => error
      Ambx2mqtt.logger.error("this round went wrong, carrying on: #{error.message}")
    end
  end
end
