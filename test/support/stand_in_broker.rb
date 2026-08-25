# Stands in for the MQTT broker. Tests hand it a command with `deliver` and read
# back what was announced or reported.
class StandInBroker
  attr_reader :announcement

  def initialize
    @listeners = {}
    @reports = {}
    @listening = false
  end

  def announce(**description)
    @announcement = description
  end

  def on_command(topic, &listener)
    @listeners[topic] = listener
  end

  def report(topic, payload)
    @reports[topic] = payload
  end

  def listen
    @listening = true
  end

  def listening?
    @listening
  end

  def deliver(topic, payload)
    listener = @listeners.fetch(topic) { raise "nobody is listening to #{topic}" }
    listener.call(payload)
  end

  def reported(topic)
    JSON.parse(@reports.fetch(topic) { raise "nothing was reported to #{topic}" })
  end
end
