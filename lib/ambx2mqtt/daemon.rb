module Ambx2mqtt
  # Listens for Home Assistant's commands and passes them on to the sets.
  class Daemon
    def initialize(sets:, broker:)
      @sets = sets
      @broker = broker
    end

    def run
      @sets.each { |set| take_commands_for(set) }
      @broker.listen
    end

    private

    def take_commands_for(set)
      set.lamps.each do |lamp|
        @broker.on_command(command_topic(set, lamp)) do |payload|
          set.show(lamp, LampCommand.parse(payload).colour)
          @broker.report(state_topic(set, lamp), lamp.state.to_json)
        end
      end
    end

    def command_topic(set, lamp)
      "ambx2mqtt/#{set.identity}/#{lamp.topic_name}/set"
    end

    def state_topic(set, lamp)
      "ambx2mqtt/#{set.identity}/#{lamp.topic_name}/state"
    end
  end
end
