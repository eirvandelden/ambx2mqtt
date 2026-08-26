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
      @attached = {}
      @reported_away = []
      @topics = {}
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
        arrive(set) unless @attached.key?(set.identity)
        @memory.seen(set.identity, @clock.now)
      end

      depart(attached.map(&:identity))
      forget_the_long_gone
    end

    def arrive(set)
      @attached[set.identity] = set
      @reported_away.delete(set.identity)
      @broker.announce(**Announcement.new(set).to_home_assistant)
      put_back(set)
      take_commands_for(set)
      @broker.report(topics_for(set.identity).availability, ONLINE)
      Ambx2mqtt.logger.info("found the set #{set.identity}, calling it #{set.name.inspect}")
    end

    # Every set the daemon has ever seen, not only those it saw this run: one
    # that was already away at startup still has to be reported away, or Home
    # Assistant goes on showing whatever it was told last time.
    def depart(still_attached)
      ((@attached.keys | @memory.known.keys) - still_attached).each { |identity| lose(identity) }
    end

    def lose(identity)
      return if @reported_away.include?(identity)

      @broker.report(topics_for(identity).availability, OFFLINE)
      @attached.delete(identity)
      @reported_away << identity
      Ambx2mqtt.logger.info("lost the set #{identity}")
    end

    def forget_the_long_gone
      @memory.known.each do |identity, last_seen|
        next if @attached.key?(identity)
        next unless @clock.now - last_seen > GRACE_PERIOD

        @broker.forget(Announcement.device_id(identity))
        @memory.forget(identity)
        Ambx2mqtt.logger.info("forgetting the set #{identity}; gone for more than two days")
      end
    end

    def put_back(set)
      set.lamps.each do |lamp|
        asked = @memory.for(set.identity, lamp.topic_name)
        show(set, lamp, LampCommand.new(asked)) if asked
      end
    end

    def take_commands_for(set)
      set.lamps.each do |lamp|
        @broker.on_command(topics_for(set.identity).command_for(lamp)) do |payload|
          @one_at_a_time.synchronize do
            show(set, lamp, LampCommand.parse(payload))
            @memory.remember(set.identity, lamp.topic_name, lamp.state)
          end
        end
      end
    end

    # A set can be unplugged between one command and the next. However the driver
    # says so, it must not take the daemon down: the set is simply lost, and the
    # others carry on.
    def show(set, lamp, command)
      reached = set.show(lamp, command)
      @broker.report(topics_for(set.identity).state_for(lamp), lamp.state.to_json)
      lose(set.identity) unless reached
    rescue StandardError => error
      Ambx2mqtt.logger.warn("could not reach the set #{set.identity}: #{error.message}")
      lose(set.identity)
    end

    def topics_for(identity)
      @topics[identity] ||= Topics.new(identity)
    end
  end
end
