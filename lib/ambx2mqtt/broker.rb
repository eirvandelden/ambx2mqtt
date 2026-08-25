module Ambx2mqtt
  # The MQTT broker Home Assistant listens to. Carries commands in and reports
  # state back out.
  class Broker
    DISCOVERY_PREFIX = "homeassistant".freeze

    def initialize(client)
      @client = client
      @listeners = {}
    end

    def announce(device_id:, device:, origin:, lamps:)
      @client.publish_hass_device(device_id, device: device, origin: origin) do
        lamps.each { |lamp| @client.publish_hass_light(lamp.fetch(:object_id), **lamp.except(:object_id)) }
      end
    end

    # An empty retained payload on the announcement topic is how Home Assistant
    # is told to drop the device and its lamps.
    def forget(device_id)
      @client.publish("#{DISCOVERY_PREFIX}/device/#{device_id}/config", "", retain: true, qos: 1)
    end

    def on_command(topic, &listener)
      @listeners[topic] = listener
      @client.subscribe(topic)
    end

    def report(topic, payload)
      @client.publish(topic, payload, retain: true)
    end

    def listen
      @client.get do |topic, payload|
        @listeners[topic]&.call(payload)
      end
    end
  end
end
