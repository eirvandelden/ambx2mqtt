module Ambx2mqtt
  # One set the daemon is looking after, and what Home Assistant has been told
  # about it. A set is announced once when it turns up and reported away once
  # when it cannot be reached, so the two can never disagree.
  class WatchedSet
    def initialize(identity, broker:, memory:, one_at_a_time:)
      @identity = identity
      @broker = broker
      @memory = memory
      @one_at_a_time = one_at_a_time
      @topics = Topics.new(identity)
      @away = false
    end

    def here?
      !@set.nil?
    end

    def arrive(set)
      return if here?

      @set = set
      @away = false
      introduce
      put_back
      take_commands
    end

    def depart
      @set = nil
      lose
    end

    private

    # Reported available before anything is asked of the hardware, so a set that
    # turns out to be unreachable has the last word rather than the first.
    def introduce
      @broker.announce(**Announcement.new(@set).to_home_assistant)
      @broker.report(@topics.availability, ONLINE)
      Ambx2mqtt.logger.info("found the set #{@identity}, calling it #{@set.name.inspect}")
    end

    def lose
      return if @away

      @away = true
      @broker.report(@topics.availability, OFFLINE)
      Ambx2mqtt.logger.info("lost the set #{@identity}")
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
          @one_at_a_time.synchronize { obey(lamp, payload) }
        end
      end
    end

    # A command that makes no sense says nothing about whether the set is there,
    # so the set is left as it was and the daemon carries on.
    def obey(lamp, payload)
      return unless here?

      show(lamp, LampCommand.parse(payload))
      @memory.remember(@identity, lamp.topic_name, lamp.state)
    rescue CannotReadCommand => error
      Ambx2mqtt.logger.warn("ignoring a command for the set #{@identity}: #{error.message}")
    end

    # A set can be unplugged between one command and the next. However the driver
    # says so, it must not take the daemon down: the set is simply lost, and the
    # others carry on.
    def show(lamp, command)
      reached = @set.show(lamp, command)
      @broker.report(@topics.state_for(lamp), lamp.state.to_json)
      lose unless reached
    rescue StandardError => error
      Ambx2mqtt.logger.warn("could not reach the set #{@identity}: #{error.message}")
      lose
    end
  end
end
