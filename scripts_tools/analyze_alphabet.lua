-- Analizza assets/sprites/ui/alphabet.png: trova il bounding box di ogni lettera
-- (colonne separate da spazio trasparente) e scrive le coordinate in un file di testo.

local spr = Sprite{ fromFile = "assets/sprites/ui/alphabet.png" }
local img = spr.cels[1].image
local W, H = spr.width, spr.height

local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

local function pixelAlpha(px)
  if spr.colorMode == ColorMode.GRAY then
    return app.pixelColor.grayaA(px)
  elseif spr.colorMode == ColorMode.INDEXED then
    local c = spr.palettes[1]:getColor(px)
    return c.alpha
  else
    return app.pixelColor.rgbaA(px)
  end
end

local function columnHasPixel(x)
  for y = 0, H - 1 do
    local px = img:getPixel(x, y)
    if pixelAlpha(px) > 10 then return true end
  end
  return false
end

local ranges = {}
local inGlyph = false
local startX = 0
for x = 0, W - 1 do
  local has = columnHasPixel(x)
  if has and not inGlyph then
    inGlyph = true
    startX = x
  elseif not has and inGlyph then
    inGlyph = false
    table.insert(ranges, { x = startX, w = x - startX })
  end
end
if inGlyph then
  table.insert(ranges, { x = startX, w = W - startX })
end

local out = io.open("assets/sprites/ui/alphabet_map.txt", "w")
out:write("count_found=" .. #ranges .. " count_expected=" .. #chars .. "\n")
for i, r in ipairs(ranges) do
  local ch = chars:sub(i, i)
  out:write(string.format("%s\tx=%d\ty=0\tw=%d\th=%d\n", ch ~= "" and ch or "?", r.x, r.w, H))
end
out:close()

print("found " .. #ranges .. " glyphs, expected " .. #chars)
