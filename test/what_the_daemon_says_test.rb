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
    @driver = Ambx2mqtt::AmbxDriver.new(
      @controllers,
      configuration: Ambx2mqtt::Configuration.new("sets" => { "port_1_2_2" => "Living room" })
    )
    @daemon = Ambx2mqtt::Daemon.new(driver: @driver, broker: StandInBroker.new,
                                    memory: @memory, clock: @clock)
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

  def test_a_controller_that_will_not_open_says_so_rather_than_disappearing_quietly
    @controllers.plug_in(StandInController.new(identity: "port:1-2.3", opens: false))

    @daemon.look_around

    assert_match(/port_1_2_3/, @said.string)
  end

  def test_a_daemon_waiting_for_the_broker_says_so_once_rather_than_every_round
    broker = StandInBroker.new(connected: false)
    daemon = Ambx2mqtt::Daemon.new(driver: @driver, broker: broker, memory: @memory, clock: @clock)

    3.times { daemon.look_around }

    assert_equal 1, @said.string.scan(/waiting for the broker/).size,
                 "a daemon waiting for the broker either says nothing or will not stop saying it"
  end

  def test_a_daemon_that_was_waiting_says_when_the_broker_answers_again
    broker = StandInBroker.new(connected: false)
    daemon = Ambx2mqtt::Daemon.new(driver: @driver, broker: broker, memory: @memory, clock: @clock)
    daemon.look_around

    broker.answer_again
    daemon.look_around

    assert_match(/the broker answered/, @said.string)
  end
end
