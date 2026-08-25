module Ambx2mqtt
  class CannotReadSecret < StandardError; end

  # A configuration value that says where a secret lives rather than holding it.
  # An op:// reference is read from 1Password; anything else is used as it stands.
  # Printing a secret never shows it.
  class Secret
    ONE_PASSWORD_PREFIX = "op://".freeze
    ONE_PASSWORD = "op".freeze
    HIDDEN = "[secret]".freeze

    def initialize(value, shell: Open3)
      @value = value
      @shell = shell
    end

    def reveal
      return @value unless kept_in_one_password?

      read_from_one_password
    end

    def to_s
      return @value if kept_in_one_password?

      HIDDEN
    end

    alias_method :inspect, :to_s

    private

    def kept_in_one_password?
      @value.is_a?(String) && @value.start_with?(ONE_PASSWORD_PREFIX)
    end

    def read_from_one_password
      secret, status = @shell.capture2(ONE_PASSWORD, "read", "--no-newline", @value)
      raise CannotReadSecret, "1Password would not give up #{@value}" unless status.success?

      secret
    end
  end
end
