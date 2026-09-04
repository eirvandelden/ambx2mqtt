# Stands in for the MQTT broker. Tests hand it a command with `deliver` and read
# back what was announced or reported.
class StandInBroker
  attr_reader :announcements, :connected_reporting_on

  def initialize(connected: true)
    @connected = connected
    @listeners = {}
    @reports = {}
    @listening = false
    @forgotten = []
    @announcements = []
  end

  def connected?
    @connected
  end

  def answer_again
    @connected = true
  end

  def connect(reporting_availability_on:)
    @connected_reporting_on = reporting_availability_on
  end

  def announce(device_id:, **described)
    @announcements << described.merge(device_id: device_id)
  end

  def announcement
    @announcements.last
  end

  def forget(device_id)
    @forgotten << device_id
  end

  def forgotten?(device_id)
    @forgotten.include?(device_id)
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

  def forget_what_was_reported(topic)
    @reports.delete(topic)
  end

  def reported?(topic)
    @reports.key?(topic)
  end

  def reported(topic)
    @reports.fetch(topic) { raise "nothing was reported to #{topic}" }
  end

  def reported_settings(topic)
    JSON.parse(reported(topic))
  end
end
