require "test_helper"
require "stringio"

class TheRoundsKeepingUpTest < Minitest::Test
  def setup
    @said = StringIO.new
    @before = Ambx2mqtt.logger
    Ambx2mqtt.logger = Logger.new(@said)
    @broker = StandInBroker.new
    @clock = StandInClock.new
    @driver = DriverThatFailsOnce.new(Ambx2mqtt::Set.new(identity: "desk", connection: StandInConnection.new))
    @daemon = Ambx2mqtt::Daemon.new(driver: @driver, broker: @broker,
                                    memory: StandInMemory.new, clock: @clock)
  end

  def teardown
    Ambx2mqtt.logger = @before
  end

  def test_a_round_that_goes_wrong_says_so_rather_than_going_quiet
    @daemon.run
    @driver.fail_next_time

    @clock.next_round

    assert_match(/the bus would not answer/, @said.string)
  end

  def test_a_round_that_goes_wrong_is_not_the_last_round
    @daemon.run
    @driver.fail_next_time

    @clock.next_round
    @clock.next_round

    assert_equal 3, @driver.rounds
  end
end

# A driver that answers once with trouble, the way a USB enumeration can.
class DriverThatFailsOnce < StandInDriver
  attr_reader :rounds

  def initialize(*sets)
    super
    @rounds = 0
    @failing = false
  end

  def fail_next_time
    @failing = true
  end

  def attached_sets
    @rounds += 1
    raise "the bus would not answer" if @failing.tap { @failing = false }

    super
  end
end
