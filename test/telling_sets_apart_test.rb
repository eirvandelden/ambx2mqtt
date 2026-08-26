require "test_helper"

class TellingSetsApartTest < Minitest::Test
  LIVING_ROOM = "serial:AB12CD34".freeze
  STUDY = "serial:EF56GH78".freeze
  RED_AT_FULL = %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}}).freeze

  def setup
    @living_room = StandInController.new(identity: LIVING_ROOM)
    @study = StandInController.new(identity: STUDY)
    @broker = StandInBroker.new
    configuration = Ambx2mqtt::Configuration.new(
      "sets" => { "serial_AB12CD34" => "Living room", "serial_EF56GH78" => "Study" }
    )
    driver = Ambx2mqtt::AmbxDriver.new(StandInControllers.new(@living_room, @study), configuration: configuration)

    Ambx2mqtt::Daemon.new(driver: driver, broker: @broker, memory: StandInMemory.new,
                          clock: StandInClock.new).run
  end

  def test_turning_one_sets_left_lamp_red_leaves_the_other_set_dark
    @broker.deliver("ambx2mqtt/serial_AB12CD34/left/set", RED_AT_FULL)

    assert_equal [ [ 0xA1, 0x0B, 0x03, 255, 0, 0 ] ], @living_room.written
    assert_empty @study.written
  end

  def test_both_sets_appear_in_home_assistant_under_the_names_they_were_given
    assert_equal [ "Living room", "Study" ],
                 @broker.announcements.map { |announcement| announcement[:device][:name] }
  end

  def test_each_set_keeps_its_lamps_to_itself
    assert_equal [ "ambx2mqtt_serial_AB12CD34_left", "ambx2mqtt_serial_EF56GH78_left" ],
                 @broker.announcements.map { |announcement| announcement[:lamps].first[:unique_id] }
  end
end
