# Stands in for the memory of what each lamp was last asked for, without
# touching the disk.
class StandInMemory
  def initialize(remembered = {})
    @remembered = remembered
    @last_seen = {}
  end

  def seen(set_identity, at)
    @last_seen[set_identity] = at
  end

  def known
    @last_seen.dup
  end

  def forget(set_identity)
    @remembered.delete(set_identity)
    @last_seen.delete(set_identity)
  end

  def for(set_identity, lamp_name)
    @remembered.dig(set_identity, lamp_name)
  end

  def remember(set_identity, lamp_name, asked)
    (@remembered[set_identity] ||= {})[lamp_name] = asked
  end
end
