require "test_helper"

class BrokerTest < Minitest::Test
  def test_reporting_a_lamps_state_keeps_it_on_the_broker_for_home_assistant_to_find
    client = StandInMqttClient.new
    broker = Ambx2mqtt::Broker.new(client)

    broker.report("ambx2mqtt/desk/left/state", %({"state":"ON"}))

    assert_equal [ { topic: "ambx2mqtt/desk/left/state", payload: %({"state":"ON"}), retain: true, qos: 0 } ],
                 client.published
  end


  def test_the_broker_offers_home_assistant_the_announcement_a_set_actually_makes
    set = Ambx2mqtt::Set.new(identity: "desk", connection: StandInConnection.new)
    client = StandInMqttClient.new

    Ambx2mqtt::Broker.new(client).announce(**Ambx2mqtt::Announcement.new(set).to_home_assistant)

    offered = client.published.first
    assert_equal "homeassistant/device/ambx2mqtt_desk/config", offered[:topic]
    assert offered[:retain], "Home Assistant would forget the set as soon as it looked away"

    described = JSON.parse(offered[:payload])
    assert_equal "all", described["availability_mode"]
    assert_equal 2, described["availability"].size
    assert_equal 5, described["components"].size
  end

  def test_a_command_topic_arriving_while_the_connection_comes_back_does_not_break_it
    client = StandInMqttClient.new
    broker = Ambx2mqtt::Broker.new(client)
    broker.connect(reporting_availability_on: "ambx2mqtt/availability")
    broker.on_command("ambx2mqtt/desk/left/set") { }

    # A set arriving on the daemon's own thread asks to be listened to while the
    # connection is being put back together on the library's thread.
    client.while_subscribing { broker.on_command("ambx2mqtt/study/left/set") { } }

    client.come_back

    assert_includes client.subscribed, "ambx2mqtt/desk/left/set"
  end

  def test_a_connection_that_comes_back_only_half_way_does_not_take_the_daemon_down
    client = StandInMqttClient.new(refusing_to_subscribe: true)
    broker = Ambx2mqtt::Broker.new(client)
    broker.connect(reporting_availability_on: "ambx2mqtt/availability")
    broker.on_command("ambx2mqtt/desk/left/set") { }

    client.come_back

    assert true, "coming back raised and would have ended the daemon"
  end

  def test_a_daemon_whose_connection_comes_back_says_it_is_here_again
    client = StandInMqttClient.new
    broker = Ambx2mqtt::Broker.new(client)
    broker.connect(reporting_availability_on: "ambx2mqtt/availability")
    client.published.clear

    client.come_back

    assert_includes client.published,
                    { topic: "ambx2mqtt/availability", payload: "online", retain: true, qos: 0 }
  end

  def test_a_daemon_whose_connection_comes_back_listens_for_commands_again
    client = StandInMqttClient.new
    broker = Ambx2mqtt::Broker.new(client)
    broker.connect(reporting_availability_on: "ambx2mqtt/availability")
    broker.on_command("ambx2mqtt/desk/left/set") { }
    client.subscribed.clear

    client.come_back

    assert_equal [ "ambx2mqtt/desk/left/set" ], client.subscribed
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
