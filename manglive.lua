-- Live Mangl with Midi Fighter Twister

engine.name = "LMGlut"

local inspect = require "manglive/lib/inspect" -- why not "lib/inspect"?

local values = {
  64, 64, 64, 64,
  64, 64, 64, 64,
  64, 64, 64, 64,
  64, 64, 64, 64
}

-- utils

function clamp(v, min, max)
  return math.max(math.min(v, max), min)
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

-- mft

local mft = midi.connect(1)

mft.event = function(data)
  data = midi.to_msg(data)

  print(inspect(data))

  if data.type == "cc" and data.ch == 1 then
    -- data.cc is index of the knob
    local idx = data.cc + 1 -- lua is 1-indexed

    values[idx] = values[idx] + (data.val > 64 and 1 or -1)
    values[idx] = clamp(values[idx], 0, 127)

    redraw_screen()
    redraw_mft()
  end

  -- ch = 2 is for "clicks" - val 127 is clicked, 0 unclicked
  -- ^ can use this for buttons / toggles
  --
  -- ch = 4 is for side buttons
  --   - note 8, 9, 10 for left and note 11, 12, 13 for right side
  --   - note_on when clicked, note_off when not
  -- ^ can use this for my own  "banks"
end

function redraw_mft()
  for i = 0, 15, 1 do

    mft:cc(i, values[i + 1], 1) -- value
    mft:cc(i, 63, 2) -- base color
    mft:cc(i, 18, 3) -- animation/brightness; 18 - off, 32 - dim, 47 - bright
  end
end

-- main

function init()
  redraw_screen()
  redraw_mft()
end

function redraw_screen()
  screen.clear()

  for i = 1, 4, 1
  do
    for j = 1, 4, 1
    do
      local index = (i - 1) * 4 + j
      local value = values[index]

      screen.move((j - 1) * 16, i * 8)
      screen.text(value)
    end
  end

  screen.update()
end

