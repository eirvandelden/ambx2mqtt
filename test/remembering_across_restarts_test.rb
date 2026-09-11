require "test_helper"
require "tmpdir"
require "fileutils"
require "json"

class RememberingAcrossRestartsTest < Minitest::Test
  COMMAND_TOPIC = "ambx2mqtt/desk/wallwasher_centre/set".freeze
  STATE_TOPIC = "ambx2mqtt/desk/wallwasher_centre/state".freeze
  RED_AT_HALF = %({"state":"ON","brightness":128,"color":{"r":255,"g":0,"b":0}}).freeze
  FAN_SPEED_COMMAND_TOPIC = "ambx2mqtt/desk/left_fan/speed/set".freeze
  FAN_STATE_TOPIC = "ambx2mqtt/desk/left_fan/state".freeze
  FAN_SPEED_STATE_TOPIC = "ambx2mqtt/desk/left_fan/speed/state".freeze

  def setup
    @directory = Dir.mktmpdir
    @path = File.join(@directory, "state.json")
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_a_set_that_comes_back_after_a_restart_returns_to_the_colours_it_had
    start_the_daemon { |broker| broker.deliver(COMMAND_TOPIC, RED_AT_HALF) }

    connection, = start_the_daemon

    assert_equal [ 0xA1, 0x3B, 0x03, 128, 0, 0 ], connection.commands.last
  end

  def test_a_set_that_comes_back_after_a_restart_tells_home_assistant_where_it_stands
    start_the_daemon { |broker| broker.deliver(COMMAND_TOPIC, RED_AT_HALF) }

    _, broker = start_the_daemon

    assert_equal({ "state" => "ON", "brightness" => 128, "color" => { "r" => 255, "g" => 0, "b" => 0 } },
                 broker.reported_settings(STATE_TOPIC))
  end

  def test_a_lamp_nobody_has_touched_yet_is_left_alone
    connection, = start_the_daemon

    assert_empty connection.commands
  end

  def test_a_memory_that_cannot_be_read_is_set_aside_and_the_daemon_starts_fresh
    File.write(@path, "this is not what we wrote")

    connection, = start_the_daemon

    assert_empty connection.commands
    assert_path_exists "#{@path}.unreadable", "the unreadable memory was not kept for inspection"
  end

  def test_a_memory_holding_something_other_than_lamp_settings_is_set_aside_too
    File.write(@path, "[]")

    connection, = start_the_daemon

    assert_empty connection.commands
    assert_path_exists "#{@path}.unreadable", "the unusable memory was not kept for inspection"
  end

  def test_a_memory_whose_last_seen_makes_no_sense_is_set_aside_rather_than_stopping_every_round
    File.write(@path, JSON.generate("desk" => { "last_seen" => "yesterday", "lamps" => {} }))

    connection, = start_the_daemon

    assert_empty connection.commands
    assert_path_exists "#{@path}.unreadable", "the unusable memory was not kept for inspection"
  end

  def test_a_fan_comes_back_after_a_restart_at_the_speed_it_had
    start_the_daemon(fans: true) { |broker| broker.deliver(FAN_SPEED_COMMAND_TOPIC, "128") }

    connection, = start_the_daemon(fans: true)

    assert_equal [ 0xA1, 0x5B, 0x03, 0, 0, 128 ], connection.commands.first
  end

  def test_a_fan_that_comes_back_after_a_restart_tells_home_assistant_where_it_stands
    start_the_daemon(fans: true) { |broker| broker.deliver(FAN_SPEED_COMMAND_TOPIC, "128") }

    _, broker = start_the_daemon(fans: true)

    assert_equal "ON", broker.reported(FAN_STATE_TOPIC)
    assert_equal "128", broker.reported(FAN_SPEED_STATE_TOPIC)
  end

  def test_a_fan_nobody_has_touched_yet_is_left_alone
    connection, = start_the_daemon(fans: true)

    assert_empty connection.commands
  end

  private

  def start_the_daemon(fans: false)
    connection = StandInConnection.new
    broker = StandInBroker.new
    set = Ambx2mqtt::Set.new(identity: "desk", connection: connection,
                             wiring: Ambx2mqtt::Wiring.new(fans: fans))

    Ambx2mqtt::Daemon.new(driver: StandInDriver.new(set), broker: broker,
                          memory: Ambx2mqtt::RememberedState.new(@path),
                          clock: StandInClock.new).run
    yield broker if block_given?

    [ connection, broker ]
  end
end
