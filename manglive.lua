-- Live Mangl with Midi Fighter Twister

engine.name = "LMGlut"

local inspect = require "manglive/lib/inspect" -- why not "lib/inspect"?

local mft   = midi.connect(1)
local bank  = 1
local knobs = {}

local B = {
  OFF = 18,
  MID = 32,
  HI = 47
}

local C = {
  RED = 74,
  YELLOW = 63
}

-- utils

function clamp(i, min, max)
  return math.max(math.min(i, max), min)
end

function scale(x, i_min, i_max, o_min, o_max)
  return (o_max - o_min) * (x - i_min) / (i_max - i_min) + o_min;
end

function mft_dir(data)
  return data.val > 64 and 1 or -1
end

-- Knob

local Knob = {}

function Knob:new(o)
  o = setmetatable(o, self)
  self.__index = self
  return o
end

function Knob:init()
  if self.toggle_name then
    self.toggle_param_name = self.track .. ' ' .. self.toggle_name

    params:add_option(
      self.toggle_param_name,
      self.toggle_param_name,
      { "off", "on" },
      1
    )

    params:set_action(self.toggle_param_name, function(x)
      self.toggle = x == 2

      if self.on_toggle_change then
        self:on_toggle_change()
      end

      self:redraw_mft()
    end)
  end

  if self.value_name then
    self.value_param_name = self.track .. ' ' .. self.value_name

    params:add_taper(
      self.value_param_name,
      self.value_param_name,
      self.value_min,
      self.value_max,
      self.value,
      0,
      self.value_unit
    )

    params:set_action(self.value_param_name, function(x)
      self.value = x
      self:redraw_mft()
    end)
  end

  self:redraw_mft()
end

function Knob:on_midi(midi)
  if midi.ch == 1 and self.on_midi_value ~= nil then
    local new_value = self:on_midi_value(midi)

    self.value = clamp(new_value, self.value_min, self.value_max)

    if self.value_param_name then
      params:set(self.value_param_name, self.value)
    end

    if self.on_value_change then
      self:on_value_change()
    end
  end

  if midi.ch == 2 and midi.val == 127 and self.on_midi_toggle ~= nil then
    local new_toggle = self:on_midi_toggle(midi)
    self.toggle = new_toggle

    if self.toggle_param_name then
      params:set(self.toggle_param_name, self.toggle and 2 or 1)
    end

    if self.on_toggle_change then
      self:on_toggle_change()
    end
  end

  self:redraw_mft()

  print(inspect(self))
end

function Knob:redraw_mft()
  if bank == self.bank then
    local midi_value = math.floor(scale(self.value, self.value_min, self.value_max, 0, 127))

    mft:cc(self.index, midi_value, 1)
    mft:cc(self.index, self.color, 2)
    mft:cc(self.index, self.brightness, 3)
  end
end

-- Main

function init()
  knobs[0] = Knob:new({
    index = 0,
    track = 1,
    bank = 1,

    toggle_name = "record",
    value_name = "record feedback",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 0.01 end,
    on_midi_toggle = function(self, midi) return not self.toggle end,

    on_value_change = function(self)
      engine.pre_level(self.track, self.value)
    end,

    on_toggle_change = function(self)
      self.brightness = self.toggle and B.HI or B.MID
      engine.record(self.track, self.toggle and 1 or 0)
    end,

    value = 0,
    value_min = 0,
    value_max = 1,
    toggle = false,

    color = C.RED,
    brightness = B.MID
  })

  knobs[0]:init()

  knobs[3] = Knob:new({
    index = 3,
    track = 1,
    bank = 1,

    toggle_name = "play",
    value_name = "gain",
    value_unit = "dB",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 0.5 end,
    on_midi_toggle = function(self, midi) return not self.toggle end,

    on_value_change = function(self)
      engine.gain(self.track, math.pow(10, self.value / 20))
    end,

    on_toggle_change = function(self)
      self.brightness = self.toggle and B.HI or B.MID
      engine.gate(self.track, self.toggle and 1 or 0)
    end,

    value = 0,
    value_min = -60,
    value_max = 20,
    toggle = false,

    color = C.YELLOW,
    brightness = B.MID
  })

  knobs[3]:init()

  params:bang()
end

-- Midi

mft.event = function(data)
  data = midi.to_msg(data)

  local knob = knobs[data.cc]
  if knob then
    knob:on_midi(data)
  end
end

