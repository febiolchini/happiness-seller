-- Starter template for a 16x24 character sprite, aligned to a 16-wide tile grid.
local W, H = 16, 24

local spr = Sprite(W, H, ColorMode.INDEXED)
spr.gridBounds = Rectangle(0, 0, 16, 8) -- rough head / torso / legs guide rows

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

-- Four directions as tags, one frame each to start (duplicate frames later for walk cycles)
spr:newFrame()
spr:newFrame()
spr:newFrame()
spr:newTag(1, 1).name = "down"
spr:newTag(2, 2).name = "up"
spr:newTag(3, 3).name = "left"
spr:newTag(4, 4).name = "right"

spr:saveAs("assets/sprites/characters/character_template.aseprite")
print("Character template created: assets/sprites/characters/character_template.aseprite")
