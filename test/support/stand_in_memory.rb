# Stands in for the memory of what each part of a set was last asked for, without
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

  def for(set_identity, part_name)
    @remembered.dig(set_identity, part_name)
  end

  def remember(set_identity, part_name, asked)
    (@remembered[set_identity] ||= {})[part_name] = asked
  end
end
