require "test_helper"

class TheDaemonGoingAwayTest < Minitest::Test
  DAEMON_AVAILABILITY = "ambx2mqtt/availability".freeze
  SET_AVAILABILITY = "ambx2mqtt/desk/availability".freeze

  def test_connecting_leaves_word_so_a_daemon_that_dies_is_seen_to_have_gone
    client = StandInMqttClient.new
    Ambx2mqtt::Broker.new(client).connect(reporting_availability_on: DAEMON_AVAILABILITY)

    assert_equal({ topic: DAEMON_AVAILABILITY, payload: "offline", retain: true }, client.will)
  end

  def test_a_connected_daemon_says_it_is_here
    client = StandInMqttClient.new
    Ambx2mqtt::Broker.new(client).connect(reporting_availability_on: DAEMON_AVAILABILITY)

    assert_includes client.published,
                    { topic: DAEMON_AVAILABILITY, payload: "online", retain: true, qos: 0 }
  end

  def test_a_lamp_is_shown_as_reachable_only_while_both_the_daemon_and_its_set_are_here
    broker = StandInBroker.new
    set = Ambx2mqtt::Set.new(identity: "desk", connection: StandInConnection.new)

    Ambx2mqtt::Daemon.new(driver: StandInDriver.new(set), broker: broker,
                          memory: StandInMemory.new).run

    assert_equal [ DAEMON_AVAILABILITY, SET_AVAILABILITY ],
                 broker.announcement[:availability].map { |watched| watched[:topic] }
    assert_equal "all", broker.announcement[:availability_mode]
  end

  def test_a_running_daemon_connects_and_says_where_it_will_report_that_it_is_here
    broker = StandInBroker.new
    set = Ambx2mqtt::Set.new(identity: "desk", connection: StandInConnection.new)

    Ambx2mqtt::Daemon.new(driver: StandInDriver.new(set), broker: broker,
                          memory: StandInMemory.new).run

    assert_equal DAEMON_AVAILABILITY, broker.connected_reporting_on
  end
end
