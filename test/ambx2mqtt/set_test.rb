require "test_helper"

class SetTest < Minitest::Test
  RED = Ambx2mqtt::LampCommand.new("state" => "ON", "brightness" => 255,
                                   "color" => { "r" => 255, "g" => 0, "b" => 0 }).freeze

  def test_asking_for_the_left_lamp_drives_the_socket_the_left_speaker_is_plugged_into
    connection = StandInConnection.new
    set = Ambx2mqtt::Set.new(identity: "desk", connection: connection)

    set.show(lamp_called("left", set), RED)

    assert_equal [ 0xA1, 0x0B, 0x03, 255, 0, 0 ], connection.commands.last
  end

  def test_a_set_whose_speakers_are_swapped_drives_the_other_socket_for_its_left_lamp
    connection = StandInConnection.new
    set = Ambx2mqtt::Set.new(identity: "desk", connection: connection, sides_swapped: true)

    set.show(lamp_called("left", set), RED)

    assert_equal [ 0xA1, 0x1B, 0x03, 255, 0, 0 ], connection.commands.last
  end

  def test_swapping_the_speakers_leaves_the_wallwasher_alone
    connection = StandInConnection.new
    set = Ambx2mqtt::Set.new(identity: "desk", connection: connection, sides_swapped: true)

    set.show(lamp_called("wallwasher left", set), RED)

    assert_equal [ 0xA1, 0x2B, 0x03, 255, 0, 0 ], connection.commands.last
  end

  private

  def lamp_called(name, set)
    set.lamps.find { |lamp| lamp.name == name }
  end
end
