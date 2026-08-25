module Ambx2mqtt
  # How a set introduces itself to Home Assistant: one device carrying five lamps.
  class Announcement
    MANUFACTURER = "Philips".freeze
    MODEL = "amBX".freeze
    COLOUR_MODE = "rgb".freeze

    def self.device_id(identity)
      "#{NAME}_#{identity}"
    end

    def initialize(set)
      @set = set
      @topics = Topics.new(set.identity)
    end

    def to_home_assistant
      {
        device_id: device_id,
        device: { identifiers: device_id, name: @set.name, manufacturer: MANUFACTURER, model: MODEL },
        origin: { name: NAME },
        availability: [ { topic: Topics.daemon_availability }, { topic: @topics.availability } ],
        availability_mode: "all",
        lamps: @set.lamps.map { |lamp| lamp_component(lamp) }
      }
    end

    private

    def device_id
      self.class.device_id(@set.identity)
    end

    def lamp_component(lamp)
      {
        object_id: lamp.topic_name,
        name: lamp.name.capitalize,
        unique_id: "#{device_id}_#{lamp.topic_name}",
        schema: :json,
        command_topic: @topics.command_for(lamp),
        state_topic: @topics.state_for(lamp),
        supported_color_modes: [ COLOUR_MODE ],
        brightness: true
      }
    end
  end
end
