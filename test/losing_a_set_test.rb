require "test_helper"

class LosingASetTest < Minitest::Test
  AVAILABILITY_TOPIC = "ambx2mqtt/desk/availability".freeze
  ONE_DAY = 24 * 60 * 60
  THREE_DAYS = 3 * ONE_DAY

  def setup
    @connection = StandInConnection.new
    @broker = StandInBroker.new
    @clock = StandInClock.new
    @set = Ambx2mqtt::Set.new(identity: "desk", connection: @connection)
    @driver = StandInDriver.new(@set)

    @memory = StandInMemory.new
    @daemon = Ambx2mqtt::Daemon.new(driver: @driver, broker: @broker,
                                    memory: @memory, clock: @clock)
  end

  def test_a_set_that_is_attached_is_available_in_home_assistant
    @daemon.look_around

    assert_equal "online", @broker.reported(AVAILABILITY_TOPIC)
  end

  def test_home_assistant_is_told_where_to_watch_for_a_set_going_away
    @daemon.look_around

    assert_includes @broker.announcement[:availability], { topic: AVAILABILITY_TOPIC }
  end

  def test_a_set_that_is_unplugged_becomes_unavailable
    @daemon.look_around
    @driver.unplug("desk")
    @daemon.look_around

    assert_equal "offline", @broker.reported(AVAILABILITY_TOPIC)
  end

  def test_a_set_that_comes_back_is_available_again
    @daemon.look_around
    @driver.unplug("desk")
    @daemon.look_around
    @driver.plug_in(@set)
    @daemon.look_around

    assert_equal "online", @broker.reported(AVAILABILITY_TOPIC)
  end

  def test_a_set_unseen_for_two_days_disappears_from_home_assistant_altogether
    lose_the_set_for(THREE_DAYS)

    assert @broker.forgotten?("ambx2mqtt_desk"), "Home Assistant was never told to drop the set"
  end

  def test_a_set_unseen_for_two_days_is_forgotten_from_the_memory_too
    lose_the_set_for(THREE_DAYS)

    assert_nil @memory.for("desk", "left"), "the set's lamps are still remembered"
  end

  def test_a_set_gone_only_a_day_keeps_its_place_in_home_assistant
    lose_the_set_for(ONE_DAY)

    refute @broker.forgotten?("ambx2mqtt_desk"), "the set was dropped before its two days were up"
  end

  def test_a_set_that_comes_back_the_next_day_lights_up_the_colours_it_had
    @daemon.look_around
    @broker.deliver("ambx2mqtt/desk/left/set", %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}}))
    @driver.unplug("desk")
    @daemon.look_around

    @clock.advance(ONE_DAY)
    @driver.plug_in(@set)
    @daemon.look_around

    assert_equal [ 0xA1, 0x0B, 0x03, 255, 0, 0 ], @connection.commands.last
  end

  def test_a_running_daemon_keeps_looking_around_so_a_set_that_goes_is_noticed
    @daemon.run
    @driver.unplug("desk")
    @clock.next_round

    assert_equal "offline", @broker.reported(AVAILABILITY_TOPIC)
  end

  def test_a_set_unplugged_midway_through_a_command_does_not_take_the_daemon_down
    daemon = daemon_over(Ambx2mqtt::Set.new(identity: "desk", connection: VanishedConnection.new))
    daemon.look_around

    @broker.deliver("ambx2mqtt/desk/left/set", %({"state":"ON","color":{"r":255,"g":0,"b":0}}))

    assert_equal "offline", @broker.reported("ambx2mqtt/desk/availability")
  end

  def test_a_set_that_says_the_command_did_not_land_is_marked_unavailable
    daemon = daemon_over(Ambx2mqtt::Set.new(identity: "desk", connection: UnpluggedConnection.new))
    daemon.look_around

    @broker.deliver("ambx2mqtt/desk/left/set", %({"state":"ON","color":{"r":255,"g":0,"b":0}}))

    assert_equal "offline", @broker.reported("ambx2mqtt/desk/availability")
  end

  def test_a_set_that_was_already_away_when_the_daemon_started_is_reported_away
    @memory.seen("attic", @clock.now)

    @daemon.look_around

    assert_equal "offline", @broker.reported("ambx2mqtt/attic/availability")
  end

  def test_a_set_that_stays_away_is_not_announced_as_away_over_and_over
    @memory.seen("attic", @clock.now)
    @daemon.look_around
    @broker.forget_what_was_reported("ambx2mqtt/attic/availability")

    @daemon.look_around

    refute @broker.reported?("ambx2mqtt/attic/availability"),
           "the daemon keeps repeating that a set it lost long ago is away"
  end

  def test_a_set_that_fails_while_it_is_arriving_is_not_left_looking_reachable
    @memory.remember("desk", "left", { "state" => "ON", "brightness" => 255,
                                       "color" => { "r" => 255, "g" => 0, "b" => 0 } })
    daemon = daemon_over(Ambx2mqtt::Set.new(identity: "desk", connection: VanishedConnection.new))

    daemon.look_around

    assert_equal "offline", @broker.reported("ambx2mqtt/desk/availability")
  end

  def test_a_set_that_keeps_failing_is_not_announced_afresh_every_round
    @memory.remember("desk", "left", { "state" => "ON", "brightness" => 255,
                                       "color" => { "r" => 255, "g" => 0, "b" => 0 } })
    daemon = daemon_over(Ambx2mqtt::Set.new(identity: "desk", connection: VanishedConnection.new))

    4.times { daemon.look_around }

    assert_equal 1, @broker.announcements.size,
                 "the daemon keeps announcing a set it cannot reach"
  end

  def test_a_daemon_that_cannot_reach_the_broker_leaves_the_sets_alone
    broker = StandInBroker.new(connected: false)
    driver = StandInDriver.new(Ambx2mqtt::Set.new(identity: "desk", connection: @connection))

    Ambx2mqtt::Daemon.new(driver: driver, broker: broker, memory: @memory, clock: @clock).look_around

    assert_nil driver.times_asked,
               "the daemon took hold of the sets while it had nowhere to tell anyone about them"
  end

  private

  def daemon_over(set)
    Ambx2mqtt::Daemon.new(driver: StandInDriver.new(set), broker: @broker,
                          memory: @memory, clock: @clock)
  end

  def lose_the_set_for(seconds)
    @daemon.look_around
    @broker.deliver("ambx2mqtt/desk/left/set", %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}}))
    @driver.unplug("desk")
    @daemon.look_around

    @clock.advance(seconds)
    @daemon.look_around
  end
end
