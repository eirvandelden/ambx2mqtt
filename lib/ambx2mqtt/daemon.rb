module Ambx2mqtt
  # Announces every set to Home Assistant, then passes its commands on.
  class Daemon
    def initialize(sets:, broker:)
      @sets = sets
      @broker = broker
    end

    def run
      @sets.each do |set|
        @broker.announce(**Announcement.new(set).to_home_assistant)
        take_commands_for(set)
      end

      @broker.listen
    end

    private

    def take_commands_for(set)
      topics = Topics.new(set.identity)

      set.lamps.each do |lamp|
        @broker.on_command(topics.command_for(lamp)) do |payload|
          set.show(lamp, LampCommand.parse(payload))
          @broker.report(topics.state_for(lamp), lamp.state.to_json)
        end
      end
    end
  end
end
