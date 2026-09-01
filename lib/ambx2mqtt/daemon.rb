module Ambx2mqtt
  # Looks after every attached set, and keeps looking: one that arrives is
  # announced to Home Assistant, one that goes is marked unavailable, and one
  # that has been gone for two days is forgotten altogether.
  class Daemon
    GRACE_PERIOD = 48 * 60 * 60

    def initialize(driver:, broker:, memory:, clock: Clock.new)
      @driver = driver
      @broker = broker
      @memory = memory
      @clock = clock
      @watched = {}
      @taking_turns = Mutex.new
    end

    def run
      @broker.connect(reporting_availability_on: Topics.daemon_availability)
      look_around
      @clock.every_round { look_around }
      @broker.listen
    end

    # Taking hold of a set means claiming it away from anything else on the
    # machine. There is no point doing that while there is nowhere to tell Home
    # Assistant about it, so the sets are left alone until the broker is back.
    def look_around
      return unless @broker.connected?

      @taking_turns.synchronize { look_around_now }
    end

    private

    def look_around_now
      attached = @driver.attached_sets

      attached.each do |set|
        settle_in(set)
        @memory.seen(set.identity, @clock.now)
      end

      depart(attached.map(&:identity))
      forget_the_long_gone
    end

    def settle_in(set)
      watched = watched_for(set.identity)
      return if watched.here?

      watched.arrive(set)
    end

    # Every set the daemon knows about, not only those attached right now: one
    # that was already away at startup still has to be reported away, or Home
    # Assistant goes on showing whatever it was told last time.
    def depart(still_attached)
      ((@watched.keys | @memory.known.keys) - still_attached).each { |identity| watched_for(identity).leave }
    end

    def forget_the_long_gone
      @memory.known.each do |identity, last_seen|
        next if watched_for(identity).here?
        next unless @clock.now - last_seen > GRACE_PERIOD

        @broker.forget(Announcement.device_id(identity))
        @memory.forget(identity)
        @watched.delete(identity)
        Ambx2mqtt.logger.info("forgetting the set #{identity}; gone for more than two days")
      end
    end

    def watched_for(identity)
      @watched[identity] ||= WatchedSet.new(identity, broker: @broker, memory: @memory,
                                                      taking_turns: @taking_turns)
    end
  end
end
