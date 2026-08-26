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
end
