# Stands in for the MQTT gem's client, recording what the broker asked it to do.
class StandInMqttClient
  attr_reader :published, :subscribed, :announced_device, :announced_lamps

  def initialize(arriving: [])
    @published = []
    @subscribed = []
    @announced_lamps = []
    @arriving = arriving
  end

  def publish(topic, payload, retain: false, qos: 0)
    @published << { topic: topic, payload: payload, retain: retain, qos: qos }
  end

  def subscribe(*topics)
    @subscribed.concat(topics)
  end

  def get(&)
    @arriving.each(&)
  end

  def publish_hass_device(device_id, **attributes)
    @announced_device = attributes.merge(device_id: device_id)
    yield
  end

  def publish_hass_light(object_id, **attributes)
    @announced_lamps << attributes.merge(object_id: object_id)
  end
end
