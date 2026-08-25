module Ambx2mqtt
  # What the daemon remembers about each set between runs: when it was last seen,
  # and what each of its lamps was last asked for. A memory that cannot be read is
  # set aside and the daemon starts fresh.
  class RememberedState
    SET_ASIDE_SUFFIX = ".unreadable".freeze
    LAST_SEEN = "last_seen".freeze
    LAMPS = "lamps".freeze

    def initialize(path)
      @path = Pathname.new(path)
      @remembered = read
    end

    def for(set_identity, lamp_name)
      @remembered.dig(set_identity, LAMPS, lamp_name)
    end

    def remember(set_identity, lamp_name, asked)
      lamps_of(set_identity)[lamp_name] = asked
      write
    end

    def seen(set_identity, at)
      about(set_identity)[LAST_SEEN] = at.utc.iso8601
      write
    end

    def known
      @remembered.filter_map do |set_identity, about|
        last_seen = about[LAST_SEEN]
        [ set_identity, Time.iso8601(last_seen) ] if last_seen
      end.to_h
    end

    def forget(set_identity)
      @remembered.delete(set_identity)
      write
    end

    private

    def about(set_identity)
      @remembered[set_identity] ||= {}
    end

    def lamps_of(set_identity)
      about(set_identity)[LAMPS] ||= {}
    end

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
