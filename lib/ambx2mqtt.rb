require "json"

module Ambx2mqtt
  NAME = "ambx2mqtt".freeze
  FULL_BRIGHTNESS = 255

  # The words Home Assistant uses for a light that is lit or dark.
  ON = "ON".freeze
  OFF = "OFF".freeze
end

require "ambx2mqtt/colour"
require "ambx2mqtt/lamp"
require "ambx2mqtt/lamp_command"
require "ambx2mqtt/set"
require "ambx2mqtt/topics"
require "ambx2mqtt/announcement"
require "ambx2mqtt/broker"
require "ambx2mqtt/daemon"
