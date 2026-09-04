module Ambx2mqtt
  # Everything the daemon needs, built from what the configuration says.
  class Installation
    def initialize(configuration, controllers:)
      @configuration = configuration
      @controllers = controllers
    end

    def daemon
      Daemon.new(driver: driver, broker: broker, memory: memory)
    end

    # A broker is away for as long as it is away — a closed lid can mean hours.
    # Giving up after a handful of tries would leave the daemon running with
    # nothing to talk to, so it waits however long it takes.
    WAIT_HOWEVER_LONG_IT_TAKES = nil

    def client
      MQTT::Client.new(host: @configuration.broker_host, port: @configuration.broker_port,
                       username: @configuration.broker_username.reveal,
                       password: @configuration.broker_password.reveal,
                       client_id: NAME,
                       reconnect_limit: WAIT_HOWEVER_LONG_IT_TAKES)
    end

    private

    def driver
      AmbxDriver.new(@controllers, configuration: @configuration)
    end

    def broker
      Broker.new(client)
    end

    def memory
      RememberedState.new(@configuration.state_file)
    end
  end
end
