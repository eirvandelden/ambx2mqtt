require "test_helper"

class ClockTest < Minitest::Test
  def test_the_clock_tells_the_time
    assert_kind_of Time, Ambx2mqtt::Clock.new.now
  end

  def test_the_rounds_keep_coming_after_one_of_them_goes_wrong
    rounds = Queue.new
    doing_rounds = Ambx2mqtt::Clock.new(seconds_between_rounds: 0).every_round do
      rounds << :round
      raise "something went wrong on this round" if rounds.size == 1
    end

    seen = 3.times.map { rounds.pop(timeout: 2) }
    doing_rounds.kill

    refute_includes seen, nil, "the rounds stopped after one of them went wrong"
  end
end
