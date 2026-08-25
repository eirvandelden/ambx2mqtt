require "test_helper"

class LightingALampTest < Minitest::Test
  def setup
    @connection = StandInConnection.new
    @broker = StandInBroker.new

    set = Ambx2mqtt::Set.new(identity: "desk", connection: @connection)
    Ambx2mqtt::Daemon.new(sets: [ set ], broker: @broker).run
  end

  def test_the_daemon_listens_for_commands_for_as_long_as_it_runs
    assert @broker.listening?, "the daemon ran without ever listening to the broker"
  end

  def test_turning_the_wallwasher_centre_lamp_red_sends_a_red_command_to_the_set
    turn_the_wallwasher_centre_red

    assert_equal [ [ 0xA1, 0x3B, 0x03, 255, 0, 0 ] ], @connection.commands
  end

  def test_turning_the_wallwasher_centre_lamp_red_reports_it_red_to_home_assistant
    turn_the_wallwasher_centre_red

    assert_equal({ "state" => "ON", "color" => { "r" => 255, "g" => 0, "b" => 0 } },
                 @broker.reported("ambx2mqtt/desk/wallwasher_centre/state"))
  end

  private

  def turn_the_wallwasher_centre_red
    @broker.deliver("ambx2mqtt/desk/wallwasher_centre/set",
                    %({"state":"ON","color":{"r":255,"g":0,"b":0}}))
  end
end
