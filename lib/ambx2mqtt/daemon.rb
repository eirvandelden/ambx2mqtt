module Ambx2mqtt
  # Looks after every attached set: announces it to Home Assistant, puts back what
  # its lamps were last asked for, and passes new commands on. A set that goes
  # away is marked unavailable.
  class Daemon
    GRACE_PERIOD = 48 * 60 * 60

    def initialize(driver:, broker:, memory:, clock: Time)
      @driver = driver
      @broker = broker
      @memory = memory
      @clock = clock
      @attached = {}
      @topics = {}
    end

    def run
      @broker.connect(reporting_availability_on: Topics.daemon_availability)
      look_around
      @broker.listen
    end

    def look_around
      attached = @driver.attached_sets

      attached.each do |set|
        arrive(set) unless @attached.key?(set.identity)
        @memory.seen(set.identity, @clock.now)
      end

      depart(attached.map(&:identity))
      forget_the_long_gone
    end

    private

    def arrive(set)
      @attached[set.identity] = set
      @broker.announce(**Announcement.new(set).to_home_assistant)
      put_back(set)
      take_commands_for(set)
      @broker.report(topics_for(set.identity).availability, ONLINE)
    end

    def depart(still_attached)
      (@attached.keys - still_attached).each do |identity|
        @broker.report(topics_for(identity).availability, OFFLINE)
        @attached.delete(identity)
      end
    end

    def forget_the_long_gone
      @memory.known.each do |identity, last_seen|
        next if @attached.key?(identity)
        next unless @clock.now - last_seen > GRACE_PERIOD

        @broker.forget(Announcement.device_id(identity))
        @memory.forget(identity)
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
          show(set, lamp, LampCommand.parse(payload))
          @memory.remember(set.identity, lamp.topic_name, lamp.state)
        end
      end
    end

    def show(set, lamp, command)
      set.show(lamp, command)
      @broker.report(topics_for(set.identity).state_for(lamp), lamp.state.to_json)
    end

    def topics_for(identity)
      @topics[identity] ||= Topics.new(identity)
    end
  end
end
