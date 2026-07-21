--[[ #include "image_assets.lua" ]]

local Black = {0,0,0}
local HeaderFill = {245,245,245}
local PanelFill = {200,200,200}
local HeaderHeight = 64

local function AddHeader()
  table.insert(graphics,{
    Type = "GroupBox",
    Fill = HeaderFill,
    StrokeWidth = 1,
    Position = {5,5},
    Size = {310,HeaderHeight}
  })
  table.insert(graphics,{
    Type = "Svg",
    Image = DechenLogo,
    Position = {12,18},
    Size = {96,24}
  })
  table.insert(graphics,{
    Type = "Svg",
    Image = PlanarLogo,
    Position = {206,18},
    Size = {96,24}
  })
  table.insert(graphics,{
    Type = "Text",
    Text = "Planar UltraRes",
    Color = Black,
    HTextAlign = "Center",
    Position = {110,17},
    Size = {94,24},
    FontSize = 14
  })
end

AddHeader()

local CurrentPage = PageNames[props["page_index"].Value]
if CurrentPage == "Control" then
  table.insert(graphics,{
    Type = "GroupBox",
    Text = "Control",
    Fill = PanelFill,
    StrokeWidth = 1,
    Position = {5,76},
    Size = {200,100}
  })
  table.insert(graphics,{
    Type = "Text",
    Text = "Say Hello:",
    Position = {10,113},
    Size = {90,16},
    FontSize = 14,
    HTextAlign = "Right"
  })
  layout["SendButton"] = {
    PrettyName = "Buttons~Send The Command",
    Style = "Button",
    Position = {105,113},
    Size = {50,16},
    Color = Black
  }
elseif CurrentPage == "Setup" then
  -- TBD
end
