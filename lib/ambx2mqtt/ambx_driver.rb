module Ambx2mqtt
  # The only place that knows about the libambx driver. Turns the controllers it
  # finds into sets the daemon can look after, one per physical amBX box.
  #
  # A set is kept for as long as its controller stays plugged in, because a
  # controller is opened once and its handle stays good. A controller that goes
  # away has its set dropped, so coming back gets a freshly opened one.
  class AmbxDriver
    UNSAFE_IN_A_TOPIC = /[^A-Za-z0-9_]/
    WHAT_THEY_ARE = "amBX".freeze

    def initialize(controllers, configuration:)
      @controllers = controllers
      @configuration = configuration
      @sets = {}
    end

    def attached_sets
      plugged_in = plugged_in_by_identity

      @sets.select! { |identity, _| plugged_in.key?(identity) }
      plugged_in.keys.sort.each_with_index do |identity, position|
        take_on(identity, plugged_in.fetch(identity), position)
      end

      @sets.values
    end

    private

    def plugged_in_by_identity
      @controllers.devices.each_with_object({}) do |controller, plugged_in|
        known_as = identify(controller)
        plugged_in[known_as] = controller if known_as
      end
    end

    # libambx says "serial:AB12CD34" or "port:1-2.3"; neither is safe to put in a
    # topic or a Home Assistant entity name as it stands.
    def identify(controller)
      controller.identity&.gsub(UNSAFE_IN_A_TOPIC, "_")
    end

    def take_on(identity, controller, position)
      return if @sets.key?(identity)

      unless controller.open
        Ambx2mqtt.logger.warn("the set #{identity} would not open; trying again next time")
        return
      end

      @sets[identity] = Set.new(identity: identity, connection: controller,
                                name: @configuration.name_for(identity) || plain_name(position),
                                sides_swapped: @configuration.sides_swapped?(identity))
    end

    # A set nobody has named is called after what it is, numbered from the
    # second onwards so two of them can be told apart.
    def plain_name(position)
      return WHAT_THEY_ARE if position.zero?

      "#{WHAT_THEY_ARE} #{position + 1}"
    end
  end
end
