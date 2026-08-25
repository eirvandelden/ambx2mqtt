module Ambx2mqtt
  # The MQTT broker Home Assistant listens to. Carries commands in and reports
  # state back out.
  class Broker
    def initialize(client)
      @client = client
      @listeners = {}
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
