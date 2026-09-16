module Ambx2mqtt
  # One set the daemon looks after: what Home Assistant has been told about it,
  # and the commands it is given. Saying the same thing twice is a no-op, so a
  # set that stays away is only reported away once and a set that comes back is
  # never announced afresh.
  class WatchedSet
    def initialize(identity, broker:, memory:, taking_turns:)
      @identity = identity
      @broker = broker
      @memory = memory
      @taking_turns = taking_turns
      @topics = Topics.new(identity)
      @announced = false
    end

    def here?
      @announced && @said == ONLINE
    end

    def arrive(set)
      @set = set
      announce unless @announced
      say(ONLINE)
      put_back
      take_commands
      Ambx2mqtt.logger.info("found the set #{@identity}, calling it #{set.name.inspect}")
    end

    def leave
      Ambx2mqtt.logger.info("lost the set #{@identity}") if say(OFFLINE)
    end

    private

    def announce
      @broker.announce(**Announcement.new(@set).to_home_assistant)
      @announced = true
    end

    # Answers whether this was news.
    def say(state)
      return false if @said == state

      @said = state
      @broker.report(@topics.availability, state)
      true
    end

    def put_back
      @set.parts.each do |part|
        asked = @memory.for(@identity, part.topic_name)
        carry_out(part, part.command_from(asked)) if asked
      end
    end

    def take_commands
      @set.lamps.each { |lamp| listen(lamp, @topics.command_for(lamp)) { |said| LampCommand.parse(said) } }
      @set.fans.each { |fan| take_fan_commands(fan) }
    end

    # A fan is told whether to run on one topic and how fast on another, because
    # Home Assistant has no single JSON command for a fan the way it has for a
    # light.
    def take_fan_commands(fan)
      listen(fan, @topics.command_for(fan)) { |said| FanCommand.switching(said) }
      listen(fan, @topics.speed_command_for(fan)) { |said| FanCommand.at_speed(said) }
    end

    def listen(part, topic, &read)
      @broker.on_command(topic) do |payload|
        @taking_turns.synchronize { obey(part, read.call(payload), payload) }
      end
    end

    def obey(part, command, payload)
      return ignore(part, payload) unless command

      carry_out(part, command)
      @memory.remember(@identity, part.topic_name, part.state)
    end

    # A command nobody can read says nothing about whether the set is reachable.
    def ignore(part, payload)
      Ambx2mqtt.logger.warn("ignoring a command for #{@identity} #{part.name} that makes no sense: #{payload}")
    end

    # A set can be unplugged between one command and the next. However the driver
    # says so, it must not take the daemon down: the set is simply lost, and the
    # others carry on.
    def carry_out(part, command)
      reached = @set.carry_out(part, command)
      part.reports(@topics).each { |topic, said| @broker.report(topic, said) }
      leave unless reached
    rescue StandardError => error
      Ambx2mqtt.logger.warn("could not reach the set #{@identity}: #{error.message}")
      leave
    end
  end
end
