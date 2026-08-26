require "test_helper"
require "stringio"

class WhatTheDaemonSaysTest < Minitest::Test
  def setup
    @said = StringIO.new
    @before = Ambx2mqtt.logger
    Ambx2mqtt.logger = Logger.new(@said)

    @controllers = StandInControllers.new(StandInController.new(identity: "port:1-2.2"))
    @clock = StandInClock.new
    @memory = StandInMemory.new
    @broker = StandInBroker.new
    @daemon = Ambx2mqtt::Daemon.new(
      driver: Ambx2mqtt::AmbxDriver.new(@controllers, configuration: Ambx2mqtt::Configuration.new("sets" => { "port_1_2_2" => "Living room" })),
      broker: @broker, memory: @memory, clock: @clock
    )
  end

  def teardown
    Ambx2mqtt.logger = @before
  end

  def test_a_set_that_turns_up_is_named_so_it_can_be_put_in_the_configuration
    @daemon.look_around

    assert_match(/port_1_2_2/, @said.string)
    assert_match(/Living room/, @said.string)
  end

  def test_a_set_that_goes_away_says_so
    @daemon.look_around
    @controllers.unplug("port:1-2.2")
    @daemon.look_around

    assert_match(/lost .*port_1_2_2/, @said.string)
  end

  def test_forgetting_a_set_altogether_says_so
    @daemon.look_around
    @controllers.unplug("port:1-2.2")
    @daemon.look_around
    @clock.advance(3 * 24 * 60 * 60)
    @daemon.look_around

    assert_match(/forget.*port_1_2_2/, @said.string)
  end

  def test_a_command_nobody_can_read_is_reported_as_such_rather_than_as_a_set_out_of_reach
    @daemon.look_around

    @broker.deliver("ambx2mqtt/port_1_2_2/left/set", "not json at all")

    assert_match(/ignoring a command .*port_1_2_2/, @said.string)
  end

  def test_a_command_for_a_set_that_has_gone_is_not_blamed_on_the_hardware
    @daemon.look_around
    @controllers.unplug("port:1-2.2")
    @daemon.look_around

    @broker.deliver("ambx2mqtt/port_1_2_2/left/set", %({"state":"ON"}))

    refute_match(/could not reach/, @said.string)
  end

  def test_a_controller_that_will_not_open_says_so_rather_than_disappearing_quietly
    @controllers.plug_in(StandInController.new(identity: "port:1-2.3", opens: false))

    @daemon.look_around

    assert_match(/port_1_2_3/, @said.string)
  end
end
