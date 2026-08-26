# Stands in for the MQTT gem's client, recording what the broker asked it to do.
class StandInMqttClient
  attr_reader :published, :subscribed, :will, :connected

  def initialize(arriving: [])
    @published = []
    @subscribed = []
    @arriving = arriving
  end

  def publish(topic, payload, retain: false, qos: 0)
    @published << { topic: topic, payload: payload, retain: retain, qos: qos }
  end

  def set_will(topic, payload, retain: false)
    @will = { topic: topic, payload: payload, retain: retain }
  end

  def connect
    @connected = true
  end

  def subscribe(*topics)
    @subscribed.concat(topics)
  end

  # The real client hands over one arriving message, which knows its own topic.
  Arriving = Struct.new(:topic, :payload)

  def get
    @arriving.each { |topic, payload| yield Arriving.new(topic, payload) }
  end

  def publish_hass_device(device_id, **attributes)
    @announced_device = attributes.merge(device_id: device_id)
    yield
  end

  def publish_hass_light(object_id, **attributes)
    @announced_lamps << attributes.merge(object_id: object_id)
  end
end
