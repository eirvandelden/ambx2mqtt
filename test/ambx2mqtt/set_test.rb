require "test_helper"

class SetTest < Minitest::Test
  RED = Ambx2mqtt::LampCommand.new("state" => "ON", "brightness" => 255,
                                   "color" => { "r" => 255, "g" => 0, "b" => 0 }).freeze

  def test_asking_for_the_left_lamp_drives_the_socket_the_left_speaker_is_plugged_into
    connection = StandInConnection.new
    set = Ambx2mqtt::Set.new(identity: "desk", connection: connection)

    set.carry_out(lamp_called("left", set), RED)

    assert_equal [ 0xA1, 0x0B, 0x03, 255, 0, 0 ], connection.commands.last
  end

  def test_a_set_whose_speakers_are_swapped_drives_the_other_socket_for_its_left_lamp
    connection = StandInConnection.new
    set = Ambx2mqtt::Set.new(identity: "desk", connection: connection,
                             wiring: Ambx2mqtt::Wiring.new(sides_swapped: true))

    set.carry_out(lamp_called("left", set), RED)

    assert_equal [ 0xA1, 0x1B, 0x03, 255, 0, 0 ], connection.commands.last
  end

  def test_swapping_the_speakers_leaves_the_wallwasher_alone
    connection = StandInConnection.new
    set = Ambx2mqtt::Set.new(identity: "desk", connection: connection,
                             wiring: Ambx2mqtt::Wiring.new(sides_swapped: true))

    set.carry_out(lamp_called("wallwasher left", set), RED)

    assert_equal [ 0xA1, 0x2B, 0x03, 255, 0, 0 ], connection.commands.last
  end

  def test_a_set_that_took_the_command_says_so
    set = Ambx2mqtt::Set.new(identity: "desk", connection: StandInConnection.new)

    assert_equal true, set.carry_out(lamp_called("left", set), RED)
  end

  def test_a_set_that_has_gone_says_the_command_did_not_land
    set = Ambx2mqtt::Set.new(identity: "desk", connection: UnpluggedConnection.new)

    assert_equal false, set.carry_out(lamp_called("left", set), RED)
  end

  def test_a_set_nobody_said_has_fans_has_none
    set = Ambx2mqtt::Set.new(identity: "desk", connection: StandInConnection.new)

    assert_empty set.fans
  end

  def test_a_set_that_has_fans_has_one_on_each_side
    set = Ambx2mqtt::Set.new(identity: "desk", connection: StandInConnection.new,
                             wiring: Ambx2mqtt::Wiring.new(fans: true))

    assert_equal [ "left fan", "right fan" ], set.fans.map(&:name)
  end

  private

  def lamp_called(name, set)
    set.lamps.find { |lamp| lamp.name == name }
  end
end
