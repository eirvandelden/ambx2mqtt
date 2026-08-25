require "minitest/autorun"
require "ambx2mqtt"

Dir[File.expand_path("support/*.rb", __dir__)].sort.each { |stand_in| require stand_in }
