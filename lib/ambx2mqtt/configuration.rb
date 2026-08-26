module Ambx2mqtt
  # What the daemon was told to do, read from a YAML file. It never holds a
  # password, only a Secret saying where one lives.
  class Configuration
    USUAL_BROKER_PORT = 1883
    STATE_FILE_AT_HOME = "~/.local/state/ambx2mqtt/state.json".freeze
    USUAL_LOG_LEVEL = :info

    def self.read(path)
      new(YAML.safe_load_file(path) || {})
    end

    def initialize(said = {})
      @said = said
    end

    def broker_host
      broker["host"]
    end

    def broker_port
      broker.fetch("port", USUAL_BROKER_PORT)
    end

    def broker_username
      broker["username"]
    end

    def broker_password
      Secret.new(broker["password"])
    end

    def state_file
      File.expand_path(@said.fetch("state_file", STATE_FILE_AT_HOME))
    end

    def log_level
      @said.fetch("log_level", USUAL_LOG_LEVEL).to_sym
    end

    def name_for(set_identity)
      names.fetch(set_identity, set_identity)
    end

    private

    def broker
      @said.fetch("broker", {})
    end

    def names
      @said.fetch("sets", {})
    end
  end
end
