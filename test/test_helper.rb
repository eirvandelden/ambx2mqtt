require "minitest/autorun"
require "ambx2mqtt"

# The daemon says what it is doing; a test run is not the place for it. The one
# test about what it says gives itself a logger it can read.
Ambx2mqtt.logger = Logger.new(File::NULL)

Dir[File.expand_path("support/*.rb", __dir__)].sort.each { |stand_in| require stand_in }
