module Ambx2mqtt
  Colour = Data.define(:red, :green, :blue) do
    def self.from_home_assistant(colour)
      new(red: colour.fetch("r"), green: colour.fetch("g"), blue: colour.fetch("b"))
    end

    def to_home_assistant
      { r: red, g: green, b: blue }
    end
  end

  Colour::BLACK = Colour.new(red: 0, green: 0, blue: 0)
end
