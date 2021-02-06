local clamp = include("lib/utils").clamp
local scale = include("lib/utils").scale
local round = include("lib/utils").round

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

function Knob:switch_bank(new_bank)
  self.active_bank = new_bank
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
end

function Knob:redraw_screen()
  if self.active_bank == self.bank then
    local value = round(self.value)
    local unit = self.value_unit or ""

    if self.toggle_name then
      screen.level(2)
      if self.toggle then
        screen.level(15)
      end
    end

    screen.text_right(value .. "" .. unit)
  end
end

function Knob:redraw_mft()
  if self.active_bank == self.bank then
    local midi_value = math.floor(scale(self.value, self.value_min, self.value_max, 0, 127))

    self.mft:cc(self.physical_index, midi_value, 1)
    self.mft:cc(self.physical_index, self.color, 2)
    self.mft:cc(self.physical_index, self.brightness, 3)
  end
end

return Knob
