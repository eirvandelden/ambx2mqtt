require "test_helper"

class ConfigurationTest < Minitest::Test
  EXAMPLE = File.expand_path("../../config/ambx2mqtt.example.yml", __dir__).freeze

  def test_the_broker_is_read_from_the_file
    configuration = configured("broker" => { "host" => "mqtt.home.arpa", "port" => 8883,
                                             "username" => "ambx2mqtt" })

    assert_equal "mqtt.home.arpa", configuration.broker_host
    assert_equal 8883, configuration.broker_port
    assert_equal "ambx2mqtt", configuration.broker_username
  end

  def test_a_broker_with_no_port_of_its_own_is_reached_the_usual_way
    assert_equal 1883, configured("broker" => { "host" => "mqtt.home.arpa" }).broker_port
  end

  def test_the_broker_password_says_where_it_lives_and_never_shows_itself
    configuration = configured("broker" => { "password" => "op://Familie/MqttBroker/password" })

    assert_equal "op://Familie/MqttBroker/password", configuration.broker_password.to_s
  end

  def test_the_memory_lives_where_the_file_says
    configuration = configured("state_file" => "/var/lib/ambx2mqtt/state.json")

    assert_equal "/var/lib/ambx2mqtt/state.json", configuration.state_file
  end

  def test_a_memory_with_no_home_of_its_own_lives_under_the_users_own_state_directory
    assert_equal File.expand_path("~/.local/state/ambx2mqtt/state.json"), configured.state_file
  end

  def test_a_set_can_be_given_a_name_a_person_would_recognise
    configuration = configured("sets" => { "AB12CD34" => "Living room" })

    assert_equal "Living room", configuration.name_for("AB12CD34")
  end

  def test_a_set_nobody_has_named_is_called_by_the_only_name_it_has
    assert_equal "AB12CD34", configured.name_for("AB12CD34")
  end

  def test_the_example_that_ships_with_the_daemon_can_actually_be_read
    configuration = Ambx2mqtt::Configuration.read(EXAMPLE)

    assert_equal 1883, configuration.broker_port
    assert_match %r{\Aop://}, configuration.broker_password.to_s
  end

  private

  def configured(said = {})
    Ambx2mqtt::Configuration.new(said)
  end
end
