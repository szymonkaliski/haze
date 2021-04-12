local inspect = require("tabutil").print

local B       = include("lib/consts").B
local C       = include("lib/consts").C
local clamp   = include("lib/utils").clamp
local merge   = include("lib/utils").merge
local mft_dir = include("lib/utils").mft_dir
local round   = include("lib/utils").round

local Knob    = include("lib/knob")

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
      bank        = bank,
      track       = self.track,
      index       = index - 1,
      mft         = self.mft,
      active_bank = self.active_bank,
    }, knob_options)

    self.knob_banks[bank][index] = Knob:new(knob_spec)
  end

  -- Bank 1

  add_knob(1, 1, {
    toggle_name = "record",
    value_name = "record feedback",
    value_name_short = "rec",
    value_unit = "%",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) end,
    on_midi_toggle = function(self, midi) return not self.toggle end,

    on_value_change = function(self)
      engine.pre_level(self.track, self.value / 100)
    end,

    on_toggle_change = function(self)
      self.brightness = self.toggle and B.HI or B.MID
      engine.record(self.track, self.toggle and 1 or 0)
    end,

    value = 0,
    value_min = 0,
    value_max = 100,
    toggle = false,

    color = C.RED,
    brightness = B.MID
  })

  add_knob(1, 2, {
    value_name = "input gain",
    value_name_short = "gain",
    value_unit = "dB",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 0.1 end,
    on_midi_toggle = function(self, midi) return not self.toggle end,

    on_value_change = function(self) engine.in_gain(self.track, math.pow(10, self.value / 20)) end,

    on_toggle_change = function(self)
      self.brightness = self.toggle and B.HI or B.MID
      engine.gate(self.track, self.toggle and 1 or 0)
    end,

    value = 0,
    value_min = -60,
    value_max = 20,

    color = C.RED,
    brightness = B.MID
  })

  add_knob(1, 3, {
    value_name = "fade",
    value_unit = "s",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 0.1 end,
    on_value_change = function(self) engine.fade(self.track, self.value) end,

    value = 0.0,
    value_min = 0.0,
    value_max = 10.0,

    color = C.ORANGE,
    brightness = B.MID
  })

  add_knob(1, 4, {
    toggle_name = "play",
    value_name = "output gain",
    value_name_short = "gain",
    value_unit = "dB",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 0.1 end,
    on_midi_toggle = function(self, midi) return not self.toggle end,

    on_value_change = function(self) engine.out_gain(self.track, math.pow(10, self.value / 20)) end,

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
    value_name_short = "dens",
    value_unit = "hz",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 0.1 end,
    on_value_change = function(self) engine.density(self.track, self.value) end,

    value = 10,
    value_min = 0,
    value_max = 32,

    color = C.CYAN,
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
    value_name = "size jitter",
    value_name_short = "jitter",
    value_unit = "ms",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 10 end,
    on_value_change = function(self) engine.jitter_size(self.track, self.value / 1000) end,

    value = 0,
    value_min = 0,
    value_max = 500,

    color = C.BLUE,
    brightness = B.MID
  })

  add_knob(2, 4, {
    value_name = "spread",
    value_unit = "%",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 0.25 end,
    on_value_change = function(self) engine.spread(self.track, self.value) end,

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
    value_name_short = "spd",

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
    value_name_short = "pos",
    value_unit = "%",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 0.25 end,
    on_value_change = function(self) engine.pos(self.track, self.value / 100) end,

    value = 0,
    value_min = 0,
    value_max = 100,

    color = C.YELLOW,
    brightness = B.MID
  })

  add_knob(3, 3, {
    value_name = "position jitter",
    value_name_short = "jitter",
    value_unit = "ms",

    on_midi_value = function(self, midi) return self.value + mft_dir(midi) * 10 end,
    on_value_change = function(self) engine.jitter_pos(self.track, self.value / 1000) end,

    value = 0,
    value_min = 0,
    value_max = 2000,

    color = C.YELLOW,
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

function Track:switch_bank(new_bank)
  self.active_bank = new_bank

  for i = 1, 3 do
    for j = 1, 4 do
      local knob = self.knob_banks[i][j]
      if knob then knob:switch_bank(new_bank) end
    end
  end

  self:redraw_mft()
end

function Track:on_midi(midi)
  local knob_idx = midi.cc % 4 + 1
  local knob = self.knob_banks[self.active_bank][knob_idx]

  if knob then
    knob:on_midi(midi)
    knob:redraw_mft()
  end
end

function Track:get_param_names_for_active_bank()
  local result = {}

  for i = 1, 4 do
    local knob = self.knob_banks[self.active_bank][i]
    local param_name = ""

    if knob then
      param_name = knob.value_name_short or knob.value_name
    end

    table.insert(result, param_name)
  end

  return result
end

function Track:redraw_screen()
  for i = 1, 4 do
    local knob = self.knob_banks[self.active_bank][i]

    local play_knob = self.knob_banks[1][4]
    local is_playing = play_knob.toggle

    screen.level(2)
    if is_playing then
      screen.level(8)
    end

    if knob then
      knob:redraw_screen()
    end

    screen.move_rel(34, 0)
  end
end

function Track:redraw_mft()
  if not self.mft then
    return
  end

  for i = 1, 4 do
    local knob = self.knob_banks[self.active_bank][i]

    if knob then
      knob:redraw_mft()
    else
      local physical_index = (self.track - 1) * 4 + (i - 1)

      self.mft:cc(physical_index, 0, 1)
      self.mft:cc(physical_index, 0, 2)
      self.mft:cc(physical_index, B.OFF, 3)
    end
  end
end

return Track
