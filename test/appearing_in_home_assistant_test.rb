require "test_helper"

class AppearingInHomeAssistantTest < Minitest::Test
  def setup
    @broker = StandInBroker.new
    set = Ambx2mqtt::Set.new(identity: "desk", connection: StandInConnection.new)

    Ambx2mqtt::Daemon.new(driver: StandInDriver.new(set), broker: @broker,
                          memory: StandInMemory.new,
                          clock: StandInClock.new).run
  end

  def test_a_set_appears_in_home_assistant_as_one_device
    assert_equal "ambx2mqtt_desk", announcement[:device_id]
    assert_equal "desk", announcement[:device][:name]
  end

  def test_the_device_carries_all_five_lamps
    assert_equal [ "Left", "Right", "Wallwasher left", "Wallwasher centre", "Wallwasher right" ],
                 lamps.map { |lamp| lamp[:name] }
  end

  def test_every_lamp_is_offered_to_home_assistant_as_a_light
    assert_equal [ "light" ] * 5, lamps.map { |lamp| lamp[:platform] }
  end

  def test_each_lamp_takes_its_own_colour_and_brightness
    left = lamps.first

    assert_equal "ambx2mqtt/desk/left/set", left[:command_topic]
    assert_equal "ambx2mqtt/desk/left/state", left[:state_topic]
    assert_equal [ "rgb" ], left[:supported_color_modes]
    assert left[:brightness], "the lamp does not offer brightness"
  end

  def test_each_lamp_keeps_its_own_name_across_restarts
    assert_equal [ "ambx2mqtt_desk_left", "ambx2mqtt_desk_right", "ambx2mqtt_desk_wallwasher_left",
                   "ambx2mqtt_desk_wallwasher_centre", "ambx2mqtt_desk_wallwasher_right" ],
                 lamps.map { |lamp| lamp[:unique_id] }
  end

  def test_a_set_that_has_been_given_a_name_shows_that_name_in_home_assistant
    broker = StandInBroker.new
    set = Ambx2mqtt::Set.new(identity: "AB12CD34", name: "Living room",
                             connection: StandInConnection.new)

    Ambx2mqtt::Daemon.new(driver: StandInDriver.new(set), broker: broker,
                          memory: StandInMemory.new,
                          clock: StandInClock.new).run

    assert_equal "Living room", broker.announcement[:device][:name]
  end

  private

  def announcement
    @broker.announcement
  end

  def lamps
    announcement[:components].values
  end
end
