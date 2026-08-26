module Ambx2mqtt
  # Looks after every attached set: announces it to Home Assistant, puts back what
  # its lamps were last asked for, and passes new commands on. A set that goes
  # away is marked unavailable.
  class Daemon
    GRACE_PERIOD = 48 * 60 * 60

    def initialize(driver:, broker:, memory:, clock: Clock.new)
      @driver = driver
      @broker = broker
      @memory = memory
      @clock = clock
      @watched = {}
      @one_at_a_time = Mutex.new
    end

    def run
      @broker.connect(reporting_availability_on: Topics.daemon_availability)
      look_around
      @clock.every_round { look_around }
      @broker.listen
    end

    def look_around
      @one_at_a_time.synchronize { look_around_now }
    end

    private

    def look_around_now
      attached = @driver.attached_sets

      attached.each do |set|
        watch_over(set.identity).arrive(set)
        @memory.seen(set.identity, @clock.now)
      end

      depart(attached.map(&:identity))
      forget_the_long_gone
    end

    # Every set the daemon has ever seen, not only those it saw this run: one
    # that was already away at startup still has to be reported away, or Home
    # Assistant goes on showing whatever it was told last time.
    def depart(still_attached)
      ((@watched.keys | @memory.known.keys) - still_attached).each { |identity| watch_over(identity).depart }
    end

    def forget_the_long_gone
      @memory.known.each do |identity, last_seen|
        next if watch_over(identity).here?
        next unless @clock.now - last_seen > GRACE_PERIOD

        @broker.forget(Announcement.device_id(identity))
        @memory.forget(identity)
        @watched.delete(identity)
        Ambx2mqtt.logger.info("forgetting the set #{identity}; gone for more than two days")
      end
    end

    def watch_over(identity)
      @watched[identity] ||= WatchedSet.new(identity, broker: @broker, memory: @memory,
                                            one_at_a_time: @one_at_a_time)
    end
  end
end
