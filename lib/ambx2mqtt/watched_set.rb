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
      @set.lamps.each do |lamp|
        asked = @memory.for(@identity, lamp.topic_name)
        show(lamp, LampCommand.new(asked)) if asked
      end
    end

    def take_commands
      @set.lamps.each do |lamp|
        @broker.on_command(@topics.command_for(lamp)) do |payload|
          @taking_turns.synchronize { obey(lamp, payload) }
        end
      end
    end

    def obey(lamp, payload)
      command = LampCommand.parse(payload)
      return ignore(lamp, payload) unless command

      show(lamp, command)
      @memory.remember(@identity, lamp.topic_name, lamp.state)
    end

    # A command nobody can read says nothing about whether the set is reachable.
    def ignore(lamp, payload)
      Ambx2mqtt.logger.warn("ignoring a command for #{@identity} #{lamp.name} that makes no sense: #{payload}")
    end

    # A set can be unplugged between one command and the next. However the driver
    # says so, it must not take the daemon down: the set is simply lost, and the
    # others carry on.
    def show(lamp, command)
      reached = @set.show(lamp, command)
      @broker.report(@topics.state_for(lamp), lamp.state.to_json)
      leave unless reached
    rescue StandardError => error
      Ambx2mqtt.logger.warn("could not reach the set #{@identity}: #{error.message}")
      leave
    end
  end
end
