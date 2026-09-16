require "test_helper"

class BlowingAFanTest < Minitest::Test
  COMMAND_TOPIC = "ambx2mqtt/desk/left_fan/set".freeze
  STATE_TOPIC = "ambx2mqtt/desk/left_fan/state".freeze
  SPEED_COMMAND_TOPIC = "ambx2mqtt/desk/left_fan/speed/set".freeze
  SPEED_STATE_TOPIC = "ambx2mqtt/desk/left_fan/speed/state".freeze

  def setup
    @connection = StandInConnection.new
    @broker = StandInBroker.new

    set = Ambx2mqtt::Set.new(identity: "desk", connection: @connection,
                             wiring: Ambx2mqtt::Wiring.new(fans: true))
    Ambx2mqtt::Daemon.new(driver: StandInDriver.new(set), broker: @broker,
                          memory: StandInMemory.new,
                          clock: StandInClock.new).run
  end

  def test_starting_a_fan_nobody_has_given_a_speed_yet_barely_blows
    @broker.deliver(COMMAND_TOPIC, "ON")

    assert_equal [ [ 0xA1, 0x5B, 0x03, 0, 0, 1 ] ], @connection.commands
  end

  def test_stopping_a_fan_stills_it
    @broker.deliver(COMMAND_TOPIC, "ON")
    @broker.deliver(COMMAND_TOPIC, "OFF")

    assert_equal [ 0xA1, 0x5B, 0x03, 0, 0, 0 ], @connection.commands.last
  end

  def test_a_fan_that_was_started_is_reported_running
    @broker.deliver(COMMAND_TOPIC, "ON")

    assert_equal "ON", @broker.reported(STATE_TOPIC)
  end

  def test_a_fan_that_was_stopped_is_reported_stopped
    @broker.deliver(COMMAND_TOPIC, "OFF")

    assert_equal "OFF", @broker.reported(STATE_TOPIC)
  end

  def test_the_right_fan_is_driven_apart_from_the_left_one
    @broker.deliver("ambx2mqtt/desk/right_fan/set", "ON")

    assert_equal [ [ 0xA1, 0x6B, 0x03, 0, 0, 1 ] ], @connection.commands
  end

  def test_a_command_a_fan_cannot_read_leaves_it_alone
    @broker.deliver(COMMAND_TOPIC, "spin faster please")

    assert_empty @connection.commands
  end

  def test_a_fan_asked_for_half_speed_blows_at_half_speed
    @broker.deliver(SPEED_COMMAND_TOPIC, "128")

    assert_equal [ [ 0xA1, 0x5B, 0x03, 0, 0, 128 ] ], @connection.commands
  end

  def test_a_fan_asked_for_a_speed_reports_that_speed
    @broker.deliver(SPEED_COMMAND_TOPIC, "128")

    assert_equal "128", @broker.reported(SPEED_STATE_TOPIC)
  end

  def test_a_fan_asked_for_no_speed_at_all_stops_rather_than_crawling
    @broker.deliver(SPEED_COMMAND_TOPIC, "0")

    assert_equal [ [ 0xA1, 0x5B, 0x03, 0, 0, 0 ] ], @connection.commands
    assert_equal "OFF", @broker.reported(STATE_TOPIC)
  end

  def test_a_fan_started_again_comes_back_at_the_speed_it_had
    @broker.deliver(SPEED_COMMAND_TOPIC, "128")
    @broker.deliver(COMMAND_TOPIC, "OFF")
    @broker.deliver(COMMAND_TOPIC, "ON")

    assert_equal [ 0xA1, 0x5B, 0x03, 0, 0, 128 ], @connection.commands.last
  end

  def test_a_fan_asked_for_more_speed_than_it_has_blows_as_fast_as_it_can
    @broker.deliver(SPEED_COMMAND_TOPIC, "300")

    assert_equal [ [ 0xA1, 0x5B, 0x03, 0, 0, 255 ] ], @connection.commands
    assert_equal "255", @broker.reported(SPEED_STATE_TOPIC)
  end

  def test_a_fan_asked_for_less_than_no_speed_stops
    @broker.deliver(SPEED_COMMAND_TOPIC, "-5")

    assert_equal [ [ 0xA1, 0x5B, 0x03, 0, 0, 0 ] ], @connection.commands
    assert_equal "OFF", @broker.reported(STATE_TOPIC)
  end

  def test_a_speed_that_is_not_a_number_leaves_the_fan_alone
    @broker.deliver(SPEED_COMMAND_TOPIC, "quite fast")

    assert_empty @connection.commands
  end
end
