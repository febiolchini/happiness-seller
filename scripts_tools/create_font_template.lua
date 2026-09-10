-- Genera un template Aseprite per un font bitmap pixel art (menu/UI/dialoghi)
-- Griglia 8x8 px per carattere, 16 colonne x 3 righe = 48 celle

local CELL = 8
local COLS = 16
local ROWS = 3
local W, H = CELL * COLS, CELL * ROWS

local spr = Sprite(W, H, ColorMode.INDEXED)
spr.gridBounds = Rectangle(0, 0, CELL, CELL)

-- stessa palette usata negli altri template (assets/sprites/palette.gpl)
local palette = Palette(13)
local colors = {
  {0, 0, 0, 0},       -- 0: trasparente
  {20, 16, 25, 255},  -- 1: outline
  {56, 43, 51, 255},  -- 2: shadow dark
  {96, 62, 60, 255},  -- 3: shadow
  {153, 94, 76, 255}, -- 4: mid tone
  {204, 138, 97, 255},-- 5: base
  {230, 179, 133, 255},-- 6: light tone
  {247, 226, 178, 255},-- 7: highlight
  {90, 110, 60, 255}, -- 8: green dark
  {130, 160, 80, 255},-- 9: green mid
  {180, 210, 120, 255},-- 10: green light
  {50, 70, 110, 255}, -- 11: water shadow
  {120, 160, 210, 255} -- 12: water light
}
for i, c in ipairs(colors) do
  palette:setColor(i - 1, Color(c[1], c[2], c[3], c[4]))
end
spr:setPalette(palette)

spr.layers[1].name = "Base"
spr:newLayer().name = "Outline"

local guide = spr:newLayer()
guide.name = "GridGuide"
guide.opacity = 60
local cel = spr:newCel(guide, 1)
local img = cel.image
for row = 0, ROWS - 1 do
  for x = 0, W - 1 do
    img:putPixel(x, row * CELL, Color(255, 0, 0, 180))
  end
end
for col = 0, COLS - 1 do
  for y = 0, H - 1 do
    img:putPixel(col * CELL, y, Color(255, 0, 0, 180))
  end
end

spr:saveAs("assets/sprites/ui/font_template.aseprite")
