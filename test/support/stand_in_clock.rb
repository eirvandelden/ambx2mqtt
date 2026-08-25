# Stands in for the clock, so a two-day wait takes no time at all.
class StandInClock
  attr_reader :now

  def initialize(now = Time.utc(2026, 8, 25, 12))
    @now = now
  end

  def advance(seconds)
    @now += seconds
  end
end
