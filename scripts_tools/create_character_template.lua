-- Starter template for a 32x48 "chibi" character sprite (Sea of Stars-ish proportions).
-- Head ~14px, torso ~16px, legs ~18px. Aligned to a 32px tile grid.
local W, H = 32, 48

local spr = Sprite(W, H, ColorMode.INDEXED)
-- Guide grid marking head / torso / legs bands, not a paint grid
spr.gridBounds = Rectangle(0, 0, 32, 14)

local palette = Palette(13)
local colors = {
  Color(0, 0, 0, 0),
  Color(20, 16, 25, 255),
  Color(56, 43, 51, 255),
  Color(96, 62, 60, 255),
  Color(153, 94, 76, 255),
  Color(204, 138, 97, 255),
  Color(230, 179, 133, 255),
  Color(247, 226, 178, 255),
  Color(58, 82, 60, 255),
  Color(98, 133, 76, 255),
  Color(160, 186, 106, 255),
  Color(53, 76, 102, 255),
  Color(110, 150, 176, 255),
}
for i, c in ipairs(colors) do
  palette:setColor(i - 1, c)
end
spr:setPalette(palette)

spr.layers[1].name = "Base"
spr:newLayer().name = "Shading"
spr:newLayer().name = "Highlight"
spr:newLayer().name = "Outline"

-- Proportion guide layer: horizontal lines at head(14) / torso(30) boundaries
local guide = spr:newLayer()
guide.name = "ProportionGuide"
guide.opacity = 128
local cel = spr:newCel(guide, 1)
local img = cel.image
for x = 0, W - 1 do
  img:putPixel(x, 14, Color(255, 0, 0, 200)) -- head/torso line
  img:putPixel(x, 30, Color(255, 0, 0, 200)) -- torso/legs line
end

spr:newFrame()
spr:newFrame()
spr:newFrame()
spr:newTag(1, 1).name = "down"
spr:newTag(2, 2).name = "up"
spr:newTag(3, 3).name = "left"
spr:newTag(4, 4).name = "right"

spr:saveAs("assets/sprites/characters/character_template.aseprite")
print("Character template created: assets/sprites/characters/character_template.aseprite")
