# Stands in for the MQTT gem's client, recording what the broker asked it to do.
class StandInMqttClient
  attr_reader :published, :subscribed, :will, :connected, :subscribe_requests

  def initialize(arriving: [], refusing_to_subscribe: false)
    @published = []
    @subscribed = []
    @subscribe_requests = []
    @arriving = arriving
    @refusing_to_subscribe = refusing_to_subscribe
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

  def on_reconnect(&came_back)
    @came_back = came_back
  end

  def come_back
    @came_back&.call
  end

  # The real client sends a packet whatever it is given, and one with no topics
  # in it is a broken request that gets us dropped.
  def subscribe(*topics)
    raise "not connected" if @refusing_to_subscribe && @subscribed.any?

    @subscribe_requests << topics
    @subscribed.concat(topics)
    interrupting = @while_subscribing
    @while_subscribing = nil
    interrupting&.call
  end

  # Lets a test do something on another thread's behalf midway through a
  # subscribe, the way a set arriving would.
  def while_subscribing(&doing)
    @while_subscribing = doing
  end

  # The real client hands over one arriving message, which knows its own topic.
  Arriving = Struct.new(:topic, :payload)

  def get
    @arriving.each { |topic, payload| yield Arriving.new(topic, payload) }
  end
end
