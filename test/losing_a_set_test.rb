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

  private

  def lose_the_set_for(seconds)
    @daemon.look_around
    @broker.deliver("ambx2mqtt/desk/left/set", %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}}))
    @driver.unplug("desk")
    @daemon.look_around

    @clock.advance(seconds)
    @daemon.look_around
  end
end
