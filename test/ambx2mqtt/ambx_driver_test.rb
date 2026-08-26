require "test_helper"
require "stringio"

class AmbxDriverTest < Minitest::Test
  RED_AT_FULL = Ambx2mqtt::LampCommand.new("state" => "ON", "brightness" => 255,
                                          "color" => { "r" => 255, "g" => 0, "b" => 0 }).freeze

  def test_every_plugged_in_controller_becomes_a_set
    driver = driving(controller("serial:AB12CD34"), controller("serial:EF56GH78"))

    assert_equal %w[serial_AB12CD34 serial_EF56GH78], driver.attached_sets.map(&:identity)
  end

  def test_a_controller_without_a_serial_is_known_by_where_it_is_plugged_in
    driver = driving(controller("port:1-2.3"))

    assert_equal [ "port_1_2_3" ], driver.attached_sets.map(&:identity)
  end

  def test_a_set_is_called_what_the_configuration_calls_it
    driver = driving(controller("serial:AB12CD34"),
                     configuration: Ambx2mqtt::Configuration.new("sets" => { "serial_AB12CD34" => "Living room" }))

    assert_equal [ "Living room" ], driver.attached_sets.map(&:name)
  end

  def test_a_controller_that_will_not_open_is_left_out_and_tried_again_next_round
    stubborn = controller("serial:AB12CD34", opens: false)
    driver = driving(stubborn)

    assert_empty driver.attached_sets
    driver.attached_sets

    assert_equal 2, stubborn.times_opened
  end

  def test_a_controller_that_cannot_say_who_it_is_is_left_out
    driver = driving(controller(nil))

    assert_empty driver.attached_sets
  end

  def test_a_controller_that_stays_plugged_in_is_opened_only_once
    steady = controller("serial:AB12CD34")
    driver = driving(steady)

    3.times { driver.attached_sets }

    assert_equal 1, steady.times_opened
  end

  def test_a_controller_that_is_unplugged_and_comes_back_is_opened_afresh
    controllers = StandInControllers.new(controller("serial:AB12CD34"))
    driver = Ambx2mqtt::AmbxDriver.new(controllers, configuration: Ambx2mqtt::Configuration.new)
    driver.attached_sets

    controllers.unplug("serial:AB12CD34")
    driver.attached_sets

    returning = controller("serial:AB12CD34")
    controllers.plug_in(returning)
    driver.attached_sets

    assert_equal 1, returning.times_opened
  end


  def test_a_set_the_configuration_says_is_re_cabled_gets_its_speakers_the_other_way_round
    re_cabled = controller("serial:AB12CD34")
    driver = driving(re_cabled, configuration: Ambx2mqtt::Configuration.new(
      "sets" => { "serial_AB12CD34" => { "name" => "Living room", "sides_swapped" => true } }
    ))
    set = driver.attached_sets.first

    set.show(set.lamps.find { |lamp| lamp.name == "left" }, RED_AT_FULL)

    assert_equal [ 0xA1, 0x1B, 0x03, 255, 0, 0 ], re_cabled.written.last
  end

  def test_a_set_nobody_has_named_is_simply_called_ambx
    driver = driving(controller("port:1-2.2"))

    assert_equal [ "amBX" ], driver.attached_sets.map(&:name)
  end

  def test_a_second_unnamed_set_is_told_apart_by_a_number
    driver = driving(controller("port:1-2.3"), controller("port:1-2.2"))

    assert_equal [ "amBX", "amBX 2" ], driver.attached_sets.map(&:name)
  end

  def test_a_set_the_configuration_has_named_keeps_that_name
    driver = driving(controller("port:1-2.2"), controller("port:1-2.3"),
                     configuration: Ambx2mqtt::Configuration.new("sets" => { "port_1_2_3" => "Study" }))

    assert_equal [ "amBX", "Study" ], driver.attached_sets.map(&:name)
  end

  def test_two_controllers_that_end_up_with_the_same_name_are_not_silently_one_set
    said = StringIO.new
    before = Ambx2mqtt.logger
    Ambx2mqtt.logger = Logger.new(said)

    driving(controller("port:1-2"), controller("port_1_2")).attached_sets

    assert_match(/port_1_2/, said.string, "two controllers collapsed into one set without a word")
  ensure
    Ambx2mqtt.logger = before
  end

  private

  def controller(identity, opens: true)
    StandInController.new(identity: identity, opens: opens)
  end

  def driving(*controllers, configuration: Ambx2mqtt::Configuration.new)
    Ambx2mqtt::AmbxDriver.new(StandInControllers.new(*controllers), configuration: configuration)
  end
end
