--[[ #include "image_assets.lua" ]]

local HeaderFill = {225,225,225}
local BodyFill = {230,230,230}
local PanelStroke = {30,30,30}
local ButtonGray = {105,105,105}
local ButtonBlue = {0,185,230}
local Green = {0,145,0}
local Red = {190,60,55}
local DarkRed = {125,35,35}
local PageWidth = 518
local PageHeight = 690

local function PropIsYes(name, default)
  if props[name] == nil or props[name].Value == nil then
    return default
  end
  local value = tostring(props[name].Value)
  return value == "Yes" or value == "true" or value == "1"
end

local function AddText(text, x, y, w, h, size, align)
  table.insert(graphics,{
    Type = "Text",
    Text = text,
    Position = {x,y},
    Size = {w,h},
    FontSize = size or 9,
    HTextAlign = align or "Center"
  })
end

local function AddButton(name, x, y, w, h, legend, color, style)
  layout[name] = {
    PrettyName = name,
    Legend = legend,
    Style = "Button",
    ButtonStyle = style or "Trigger",
    Color = color or ButtonGray,
    Position = {x,y},
    Size = {w,h},
    FontSize = 10
  }
end

local function AddTextControl(name, x, y, w, h, style)
  layout[name] = {
    PrettyName = name,
    Style = style or "Text",
    Position = {x,y},
    Size = {w,h},
    FontSize = 8
  }
end

local function AddLed(name, x, y, color)
  layout[name] = {
    PrettyName = name,
    Style = "Led",
    Color = color or Green,
    Position = {x,y},
    Size = {16,16}
  }
end

local function AddFader(name, x, y)
  layout[name] = {
    PrettyName = name,
    Style = "Fader",
    Position = {x,y},
    Size = {36,130},
    FontSize = 8
  }
end

local function AddGroupBox(title, x, y, w, h, fill)
  table.insert(graphics,{
    Type = "GroupBox",
    Text = title,
    Fill = fill or BodyFill,
    StrokeWidth = 1,
    StrokeColor = PanelStroke,
    Position = {x,y},
    Size = {w,h}
  })
end

local function AddHeader()
  table.insert(graphics,{Type = "GroupBox", Fill = HeaderFill, StrokeWidth = 1, StrokeColor = PanelStroke, Position = {0,0}, Size = {PageWidth,PageHeight}})
  table.insert(graphics,{Type = "GroupBox", Fill = BodyFill, StrokeWidth = 0, Position = {10,140}, Size = {PageWidth - 20,PageHeight - 150}})
  AddGroupBox("HEADER", 10, 10, PageWidth - 20, 120, HeaderFill)
  table.insert(graphics,{Type = "Image", Image = DechenLogo, Position = {20,20}, Size = {140,45}})
  table.insert(graphics,{Type = "Image", Image = EloLogo, Position = {382,18}, Size = {76,60}})
  AddText("DCH Elo IDS", 188, 32, 142, 20, 14)
  AddText("MDC Monitor Control", 186, 54, 146, 16, 10)
  AddText("IP ADDRESS", 20, 74, 92, 14, 8, "Left")
  AddText("PORT", 118, 74, 30, 14, 8, "Left")
  AddText("STATUS", 150, 74, 108, 14, 8, "Left")
  AddTextControl("IPAddress", 22, 90, 92, 25, "Text")
  AddTextControl("TCPPort", 118, 90, 28, 25, "Text")
  AddTextControl("StatusText", 150, 90, 110, 25, "Textdisplay")
  AddLed("ConnectionActive", 385, 95, Green)
  AddText("TCP", 406, 94, 34, 16, 8, "Left")
  layout["ConnectionStatus"] = {PrettyName = "ConnectionStatus", Style = "Status", Position = {270,90}, Size = {102,25}, FontSize = 8}
end

local function AddPowerBlock()
  AddButton("PowerOn", 54, 190, 100, 30, "Power On", ButtonBlue, "Toggle")
  layout["PowerOn"].OffColor = ButtonGray
  layout["PowerOn"].UnlinkOffColor = true
  AddButton("PowerOff", 54, 225, 100, 30, "Power Off", Red, "Toggle")
  layout["PowerOff"].OffColor = ButtonGray
  layout["PowerOff"].UnlinkOffColor = true
  layout["Power"] = {
    PrettyName = "Power",
    Legend = "Power",
    Style = "Button",
    ButtonStyle = "Toggle",
    Color = ButtonGray,
    OffColor = DarkRed,
    UnlinkOffColor = true,
    Position = {158,190},
    Size = {100,66},
    FontSize = 10
  }
  AddTextControl("PowerStatus", 54, 262, 204, 20, "Textdisplay")
end

local function AddSourceButtons(x, y)
  local buttons = {
    {"SourceHDMI1", "HDMI 1", "HDMI1Active"},
    {"SourceHDMI2", "HDMI 2", "HDMI2Active"},
    {"SourceDP", "DP", "DPActive"},
    {"SourceUSBC", "USB-C", "USBCActive"}
  }
  for ix, item in ipairs(buttons) do
    local col = (ix - 1) % 2
    local row = math.floor((ix - 1) / 2)
    AddButton(item[1], x + col * 104, y + row * 38, 100, 30, item[2], ix == 1 and ButtonBlue or ButtonGray)
    AddLed(item[3], x + col * 104 + 82, y + row * 38 + 7, Green)
  end
  AddTextControl("SourceSelect", x, y + 86, 100, 24, "ComboBox")
  AddTextControl("CurrentSource", x + 104, y + 86, 100, 24, "Textdisplay")
end

local function AddLevelColumn(levelName, upName, downName, x)
  AddButton(upName, x, 202, 42, 42, "+", ButtonGray)
  AddFader(levelName, x + 3, 248)
  AddButton(downName, x, 393, 42, 42, "-", ButtonGray)
end

local function AddPictureControls()
  AddText("BRIGHTNESS", 54, 544, 96, 14, 8)
  AddText("CONTRAST", 162, 544, 96, 14, 8)
  layout["Brightness"] = {PrettyName = "Brightness", Style = "Fader", Position = {84,564}, Size = {36,78}, FontSize = 8}
  layout["Contrast"] = {PrettyName = "Contrast", Style = "Fader", Position = {192,564}, Size = {36,78}, FontSize = 8}
  AddTextControl("BrightnessFeedback", 54, 648, 96, 20, "Textdisplay")
  AddTextControl("ContrastFeedback", 162, 648, 96, 20, "Textdisplay")
  AddButton("AutoAdjust", 302, 554, 80, 28, "Auto", ButtonGray)
  AddButton("RecallDefaults", 390, 554, 80, 28, "Defaults", Red)
end

local function AddControlPage()
  AddHeader()
  AddGroupBox("POWER", 44, 160, 224, 134)
  AddGroupBox("INPUTS", 44, 306, 224, 154)
  AddGroupBox("PICTURE", 44, 518, 438, 164)
  AddGroupBox("VOLUME", 312, 160, 82, 328)
  AddPowerBlock()
  AddSourceButtons(54, 335)
  AddLevelColumn("Volume", "VolumeUp", "VolumeDown", 337)
  AddTextControl("VolumeFeedback", 326, 444, 64, 24, "Textdisplay")
  AddPictureControls()
end

local function AddTouchPage()
  AddHeader()
  AddGroupBox("TOUCH", 44, 160, 438, 110)
  AddGroupBox("DIAGNOSTICS", 44, 292, 438, 194)
  if PropIsYes("Enable Touch Control", true) then
    AddButton("TouchEnabled", 74, 202, 120, 34, "Touch", ButtonGray, "Toggle")
    AddText("TOUCH STATUS", 222, 197, 116, 14, 8, "Left")
    AddTextControl("TouchStatus", 222, 215, 120, 24, "Textdisplay")
  end
  if PropIsYes("Enable Diagnostics", true) then
    AddButton("ReadStatus", 74, 334, 120, 34, "Read Status", ButtonBlue)
    AddText("COMMAND", 222, 329, 116, 14, 8, "Left")
    AddTextControl("CommandStatus", 222, 347, 172, 24, "Textdisplay")
    AddText("TEMPERATURE", 74, 394, 120, 14, 8, "Left")
    AddTextControl("Temperature", 222, 390, 172, 24, "Textdisplay")
    AddText("POWER HOURS", 74, 426, 120, 14, 8, "Left")
    AddTextControl("PowerHours", 222, 422, 172, 24, "Textdisplay")
    AddText("BACKLIGHT HOURS", 74, 458, 120, 14, 8, "Left")
    AddTextControl("BacklightHours", 222, 454, 172, 24, "Textdisplay")
  end
end

local CurrentPage = PageNames[props["page_index"].Value]
if CurrentPage == "Control" then
  AddControlPage()
elseif CurrentPage == "Touch" then
  AddTouchPage()
end
