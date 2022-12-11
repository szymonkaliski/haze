-- Haze
-- v1.4.1 @szymon_k
--
-- 4-track live granular looper
-- built for Midi Fighter Twister,
-- but usable without it
--
-- based on mangl @justmat,
-- which is based on angl @tehn,
-- which uses glut @artfwo
--

engine.name = "Haze"

local Track   = include("lib/track")
local clamp   = include("lib/utils").clamp
local inspect = require("tabutil").print

local mft     = nil
local tracks  = {}

function init()
  for i = 1, #midi.vports do
    local midi_device = midi.vports[i]

    if midi_device.name == "Midi Fighter Twister" then
      mft = midi.connect(i)
    end
  end

  if mft then
    print("Haze operating with MFT")
    init_mft()
  else
    print("Haze operating without MFT")
  end

  for i = 1, 4 do
    tracks[i] = Track:new({
      active_bank = 1,
      track       = i,
      mft         = mft,
    })
    tracks[i]:init()
  end

  params:bang()

  -- redraw MFT after loading params to update it when loading a preset
  for i = 1, 4 do
    tracks[i]:redraw_mft()
  end
end

function redraw_screen()
  screen.clear()
  screen.move(0, 0)
  screen.level(8)

  local param_names = tracks[1]:get_param_names_for_active_bank()

  -- param names
  for i = 1, 4 do
    local param_name = param_names[i]
    screen.move(23 + (i - 1) * 34, 8)
    screen.text_right(param_name)
  end

  -- knob values
  for i = 1, 4 do
    screen.move(23, (i - 1) * 10 + 22)
    tracks[i]:redraw_screen()
  end

  -- bank indicator
  for i = 1, 3 do
    local screen_width = 128
    local indicator_width = 18
    local padding = 1

    screen.line_width(1)
    screen.level(2)
    if i == tracks[1].active_bank then
      screen.level(8)
    end

    local start_x = (screen_width - (indicator_width + padding * 2) * 3) / 2
    start_x = start_x + padding * i + (indicator_width + padding) * (i - 1)

    screen.move(start_x, 62)
    screen.line(start_x + indicator_width, 62)

    screen.stroke()
  end

  screen.update()
end

function redraw()
  redraw_screen()
end

-- UI animation
animate = metro.init()
animate.time  = 1.0 / 15.0
animate.event = function() redraw() end
animate:start()

-- Norns
function enc(n, value)
  if n == 1 then
    local dir = value > 0 and 1 or -1
    local active_bank = tracks[1].active_bank
    local new_active_bank = clamp(active_bank + dir, 1, 3)

    for i = 1, 4 do
      tracks[i]:switch_bank(new_active_bank)
    end
  end
end

function init_mft()
  mft.event = function(data)
    data = midi.to_msg(data)

    if data.type == "cc" then
      local track = math.floor(data.cc / 4) + 1
      tracks[track]:on_midi(data)
    end

    if data.type == "note_off" then
      local active_bank = tracks[1].active_bank

      if data.note == 8 or data.note == 11 then
        active_bank = 1
      elseif data.note == 9 or data.note == 12 then
        active_bank = 2
      elseif data.note == 10 or data.note == 13 then
        active_bank = 3
      end

      for i = 1, 4 do
        tracks[i]:switch_bank(active_bank)
      end
    end
  end
end

