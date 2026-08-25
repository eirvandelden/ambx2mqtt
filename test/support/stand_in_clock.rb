# Stands in for the clock, so a two-day wait takes no time at all and the rounds
# happen when the test says so.
class StandInClock
  attr_reader :now

  def initialize(now = Time.utc(2026, 8, 25, 12))
    @now = now
  end

  def advance(seconds)
    @now += seconds
  end

  def every_round(&doing)
    @doing = doing
  end

  def next_round
    @doing.call
  end
end
