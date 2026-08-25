module Ambx2mqtt
  # What each lamp was last asked for, kept on disk so a restart can ask again.
  # A memory that cannot be read is set aside and the daemon starts fresh.
  class RememberedState
    SET_ASIDE_SUFFIX = ".unreadable".freeze

    def initialize(path)
      @path = Pathname.new(path)
      @remembered = read
    end

    def for(set_identity, lamp_name)
      @remembered.dig(set_identity, lamp_name)
    end

    def remember(set_identity, lamp_name, asked)
      (@remembered[set_identity] ||= {})[lamp_name] = asked
      write
    end

    private

    def read
      return {} unless @path.exist?

      remembered = parse
      return remembered if remembered.is_a?(Hash)

      set_aside
      {}
    end

    def parse
      JSON.parse(@path.read)
    rescue JSON::ParserError
      nil
    end

    def set_aside
      @path.rename("#{@path}#{SET_ASIDE_SUFFIX}")
    end

    def write
      @path.dirname.mkpath
      @path.write(JSON.generate(@remembered))
    end
  end
end
