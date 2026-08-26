require "test_helper"
require "timeout"

class ClockTest < Minitest::Test
  def test_the_rounds_keep_coming_one_after_another
    rounds = Queue.new
    marking_rounds = Ambx2mqtt::Clock.new(seconds_between_rounds: 0.01).every_round { rounds << :round }

    two_rounds = Timeout.timeout(2) { [ rounds.pop, rounds.pop ] }

    assert_equal [ :round, :round ], two_rounds
  ensure
    marking_rounds&.kill
  end
end
