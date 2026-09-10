-- Generates starter pixel-art templates for the 4 happiness-seller building tiers.
-- Same conventions as create_template.lua: 16px tile grid, 13-color base palette,
-- Base/Shading/Highlight/Outline layers. Adds a "GroundLine" guide layer marking
-- the row where the sprite's base sits on the tile grid (for Y-sort anchoring).

local TILE = 32

local palette_colors = {
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

-- footprint_w/h are in tiles (logical grid cells the building occupies).
-- canvas_h is the sprite height in px, taller than footprint_h*TILE to allow
-- vertical overflow (roofs, upper floors) above the base.
local defs = {
  {
    name = "small_house_shop",
    path = "assets/sprites/buildings/small_house_shop_template.aseprite",
    footprint_w = 4, footprint_h = 3,
    canvas_h = 176,
  },
  {
    name = "medium_building",
    path = "assets/sprites/buildings/medium_building_template.aseprite",
    footprint_w = 6, footprint_h = 4,
    canvas_h = 240,
  },
  {
    name = "tall_condo",
    path = "assets/sprites/buildings/tall_condo_template.aseprite",
    footprint_w = 5, footprint_h = 4,
    canvas_h = 480,
  },
  {
    name = "mall_large",
    path = "assets/sprites/buildings/mall_large_template.aseprite",
    footprint_w = 12, footprint_h = 9,
    canvas_h = 340,
  },
}

for _, def in ipairs(defs) do
  local w = def.footprint_w * TILE
  local h = def.canvas_h

  local spr = Sprite(w, h, ColorMode.INDEXED)
  spr.gridBounds = Rectangle(0, 0, TILE, TILE)

  local palette = Palette(#palette_colors)
  for i, c in ipairs(palette_colors) do
    palette:setColor(i - 1, c)
  end
  spr:setPalette(palette)

  spr.layers[1].name = "Base"
  spr:newLayer().name = "Shading"
  spr:newLayer().name = "Highlight"
  spr:newLayer().name = "Outline"

  -- GroundLine guide: marks the row where the footprint's base tiles end,
  -- i.e. where the sprite should visually touch the ground/tile grid.
  local guide = spr:newLayer()
  guide.name = "GroundLine"
  guide.opacity = 128
  local cel = spr:newCel(guide, 1)
  local img = cel.image
  local ground_y = h - (def.footprint_h * TILE)
  for x = 0, w - 1 do
    img:putPixel(x, ground_y, Color(255, 0, 0, 200))
  end
  -- Footprint width markers (vertical ticks every tile along the ground line)
  for gx = 0, def.footprint_w do
    local x = math.min(gx * TILE, w - 1)
    for y = ground_y, h - 1 do
      img:putPixel(x, y, Color(255, 0, 0, 120))
    end
  end

  spr:saveAs(def.path)
  print(string.format(
    "Building template created: %s (canvas %dx%d, footprint %dx%d tiles, ground at y=%d)",
    def.path, w, h, def.footprint_w, def.footprint_h, ground_y
  ))
end
