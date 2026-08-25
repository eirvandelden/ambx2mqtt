require "test_helper"

class SecretTest < Minitest::Test
  REFERENCE = "op://Familie/MqttBroker/password".freeze

  def test_a_password_kept_in_one_password_is_read_from_there
    shell = StandInShell.new("hunter2")

    secret = Ambx2mqtt::Secret.new(REFERENCE, shell: shell)

    assert_equal "hunter2", secret.reveal
    assert_equal [ "op", "read", "--no-newline", REFERENCE ], shell.ran
  end

  def test_a_password_written_out_in_the_configuration_is_used_as_it_stands
    shell = StandInShell.new

    secret = Ambx2mqtt::Secret.new("hunter2", shell: shell)

    assert_equal "hunter2", secret.reveal
    assert_nil shell.ran, "1Password was asked about a password that was already there"
  end

  def test_a_secret_that_cannot_be_read_says_where_it_was_looking_and_not_what_it_found
    secret = Ambx2mqtt::Secret.new(REFERENCE, shell: StandInShell.new("", success: false))

    error = assert_raises(Ambx2mqtt::CannotReadSecret) { secret.reveal }

    assert_includes error.message, REFERENCE
  end

  def test_a_secret_never_shows_itself_when_it_is_printed
    assert_equal "[secret]", Ambx2mqtt::Secret.new("hunter2").to_s
    assert_equal "[secret]", Ambx2mqtt::Secret.new("hunter2").inspect
  end

  def test_a_secret_kept_in_one_password_shows_where_it_lives
    assert_equal REFERENCE, Ambx2mqtt::Secret.new(REFERENCE).to_s
  end
end
