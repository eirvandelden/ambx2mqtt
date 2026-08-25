module Ambx2mqtt
  # Announces every set to Home Assistant, puts back what each lamp was last
  # asked for, then passes new commands on.
  class Daemon
    def initialize(sets:, broker:, memory:)
      @sets = sets
      @broker = broker
      @memory = memory
      @topics = {}
    end

    def run
      @sets.each do |set|
        @broker.announce(**Announcement.new(set).to_home_assistant)
        put_back(set)
        take_commands_for(set)
      end

      @broker.listen
    end

    private

    def put_back(set)
      set.lamps.each do |lamp|
        asked = @memory.for(set.identity, lamp.topic_name)
        show(set, lamp, LampCommand.new(asked)) if asked
      end
    end

    def take_commands_for(set)
      set.lamps.each do |lamp|
        @broker.on_command(topics_for(set).command_for(lamp)) do |payload|
          show(set, lamp, LampCommand.parse(payload))
          @memory.remember(set.identity, lamp.topic_name, lamp.state)
        end
      end
    end

    def show(set, lamp, command)
      set.show(lamp, command)
      @broker.report(topics_for(set).state_for(lamp), lamp.state.to_json)
    end

    def topics_for(set)
      @topics[set.identity] ||= Topics.new(set.identity)
    end
  end
end
