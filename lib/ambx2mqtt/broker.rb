module Ambx2mqtt
  # The MQTT broker Home Assistant listens to. Carries commands in and reports
  # state back out.
  class Broker
    DISCOVERY_PREFIX = "homeassistant".freeze

    def initialize(client)
      @client = client
      @listeners = {}
    end

    # The last word is left with the broker before connecting, so a daemon that
    # dies is still seen to have gone.
    def connect(reporting_availability_on:)
      @availability = reporting_availability_on
      @client.set_will(@availability, OFFLINE, retain: true)
      @client.on_reconnect { came_back }
      @client.connect
      report(@availability, ONLINE)
    end

    def announce(device_id:, **described)
      @client.publish(announcement_topic(device_id), JSON.generate(described), retain: true, qos: 1)
    end

    # An empty retained payload on the announcement topic is how Home Assistant
    # is told to drop the device and its lamps.
    def forget(device_id)
      @client.publish(announcement_topic(device_id), "", retain: true, qos: 1)
    end

    def on_command(topic, &listener)
      @listeners[topic] = listener
      @client.subscribe(topic)
    end

    def report(topic, payload)
      @client.publish(topic, payload, retain: true)
    end

    def listen
      @client.get do |arriving|
        @listeners[arriving.topic]&.call(arriving.payload)
      end
    end

    private

    # A dropped connection is the last word the broker had from us, so on the way
    # back we have to say we are here again. Nothing is listened to across a
    # reconnect either, so every command topic is asked for afresh.
    def came_back
      Ambx2mqtt.logger.info("the connection to the broker came back")
      @listeners.each_key { |topic| @client.subscribe(topic) }
      report(@availability, ONLINE)
    end

    def announcement_topic(device_id)
      "#{DISCOVERY_PREFIX}/device/#{device_id}/config"
    end
  end
end
