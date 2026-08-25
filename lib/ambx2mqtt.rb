require "json"
require "pathname"
require "time"
require "open3"
require "yaml"

module Ambx2mqtt
  NAME = "ambx2mqtt".freeze
  FULL_BRIGHTNESS = 255

  # The words Home Assistant uses for a light that is lit or dark.
  ON = "ON".freeze
  OFF = "OFF".freeze

  # The words Home Assistant uses for a set it can and cannot reach.
  ONLINE = "online".freeze
  OFFLINE = "offline".freeze
end

require "ambx2mqtt/secret"
require "ambx2mqtt/configuration"
require "ambx2mqtt/clock"
require "ambx2mqtt/colour"
require "ambx2mqtt/lamp"
require "ambx2mqtt/lamp_command"
require "ambx2mqtt/set"
require "ambx2mqtt/topics"
require "ambx2mqtt/announcement"
require "ambx2mqtt/remembered_state"
require "ambx2mqtt/broker"
require "ambx2mqtt/daemon"
