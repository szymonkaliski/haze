-- Live Mangl with Midi Fighter Twister

engine.name = "LMGlut"

local inspect = require "manglive/lib/inspect" -- why not "lib/inspect"?

local mft = midi.connect(1)
local tracks = {}

-- utils

function clamp(i, min, max)
  return math.max(math.min(i, max), min)
end

function four_values_to_str(row_idx)
  local result = ""

  for i = row_idx * 4, (row_idx + 1) * 4 - 1, 1
  do
    print(i, values[i + 1])
    result = result .. values[i] .. " "
  end

  return result
end

function mft_dir(data)
  return data.val > 64 and 1 or -1
end

-- mft

mft.event = function(data)
  data = midi.to_msg(data)

  local track_index = math.floor(data.cc / 4) + 1
  tracks[track_index]:on_midi(data)

  -- ch = 2 is for "clicks" - val 127 is clicked, 0 unclicked
  -- ^ can use this for buttons / toggles
  --
  -- ch = 4 is for side buttons
  --   - note 8, 9, 10 for left and note 11, 12, 13 for right side
  --   - note_on when clicked, note_off when not
  -- ^ can use this for my own  "banks"
end

-- function redraw_mft()
--   for i = 0, 15, 1 do

--     mft:cc(i, values[i + 1], 1) -- value
--     mft:cc(i, 63, 2) -- base color
--     mft:cc(i, 18, 3) -- animation/brightness; 18 - off, 32 - dim, 47 - bright
--   end
-- end

-- main

local Track = {}

function Track:new(index)
  local track = setmetatable({
    index = index
  }, self)

  self.__index = self

  return track
end

function Track:on_midi(data)
  print(inspect(self), inspect(data))

  if data.type == "cc" then
    local is_knob_1 = data.cc % 4 == 0
    local is_knob_2 = data.cc % 4 == 1
    local is_knob_3 = data.cc % 4 == 2
    local is_knob_4 = data.cc % 4 == 3

    if is_knob_1 then
      if data.ch == 1 then
        local pre_level = params:get(self.index .. "pre_level")
        local new_pre_level = pre_level + mft_dir(data) * 0.01
        params:set(self.index .. "pre_level", new_pre_level)
      end

      if data.ch == 2 and data.val == 127 then
        local record = params:get(self.index .. "record")
        local new_record = record == 1 and 2 or 1
        params:set(self.index .. "record", new_record)
      end
    end

    if is_knob_4 then
      if data.ch == 1 then
        local gain = params:get(self.index .. "gain")
        local new_gain = gain + mft_dir(data)
        params:set(self.index .. "gain", new_gain)
      end

      if data.ch == 2 and data.val == 127 then
        local play = params:get(self.index .. "play")
        local new_play = play == 1 and 2 or 1
        params:set(self.index .. "play", new_play)
      end
    end
  end

  redraw_mft()
end

function Track:redraw_mft()
  local pre_level = params:get(self.index .. "pre_level")
  local gain = params:get(self.index .. "gain")
  local is_recording = params:get(self.index .. "record") == 2
  local is_playing = params:get(self.index .. "play") == 2

  local knob_1 = (self.index - 1) * 4 + 0
  local knob_2 = (self.index - 1) * 4 + 1
  local knob_3 = (self.index - 1) * 4 + 2
  local knob_4 = (self.index - 1) * 4 + 3

  mft:cc(knob_1, math.floor(pre_level * 127), 1)
  mft:cc(knob_1, 76, 2)

  if is_recording then
    mft:cc(knob_1, 47, 3)
  else
    mft:cc(knob_1, 32, 3)
  end

  mft:cc(knob_4, math.floor(((gain + 60) / 80) * 127), 1)
  mft:cc(knob_4, 63, 2)

  if is_playing then
    mft:cc(knob_4, 47, 3)
  else
    mft:cc(knob_4, 32, 3)
  end
end

function init()
  -- redraw_screen()
  -- redraw_mft()

  local action_with_redraw = function(i, cb)
    return function(x)
      tracks[i]:redraw_mft()
      cb(x)
    end
  end

  for i = 1, 4 do
    params:add_separator("")

    params:add_option(i .. "record", i .. " record", { "off", "on" }, 1)
    params:set_action(i .. "record", action_with_redraw(i, function(x) engine.record(i, x - 1) end))

    params:add_taper(i .. "pre_level", i .. " record feedback", 0, 1, 0, 1)
    params:set_action(i .. "pre_level", action_with_redraw(i, function(x) engine.pre_level(i, x) end))

    params:add_option(i .. "play", "play", { "off", "on" }, 1)
    params:set_action(i .. "play", action_with_redraw(i, function(x) engine.gate(i, x - 1) end))

    params:add_taper(i .. "gain", "gain", -60, 20, 0, 0, "dB")
    params:set_action(i .. "gain", action_with_redraw(i, function(x) engine.gain(i, math.pow(10, x / 20)) end))

    params:add_control(i .. "pos", "pos", controlspec.new(0, 1, "lin", 0.001, 0))
    params:set_action(i .. "pos", action_with_redraw(i, function(x) engine.seek(i, x) end))

    params:add_taper(i .. "speed", "speed", -300, 300, 0, 0, "%")
    params:set_action(i .. "speed", action_with_redraw(i, function(x) engine.speed(i, x / 100) end))

    params:add_taper(i .. "jitter", "jitter", 0, 1000, 0, 5, "ms")
    params:set_action(i .. "jitter", action_with_redraw(i, function(x) engine.jitter(i, x / 1000) end))

    params:add_taper(i .. "size", "size", 1, 1000, 250, 5, "ms")
    params:set_action(i .. "size", action_with_redraw(i, function(x) engine.size(i, x / 1000) end))

    params:add_taper(i .. "density", "density", 0, 512, 20, 6, "hz")
    params:set_action(i .. "density", action_with_redraw(i, function(x) engine.density(i, x) end))

    -- TODO: steps
    params:add_taper(i .. "pitch", "pitch", -24, 24, 0, 0, "st")
    params:set_action(i .. "pitch", action_with_redraw(i, function(x) engine.pitch(i, math.pow(0.5, -x / 12)) end))

    params:add_taper(i .. "spread", "spread", 0, 100, 0, 0, "%")
    params:set_action(i .. "spread", action_with_redraw(i, function(x) engine.spread(i, x / 100) end))

    params:add_taper(i .. "fade", "att / dec", 1, 9000, 1000, 3, "ms")
    params:set_action(i .. "fade", action_with_redraw(i, function(x) engine.envscale(i, x / 1000) end))

    -- track
    tracks[i] = Track:new(i)
  end

  params:read()
  params:bang()

  redraw_mft()
end

function redraw_mft()
  for i = 1, 4 do
    tracks[i]:redraw_mft()
  end
end

function redraw_screen()
  screen.clear()

  -- for i = 1, 4, 1
  -- do
  --   for j = 1, 4, 1
  --   do
  --     local index = (i - 1) * 4 + j
  --     local value = values[index]

  --     screen.move((j - 1) * 16, i * 8)
  --     screen.text(ialue)
  --   end
  -- end

  screen.update()
end

