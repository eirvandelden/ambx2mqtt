# Stands in for the MQTT gem's client, recording what the broker asked it to do.
class StandInMqttClient
  attr_reader :published, :subscribed

  def initialize(arriving: [])
    @published = []
    @subscribed = []
    @arriving = arriving
  end

  def publish(topic, payload, retain: false)
    @published << { topic: topic, payload: payload, retain: retain }
  end

  def subscribe(*topics)
    @subscribed.concat(topics)
  end

  def get(&)
    @arriving.each(&)
  end
end
