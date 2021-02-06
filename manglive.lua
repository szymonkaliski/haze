-- Live Mangl with Midi Fighter Twister

engine.name = "LMGlut"

local Track   = include("lib/track")
local inspect = require("tabutil").print

local mft     = midi.connect(1)
local tracks  = {}

function init()
  for i = 1, 4 do
    tracks[i] = Track:new({
      active_bank = 1,
      track       = i,
      mft         = mft,
    })

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

-- MFT Midi

mft.event = function(data)
  data = midi.to_msg(data)

  if data.type == "cc" then
    local track = math.floor(data.cc / 4) + 1
    tracks[track]:on_midi(data)
  end

  if data.type == "note_off" then
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

