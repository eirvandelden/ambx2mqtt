module Ambx2mqtt
  # What the daemon remembers about each set between runs: when it was last seen,
  # and what each of its parts was last asked for. A memory that cannot be read is
  # set aside and the daemon starts fresh.
  class RememberedState
    SET_ASIDE_SUFFIX = ".unreadable".freeze
    LAST_SEEN = "last_seen".freeze
    # The key in the file still says lamps, from before a set could have fans.
    # Renaming it would throw away every remembered colour for nothing.
    PARTS = "lamps".freeze

    def initialize(path)
      @path = Pathname.new(path)
      @remembered = read
    end

    def for(set_identity, part_name)
      @remembered.dig(set_identity, PARTS, part_name)
    end

    def remember(set_identity, part_name, asked)
      parts_of(set_identity)[part_name] = asked
      write
    end

    def seen(set_identity, at)
      about(set_identity)[LAST_SEEN] = at.utc.iso8601
      write
    end

    def known
      @remembered.filter_map do |set_identity, about|
        last_seen = last_seen_of(about)
        [ set_identity, last_seen ] if last_seen
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

    def parts_of(set_identity)
      about(set_identity)[PARTS] ||= {}
    end

    def read
      return {} unless @path.exist?

      remembered = parse
      return remembered if usable?(remembered)

      set_aside
      {}
    end

    # A memory the daemon cannot make sense of is no better than one it cannot
    # read: a last seen date it does not understand would stop every round.
    def usable?(remembered)
      return false unless remembered.is_a?(Hash)

      remembered.each_value { |about| last_seen_of(about) }
      true
    rescue ArgumentError, TypeError
      false
    end

    def last_seen_of(about)
      return unless about.is_a?(Hash) && about[LAST_SEEN]

      Time.iso8601(about[LAST_SEEN])
    end

    def parse
      JSON.parse(@path.read)
    rescue JSON::ParserError
      nil
    end

    def set_aside
      @path.rename("#{@path}#{SET_ASIDE_SUFFIX}")
    end

    # Written beside the real file and moved into place, so a crash partway
    # through leaves the last good memory rather than half of a new one.
    def write
      @path.dirname.mkpath
      being_written = Pathname.new("#{@path}.writing")
      being_written.write(JSON.generate(@remembered))
      being_written.rename(@path)
    end
  end
end
