-- Live Mangl with Midi Fighter Twister

engine.name = "LMGlut"

local tabutil = require("tabutil")
local inspect = tabutil.print
local mft     = midi.connect(1)
local bank    = 3
local tracks  = {}

-- MFT brightness
local B = {
  OFF = 18,
  MID = 32,
  HI  = 47
}

-- MFT color
local C = {
  BLUE   = 22,
  CYAN   = 36,
  YELLOW = 62,
  ORANGE = 68,
  RED    = 74
}

-- utils

function clamp(i, min, max)
  return math.max(math.min(i, max), min)
end

function scale(x, i_min, i_max, o_min, o_max)
  return (o_max - o_min) * (x - i_min) / (i_max - i_min) + o_min;
end

function merge(t1, t2)
  for k,v in pairs(t2) do
    t1[k] = v
  end

  return t1
end

function round(x)
  return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

print(round(-20 / 12) * 12)

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
  self.physical_index = (self.track - 1) * 4 + self.index

  if self.toggle_name then
    self.toggle_param_name = self.track .. " " .. self.toggle_name

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
    self.value_param_name = self.track .. " " .. self.value_name

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
end

function Knob:redraw_mft()
  if bank == self.bank then
    local midi_value = math.floor(scale(self.value, self.value_min, self.value_max, 0, 127))

    mft:cc(self.physical_index, midi_value, 1)
    mft:cc(self.physical_index, self.color, 2)
    mft:cc(self.physical_index, self.brightness, 3)
  end
end

-- Track

local Track = {}

function Track:new(o)
  o = setmetatable(o, self)
  self.__index = self
  return o
end

function Track:init()
  self.knob_banks = {}

  for i = 1, 3 do
    self.knob_banks[i] = {}
  end

  local add_knob = function(bank, index, knob_options)
    if self.knob_banks[bank][index] ~= nil then
      print("knob at " .. bank .. ", " .. index .. " already exists, ignoring")
      return
    end

    local knob_spec = merge({
      bank  = bank,
      track = self.track,
      index = index - 1,
    }, knob_options)

    self.knob_banks[bank][index] = Knob:new(knob_spec)
  end

  -- Bank 1

  add_knob(1, 1, {
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

  add_knob(1, 4, {
    toggle_name = "play",
    value_name = "gain",
    value_unit = "dB",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 0.1 end,
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

    color = C.RED,
    brightness = B.MID
  })

  -- Bank 2

  add_knob(2, 1, {
    value_name = "density",
    value_unit = "hz",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 0.1 end,
    on_value_change = function(self) engine.density(self.track, self.value) end,

    value = 10,
    value_min = 0,
    value_max = 32,

    color = C.BLUE,
    brightness = B.MID
  })

  add_knob(2, 2, {
    value_name = "size",
    value_unit = "ms",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 5 end,
    on_value_change = function(self) engine.size(self.track, self.value / 1000) end,

    value = 250,
    value_min = 1,
    value_max = 1000,

    color = C.BLUE,
    brightness = B.MID
  })

  add_knob(2, 3, {
    value_name = "jitter",
    value_unit = "ms",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 5 end,
    on_value_change = function(self) engine.jitter(self.track, self.value / 1000) end,

    value = 0,
    value_min = 0,
    value_max = 1000,

    color = C.CYAN,
    brightness = B.MID
  })

  add_knob(2, 4, {
    value_name = "spread",
    value_unit = "%",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 0.5 end,
    on_value_change = function(self) engine.spread(self.track, self.value / 100) end,

    value = 0,
    value_min = 0,
    value_max = 100,

    color = C.CYAN,
    brightness = B.MID
  })

  -- Bank 3

  add_knob(3, 1, {
    value_name = "speed",
    value_unit = "%",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) end,
    on_value_change = function(self) engine.speed(self.track, self.value / 100) end,

    value = 100,
    value_min = -200,
    value_max = 200,

    color = C.YELLOW,
    brightness = B.MID
  })

  add_knob(3, 2, {
    value_name = "position",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 0.005 end,
    on_value_change = function(self) engine.seek(self.track, self.value) end,

    value = 0,
    value_min = 0,
    value_max = 1,

    color = C.YELLOW,
    brightness = B.MID
  })

  add_knob(3, 3, {
    value_name = "fade",
    value_unit = "ms",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 20 end,
    on_value_change = function(self) engine.envscale(self.track, self.value / 1000) end,

    value = 1,
    value_min = 1,
    value_max = 5000,

    color = C.ORANGE,
    brightness = B.MID
  })

  add_knob(3, 4, {
    value_name = "pitch",
    value_unit = "st",

    on_midi_value = function(self, midi)
      self.temp_value = clamp((self.temp_value or 0) + mft_dir(midi) * 0.5, -24, 24)
      return round(self.temp_value / 12) * 12 -- round to nearest -24, -12, 0, 12, 24
    end,

    on_value_change = function(self) engine.pitch(self.track, math.pow(0.5, -1 * self.value / 12)) end,

    value = 0,
    value_min = -24,
    value_max = 24,

    color = C.ORANGE,
    brightness = B.MID
  })

  -- init knobs

  for i = 1, 3 do
    for j = 1, 4 do
      local knob = self.knob_banks[i][j]
      if knob then knob:init() end
    end
  end
end

function Track:on_midi(midi)
  local knob_idx = midi.cc % 4 + 1
  local knob = self.knob_banks[bank][knob_idx]

  if knob then
    knob:on_midi(midi)
    knob:redraw_mft()
  end
end

function Track:redraw_mft()
  for i = 1, 4 do
    local knob = self.knob_banks[bank][i]

    if knob then
      knob:redraw_mft()
    else
      local physical_index = (self.track - 1) * 4 + (i - 1)

      mft:cc(physical_index, 0, 1)
      mft:cc(physical_index, 0, 2)
      mft:cc(physical_index, B.OFF, 3)
    end
  end
end

-- Main

function init()
  for i = 1, 4 do
    tracks[i] = Track:new({ track = i })
    tracks[i]:init()
  end

  params:bang()

  redraw_mft()
end

function redraw_mft()
  for i = 1, 4 do
    tracks[i]:redraw_mft()
  end
end

-- Midi

mft.event = function(data)
  data = midi.to_msg(data)

  if data.type == "cc" then
    local track = math.floor(data.cc / 4) + 1
    tracks[track]:on_midi(data)
  end

  if data.type == "note_off" then
    if data.note == 8 or data.note == 11 then
      bank = 1
    elseif data.note == 9 or data.note == 12 then
      bank = 2
    elseif data.note == 10 or data.note == 13 then
      bank = 3
    end

    redraw_mft()
  end
end

