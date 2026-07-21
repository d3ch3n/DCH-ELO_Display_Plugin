local Sources = {
  "HDMI 1",
  "HDMI 2",
  "DisplayPort",
  "USB-C",
  "Side HDMI",
  "ECM HDMI",
  "ECM DP",
  "VGA"
}

local function AddControl(control)
  table.insert(ctrls, control)
end

local function PropIsYes(name, default)
  if props[name] == nil or props[name].Value == nil then
    return default
  end
  local value = tostring(props[name].Value)
  return value == "Yes" or value == "true" or value == "1"
end

AddControl({Name = "IPAddress", ControlType = "Text", Count = 1})
AddControl({Name = "TCPPort", ControlType = "Text", Count = 1})
AddControl({Name = "ConnectionActive", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
AddControl({Name = "ConnectionStatus", ControlType = "Indicator", IndicatorType = "Status", Count = 1, IsReadOnly = true})
AddControl({Name = "StatusText", ControlType = "Text", Count = 1, IsReadOnly = true})

AddControl({Name = "PowerOn", ControlType = "Button", ButtonType = "Toggle", Count = 1, UserPin = true, PinStyle = "Input", Icon = "Power"})
AddControl({Name = "PowerOff", ControlType = "Button", ButtonType = "Toggle", Count = 1, UserPin = true, PinStyle = "Input", Icon = "Power"})
AddControl({Name = "Power", ControlType = "Button", ButtonType = "Toggle", Count = 1, UserPin = true, PinStyle = "Input", Icon = "Power"})
AddControl({Name = "PowerPoll", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})
AddControl({Name = "PowerIsOn", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
AddControl({Name = "PowerIsOff", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
AddControl({Name = "PowerStatus", ControlType = "Text", Count = 1, IsReadOnly = true})

AddControl({Name = "SourceSelect", ControlType = "Text", Count = 1, Choices = Sources, UserPin = true, PinStyle = "Input"})
AddControl({Name = "CurrentSource", ControlType = "Text", Count = 1, IsReadOnly = true})
AddControl({Name = "SourceHDMI1", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})
AddControl({Name = "SourceHDMI2", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})
AddControl({Name = "SourceDP", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})
AddControl({Name = "SourceUSBC", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})
AddControl({Name = "HDMI1Active", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
AddControl({Name = "HDMI2Active", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
AddControl({Name = "DPActive", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
AddControl({Name = "USBCActive", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})

AddControl({Name = "Volume", ControlType = "Knob", ControlUnit = "Integer", Min = 0, Max = 100, Count = 1, UserPin = true, PinStyle = "Input"})
AddControl({Name = "VolumeFeedback", ControlType = "Text", Count = 1, IsReadOnly = true})
AddControl({Name = "VolumeUp", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})
AddControl({Name = "VolumeDown", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})

AddControl({Name = "Brightness", ControlType = "Knob", ControlUnit = "Integer", Min = 0, Max = 100, Count = 1, UserPin = true, PinStyle = "Input"})
AddControl({Name = "Contrast", ControlType = "Knob", ControlUnit = "Integer", Min = 0, Max = 100, Count = 1, UserPin = true, PinStyle = "Input"})
AddControl({Name = "BrightnessFeedback", ControlType = "Text", Count = 1, IsReadOnly = true})
AddControl({Name = "ContrastFeedback", ControlType = "Text", Count = 1, IsReadOnly = true})
AddControl({Name = "RecallDefaults", ControlType = "Button", ButtonType = "Trigger", Count = 1})
AddControl({Name = "AutoAdjust", ControlType = "Button", ButtonType = "Trigger", Count = 1})

if PropIsYes("Enable Touch Control", true) then
  AddControl({Name = "TouchEnabled", ControlType = "Button", ButtonType = "Toggle", Count = 1, UserPin = true, PinStyle = "Input"})
  AddControl({Name = "TouchStatus", ControlType = "Text", Count = 1, IsReadOnly = true})
end

if PropIsYes("Enable Diagnostics", true) then
  AddControl({Name = "ReadStatus", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})
  AddControl({Name = "Temperature", ControlType = "Text", Count = 1, IsReadOnly = true})
  AddControl({Name = "PowerHours", ControlType = "Text", Count = 1, IsReadOnly = true})
  AddControl({Name = "BacklightHours", ControlType = "Text", Count = 1, IsReadOnly = true})
  AddControl({Name = "CommandStatus", ControlType = "Text", Count = 1, IsReadOnly = true})
end
