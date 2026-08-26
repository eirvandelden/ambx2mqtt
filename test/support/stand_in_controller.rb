# Stands in for one amBX controller as the libambx driver hands it over.
class StandInController
  attr_reader :written, :times_opened

  def initialize(identity: "serial:AB12CD34", opens: true)
    @identity = identity
    @opens = opens
    @written = []
    @times_opened = 0
  end

  def identity
    @identity
  end

  def open
    @times_opened += 1
    @opens
  end

  def write(bytes)
    @written << bytes

    true
  end
end

# Stands in for libambx itself, answering which controllers are plugged in.
class StandInControllers
  def initialize(*controllers)
    @controllers = controllers
  end

  def devices
    @controllers.dup
  end

  def unplug(identity)
    @controllers.reject! { |controller| controller.identity == identity }
  end

  def plug_in(controller)
    @controllers << controller
  end
end

# Stands in for the configuration's answer to "what should this set be called?".
class StandInNames
  def initialize(names = {})
    @names = names
  end

  def name_for(identity)
    @names.fetch(identity, identity)
  end
end
