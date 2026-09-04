-- Generates a starter pixel-art template: sized canvas, base palette, painting layers.
local SIZE = 32

local spr = Sprite(SIZE, SIZE, ColorMode.INDEXED)
spr.gridBounds = Rectangle(0, 0, 16, 16)

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

spr:saveAs("assets/sprites/template.aseprite")
print("Template created: assets/sprites/template.aseprite")
