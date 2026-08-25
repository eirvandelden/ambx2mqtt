# Stands in for the memory of what each lamp was last asked for, without
# touching the disk.
class StandInMemory
  def initialize(remembered = {})
    @remembered = remembered
  end

  def for(set_identity, lamp_name)
    @remembered.dig(set_identity, lamp_name)
  end

  def remember(set_identity, lamp_name, asked)
    (@remembered[set_identity] ||= {})[lamp_name] = asked
  end
end
