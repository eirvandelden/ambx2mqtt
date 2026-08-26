require "test_helper"

class LightingALampTest < Minitest::Test
  COMMAND_TOPIC = "ambx2mqtt/desk/wallwasher_centre/set".freeze
  STATE_TOPIC = "ambx2mqtt/desk/wallwasher_centre/state".freeze

  def setup
    @connection = StandInConnection.new
    @broker = StandInBroker.new

    set = Ambx2mqtt::Set.new(identity: "desk", connection: @connection)
    Ambx2mqtt::Daemon.new(driver: StandInDriver.new(set), broker: @broker,
                          memory: StandInMemory.new,
                          clock: StandInClock.new).run
  end

  def test_the_daemon_listens_for_commands_for_as_long_as_it_runs
    assert @broker.listening?, "the daemon ran without ever listening to the broker"
  end

  def test_turning_the_wallwasher_centre_lamp_red_sends_a_red_command_to_the_set
    ask_for %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}})

    assert_equal [ [ 0xA1, 0x3B, 0x03, 255, 0, 0 ] ], @connection.commands
  end

  def test_turning_the_wallwasher_centre_lamp_red_reports_it_red_to_home_assistant
    ask_for %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}})

    assert_equal({ "state" => "ON", "brightness" => 255, "color" => { "r" => 255, "g" => 0, "b" => 0 } },
                 @broker.reported_settings(STATE_TOPIC))
  end

  def test_a_lamp_asked_for_a_colour_without_a_brightness_burns_at_full
    ask_for %({"state":"ON","color":{"r":255,"g":0,"b":0}})

    assert_equal [ [ 0xA1, 0x3B, 0x03, 255, 0, 0 ] ], @connection.commands
  end

  def test_dimming_a_lamp_to_half_sends_half_the_colour_to_the_hardware
    ask_for %({"state":"ON","brightness":128,"color":{"r":255,"g":0,"b":0}})

    assert_equal [ [ 0xA1, 0x3B, 0x03, 128, 0, 0 ] ], @connection.commands
  end

  def test_dimming_a_lamp_reports_the_colour_and_the_brightness_apart
    ask_for %({"state":"ON","brightness":128,"color":{"r":255,"g":0,"b":0}})

    assert_equal({ "state" => "ON", "brightness" => 128, "color" => { "r" => 255, "g" => 0, "b" => 0 } },
                 @broker.reported_settings(STATE_TOPIC))
  end

  def test_turning_a_lamp_off_darkens_the_hardware
    ask_for %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}})
    ask_for %({"state":"OFF"})

    assert_equal [ 0xA1, 0x3B, 0x03, 0, 0, 0 ], @connection.commands.last
  end

  def test_a_lamp_that_is_off_still_remembers_the_colour_it_was_given
    ask_for %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}})
    ask_for %({"state":"OFF"})

    assert_equal({ "state" => "OFF", "brightness" => 255, "color" => { "r" => 255, "g" => 0, "b" => 0 } },
                 @broker.reported_settings(STATE_TOPIC))
  end

  def test_turning_a_lamp_back_on_brings_back_the_colour_it_had
    ask_for %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}})
    ask_for %({"state":"OFF"})
    ask_for %({"state":"ON"})

    assert_equal [ 0xA1, 0x3B, 0x03, 255, 0, 0 ], @connection.commands.last
  end

  def test_a_command_nobody_can_read_is_ignored_rather_than_taking_the_daemon_down
    ask_for "not json at all"

    assert_empty @connection.commands
  end

  def test_a_command_nobody_can_read_leaves_the_set_reachable
    ask_for "not json at all"

    assert_equal "online", @broker.reported("ambx2mqtt/desk/availability")
  end

  def test_a_command_that_never_says_whether_to_light_up_is_ignored_too
    ask_for %({"brightness":128})

    assert_equal "online", @broker.reported("ambx2mqtt/desk/availability")
  end

  private

  def ask_for(payload)
    @broker.deliver(COMMAND_TOPIC, payload)
  end
end
