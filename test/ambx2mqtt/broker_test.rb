require "test_helper"

class BrokerTest < Minitest::Test
  def test_reporting_a_lamps_state_keeps_it_on_the_broker_for_home_assistant_to_find
    client = StandInMqttClient.new
    broker = Ambx2mqtt::Broker.new(client)

    broker.report("ambx2mqtt/desk/left/state", %({"state":"ON"}))

    assert_equal [ { topic: "ambx2mqtt/desk/left/state", payload: %({"state":"ON"}), retain: true, qos: 0 } ],
                 client.published
  end

  def test_announcing_a_set_offers_home_assistant_one_device_carrying_its_lamps
    client = StandInMqttClient.new
    broker = Ambx2mqtt::Broker.new(client)

    broker.announce(device_id: "ambx2mqtt_desk",
                    device: { name: "desk" },
                    origin: { name: "ambx2mqtt" },
                    lamps: [ { object_id: "left", name: "Left", command_topic: "ambx2mqtt/desk/left/set" } ])

    assert_equal "ambx2mqtt_desk", client.announced_device[:device_id]
    assert_equal({ name: "desk" }, client.announced_device[:device])
    assert_equal [ "left" ], client.announced_lamps.map { |lamp| lamp[:object_id] }
    assert_equal "Left", client.announced_lamps.first[:name]
  end

  def test_listening_for_a_lamps_commands_subscribes_to_its_command_topic
    client = StandInMqttClient.new
    broker = Ambx2mqtt::Broker.new(client)

    broker.on_command("ambx2mqtt/desk/left/set") { }

    assert_equal [ "ambx2mqtt/desk/left/set" ], client.subscribed
  end

  def test_a_command_that_arrives_reaches_whoever_asked_for_that_topic
    client = StandInMqttClient.new(arriving: [ [ "ambx2mqtt/desk/left/set", "turn it red" ] ])
    broker = Ambx2mqtt::Broker.new(client)
    heard = []

    broker.on_command("ambx2mqtt/desk/left/set") { |payload| heard << payload }
    broker.listen

    assert_equal [ "turn it red" ], heard
  end

  def test_a_command_for_a_topic_nobody_asked_about_is_ignored
    client = StandInMqttClient.new(arriving: [ [ "somebody/elses/topic", "not ours" ] ])
    broker = Ambx2mqtt::Broker.new(client)

    assert_silent { broker.listen }
  end
end
