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

function mft_dir(data)
  return data.val > 64 and 1 or -1
end

return {
  clamp   = clamp,
  scale   = scale,
  merge   = merge,
  round   = round,
  mft_dir = mft_dir,
}
