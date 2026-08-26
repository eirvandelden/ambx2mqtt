require "test_helper"
require "tmpdir"

class StartingTheDaemonTest < Minitest::Test
  def test_a_daemon_started_from_a_configuration_looks_after_the_sets_that_are_plugged_in
    Dir.mktmpdir do |somewhere|
      client = StandInMqttClient.new

      daemon = Ambx2mqtt::Daemon.looking_after(configuration_storing_state_in(somewhere),
                                               controllers: StandInControllers.new(StandInController.new),
                                               client: client)
      daemon.look_around

      assert_includes published_topics(client), "homeassistant/device/ambx2mqtt_serial_AB12CD34/config"
    end
  end

  private

  def configuration_storing_state_in(directory)
    Ambx2mqtt::Configuration.new("state_file" => File.join(directory, "state.json"))
  end

  def published_topics(client)
    client.published.map { |message| message[:topic] }
  end
end
