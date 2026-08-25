# Stands in for the USB driver, answering which sets are attached right now.
class StandInDriver
  def initialize(*sets)
    @sets = sets
  end

  def attached_sets
    @sets.dup
  end

  def unplug(identity)
    @sets.reject! { |set| set.identity == identity }
  end

  def plug_in(set)
    @sets << set
  end
end
