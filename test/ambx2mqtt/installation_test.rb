require "test_helper"

class InstallationTest < Minitest::Test
  def test_everything_the_daemon_needs_is_built_from_what_the_configuration_says
    configuration = Ambx2mqtt::Configuration.new(
      "broker" => { "host" => "mqtt.home.arpa", "username" => "ambx2mqtt", "password" => "hunter2" },
      "state_file" => "/tmp/ambx2mqtt-test-state.json"
    )

    installation = Ambx2mqtt::Installation.new(configuration, controllers: StandInControllers.new)

    assert_instance_of Ambx2mqtt::Daemon, installation.daemon
  end

  def test_a_broker_that_is_away_a_long_while_is_still_waited_for
    assert_nil installation.client.reconnect_limit,
               "the daemon gives up on the broker, so a long sleep is never recovered from"
  end

  private

  def installation
    Ambx2mqtt::Installation.new(
      Ambx2mqtt::Configuration.new(
        "broker" => { "host" => "mqtt.home.arpa", "username" => "ambx2mqtt", "password" => "hunter2" },
        "state_file" => "/tmp/ambx2mqtt-test-state.json"
      ),
      controllers: StandInControllers.new
    )
  end
end
