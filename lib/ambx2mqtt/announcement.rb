module Ambx2mqtt
  # How a set introduces itself to Home Assistant: one device carrying five lamps.
  class Announcement
    MANUFACTURER = "Philips".freeze
    MODEL = "amBX".freeze
    COLOUR_MODE = "rgb".freeze

    # A lamp is only reachable while the daemon and its own set are both here.
    BOTH_MUST_BE_HERE = "all".freeze

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
        availability_mode: BOTH_MUST_BE_HERE,
        components: components
      }
    end

    private

    def device_id
      self.class.device_id(@set.identity)
    end

    def components
      lamps = @set.lamps.to_h { |lamp| [ lamp.topic_name, lamp_component(lamp) ] }

      lamps.merge(@set.fans.to_h { |fan| [ fan.topic_name, fan_component(fan) ] })
    end

    def lamp_component(lamp)
      {
        platform: "light",
        name: lamp.name.capitalize,
        unique_id: "#{device_id}_#{lamp.topic_name}",
        schema: :json,
        command_topic: @topics.command_for(lamp),
        state_topic: @topics.state_for(lamp),
        supported_color_modes: [ COLOUR_MODE ],
        brightness: true
      }
    end

    # A fan has no JSON schema to lean on the way a light does, so its speed
    # arrives on a topic of its own, as a plain number in the hardware's range.
    def fan_component(fan)
      {
        platform: "fan",
        name: fan.name.capitalize,
        unique_id: "#{device_id}_#{fan.topic_name}",
        command_topic: @topics.command_for(fan),
        state_topic: @topics.state_for(fan),
        percentage_command_topic: @topics.speed_command_for(fan),
        percentage_state_topic: @topics.speed_state_for(fan),
        speed_range_min: Fan::SLOWEST,
        speed_range_max: Fan::FASTEST
      }
    end
  end
end
