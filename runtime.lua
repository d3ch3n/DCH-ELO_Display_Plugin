local DefaultPort = 23
local DefaultTimeout = 5
local DefaultPollInterval = 15
local DefaultFastPollInterval = 5

local Status = {
  OK = 0,
  Compromised = 1,
  Fault = 2,
  NotPresent = 3,
  Missing = 4,
  Initializing = 5
}

local Commands = {
  RecallDefaults = 0x04,
  Brightness = 0x10,
  Contrast = 0x12,
  AutoAdjust = 0x1E,
  Input = 0x60,
  VolumeStep = 0x61,
  Volume = 0x62,
  Temperature = 0xB1,
  Lifetime = 0xC0,
  Touch = 0xC7,
  Power = 0xD6
}

local SourceValues = {
  ["HDMI 1"] = 0x20,
  ["HDMI 2"] = 0x10,
  ["DisplayPort"] = 0x40,
  ["USB-C"] = 0x08,
  ["Side HDMI"] = 0x04,
  ["ECM HDMI"] = 0x02,
  ["ECM DP"] = 0x01,
  ["VGA"] = 0x80
}

local SourceNames = {}
for name, value in pairs(SourceValues) do
  SourceNames[value] = name
end

local socket = nil
local timeoutTimer = Timer.New()
local pollTimer = Timer.New()
local fastPollTimer = Timer.New()
local retryTimer = Timer.New()
local levelTimers = {}
local pendingLevelValues = {}
local queue = {}
local currentCommand = nil
local rxBuffer = ""
local updatingFeedback = false
local socketConnected = false
local currentPowerState = nil

local function HasControl(name)
  return Controls[name] ~= nil
end

local function Control(name)
  return Controls[name]
end

local function GetProperty(name, fallback)
  if Properties and Properties[name] ~= nil and Properties[name].Value ~= nil then
    return Properties[name].Value
  end
  return fallback
end

local function PropIsYes(name, default)
  local value = tostring(GetProperty(name, default and "Yes" or "No"))
  return value == "Yes" or value == "true" or value == "1"
end

local function DebugLevel()
  return tostring(GetProperty("Debug Level", "None"))
end

local function DebugPrint(level, message)
  local selected = DebugLevel()
  if selected == "All" or selected == level or (selected == "Tx/Rx" and (level == "Tx" or level == "Rx")) then
    print(message)
  end
end

local function SetStatus(code, text)
  if HasControl("ConnectionStatus") then
    Control("ConnectionStatus").Value = code
  end
  if HasControl("StatusText") then
    Control("StatusText").String = text
  end
end

local function SetConnected(state)
  socketConnected = state
  if HasControl("ConnectionActive") then
    Control("ConnectionActive").Boolean = state
  end
end

local function SetControlString(name, value)
  if HasControl(name) then
    Control(name).String = tostring(value or "")
  end
end

local function SetControlValue(name, value)
  if HasControl(name) then
    Control(name).Value = tonumber(value) or 0
  end
end

local function SetControlBoolean(name, value)
  if HasControl(name) then
    local state = value and true or false
    Control(name).Boolean = state
    Control(name).Value = state and 1 or 0
    Control(name).Position = state and 1 or 0
  end
end

local function Port()
  local value = DefaultPort
  if HasControl("TCPPort") and Control("TCPPort").String ~= nil and tonumber(Control("TCPPort").String) ~= nil then
    value = math.floor(tonumber(Control("TCPPort").String))
  else
    value = tonumber(GetProperty("TCP Port", DefaultPort)) or DefaultPort
  end
  if value < 1 or value > 65535 then
    value = DefaultPort
  end
  return value
end

local function IPAddress()
  if HasControl("IPAddress") and Control("IPAddress").String ~= nil and Control("IPAddress").String ~= "" then
    return Control("IPAddress").String
  end
  return tostring(GetProperty("IP Address", ""))
end

local function ResponseTimeout()
  return tonumber(GetProperty("Response Timeout", DefaultTimeout)) or DefaultTimeout
end

local function RetryCount()
  return tonumber(GetProperty("Retry Count", 2)) or 2
end

local function PollInterval()
  return tonumber(GetProperty("Poll Interval", DefaultPollInterval)) or DefaultPollInterval
end

local function FastPollInterval()
  return tonumber(GetProperty("Fast Poll Interval", DefaultFastPollInterval)) or DefaultFastPollInterval
end

local function RetryDelay()
  return tonumber(GetProperty("Retry Delay", 5)) or 5
end

local function ClampPercent(value)
  value = math.floor(tonumber(value) or 0)
  if value < 0 then
    return 0
  elseif value > 100 then
    return 100
  end
  return value
end

local function Hex(data)
  local out = {}
  for i = 1, #data do
    table.insert(out, string.format("%02X", string.byte(data, i)))
  end
  return table.concat(out, " ")
end

local function BuildFrame(command, rw, values)
  values = values or {}
  local bytes = {0x6E, 0x80 + 3 + #values, 0xFF, rw, command}
  for _, value in ipairs(values) do
    table.insert(bytes, value)
  end
  local checksum = 0
  for _, byte in ipairs(bytes) do
    checksum = (checksum + byte) % 256
  end
  local frame = {0x02}
  for _, byte in ipairs(bytes) do
    table.insert(frame, byte)
  end
  table.insert(frame, checksum)
  table.insert(frame, 0x03)
  local chars = {}
  for _, byte in ipairs(frame) do
    table.insert(chars, string.char(byte))
  end
  return table.concat(chars)
end

local function ReadFrame(command)
  return BuildFrame(command, 0x01, {})
end

local function WriteFrame(command, values)
  return BuildFrame(command, 0x04, values)
end

local function SetPowerUnknown()
  currentPowerState = nil
  updatingFeedback = true
  SetControlBoolean("PowerOn", false)
  SetControlBoolean("PowerOff", false)
  SetControlBoolean("PowerIsOn", false)
  SetControlBoolean("PowerIsOff", false)
  SetControlString("PowerStatus", "Unknown")
  updatingFeedback = false
end

local function UpdatePower(value)
  local on = value == 0x01
  local off = value == 0x05 or value == 0x00
  updatingFeedback = true
  if on then
    currentPowerState = true
    SetControlBoolean("PowerOn", true)
    SetControlBoolean("PowerOff", false)
    SetControlBoolean("Power", true)
    SetControlBoolean("PowerIsOn", true)
    SetControlBoolean("PowerIsOff", false)
    SetControlString("PowerStatus", "ON")
  elseif off then
    currentPowerState = false
    SetControlBoolean("PowerOn", false)
    SetControlBoolean("PowerOff", true)
    SetControlBoolean("Power", false)
    SetControlBoolean("PowerIsOn", false)
    SetControlBoolean("PowerIsOff", true)
    SetControlString("PowerStatus", "OFF")
  else
    SetControlString("PowerStatus", string.format("0x%02X", value or 0))
  end
  updatingFeedback = false
end

local function UpdateSource(value)
  local source = SourceNames[value] or string.format("0x%02X", value or 0)
  updatingFeedback = true
  SetControlString("CurrentSource", source)
  if SourceValues[source] ~= nil then
    SetControlString("SourceSelect", source)
  end
  SetControlBoolean("HDMI1Active", value == SourceValues["HDMI 1"])
  SetControlBoolean("HDMI2Active", value == SourceValues["HDMI 2"])
  SetControlBoolean("DPActive", value == SourceValues["DisplayPort"])
  SetControlBoolean("USBCActive", value == SourceValues["USB-C"])
  updatingFeedback = false
end

local function UpdateTouch(value)
  local enabled = value == 0x01
  updatingFeedback = true
  SetControlBoolean("TouchEnabled", enabled)
  SetControlString("TouchStatus", enabled and "ON" or "OFF")
  updatingFeedback = false
end

local function WordAt(data, index)
  local high = string.byte(data, index) or 0
  local low = string.byte(data, index + 1) or 0
  return high * 256 + low
end

local function HandleReadResponse(command, data)
  if command == Commands.Power then
    UpdatePower(string.byte(data, 2) or string.byte(data, 1))
  elseif command == Commands.Input then
    UpdateSource(string.byte(data, 1))
  elseif command == Commands.Volume then
    local current = string.byte(data, 4) or string.byte(data, 2) or 0
    updatingFeedback = true
    SetControlValue("Volume", current)
    SetControlString("VolumeFeedback", tostring(current))
    updatingFeedback = false
  elseif command == Commands.Brightness then
    local current = string.byte(data, 4) or WordAt(data, 3)
    updatingFeedback = true
    SetControlValue("Brightness", current)
    SetControlString("BrightnessFeedback", tostring(current))
    updatingFeedback = false
  elseif command == Commands.Contrast then
    local current = string.byte(data, 4) or WordAt(data, 3)
    updatingFeedback = true
    SetControlValue("Contrast", current)
    SetControlString("ContrastFeedback", tostring(current))
    updatingFeedback = false
  elseif command == Commands.Temperature then
    local temp = WordAt(data, 3)
    SetControlString("Temperature", tostring(temp) .. " C")
  elseif command == Commands.Lifetime then
    SetControlString("PowerHours", tostring(WordAt(data, 1)))
    SetControlString("BacklightHours", tostring(WordAt(data, 3)))
  elseif command == Commands.Touch then
    UpdateTouch(string.byte(data, 2) or string.byte(data, 1))
  end
end

local function HandleWriteAck(command, errorCode)
  if errorCode == 0x04 then
    SetControlString("CommandStatus", "OK")
    if command == Commands.Power and currentCommand ~= nil then
      local value = currentCommand.values[2]
      UpdatePower(value)
    elseif command == Commands.Input and currentCommand ~= nil then
      UpdateSource(currentCommand.values[1])
    elseif command == Commands.Touch and currentCommand ~= nil then
      UpdateTouch(currentCommand.values[2])
    end
  else
    SetControlString("CommandStatus", string.format("Error 0x%02X", errorCode or 0))
    SetStatus(Status.Compromised, "Command rejected")
  end
end

local function ParseFrame(frame)
  if #frame < 8 then
    return nil
  end
  local checksum = 0
  for i = 2, #frame - 2 do
    checksum = (checksum + (string.byte(frame, i) or 0)) % 256
  end
  local received = string.byte(frame, #frame - 1) or 0
  if checksum ~= received then
    DebugPrint("Rx", "RX checksum mismatch: " .. Hex(frame))
  end
  local rwOrError = string.byte(frame, 5)
  local command = string.byte(frame, 6)
  local data = ""
  if #frame > 8 then
    data = string.sub(frame, 7, #frame - 2)
  end
  return {rwOrError = rwOrError, command = command, data = data, raw = frame}
end

local function ExtractFrames()
  local frames = {}
  while true do
    local start = string.find(rxBuffer, string.char(0x02), 1, true)
    if start == nil then
      rxBuffer = ""
      break
    end
    if start > 1 then
      rxBuffer = string.sub(rxBuffer, start)
    end
    if #rxBuffer < 5 then
      break
    end
    local lengthByte = string.byte(rxBuffer, 3) or 0x80
    local bodyLength = lengthByte - 0x80
    if bodyLength < 0 then
      rxBuffer = string.sub(rxBuffer, 2)
    else
      local frameLength = bodyLength + 5
      if #rxBuffer < frameLength then
        break
      end
      local frame = string.sub(rxBuffer, 1, frameLength)
      rxBuffer = string.sub(rxBuffer, frameLength + 1)
      if string.byte(frame, #frame) == 0x03 then
        table.insert(frames, frame)
      else
        DebugPrint("Rx", "RX invalid frame: " .. Hex(frame))
      end
    end
  end
  return frames
end

CommandQueue = {}

function CommandQueue.Add(item)
  table.insert(queue, item)
  CommandQueue.Process()
end

function CommandQueue.AddPriority(item)
  table.insert(queue, 1, item)
  CommandQueue.Process()
end

function CommandQueue.Process()
  if currentCommand ~= nil or socket == nil or not socketConnected then
    return
  end
  currentCommand = table.remove(queue, 1)
  if currentCommand ~= nil then
    CommandQueue.SendCurrent()
  end
end

function CommandQueue.SendCurrent()
  if currentCommand == nil or socket == nil or not socketConnected then
    return
  end
  DebugPrint("Tx", "TX: " .. Hex(currentCommand.frame))
  socket:Write(currentCommand.frame)
  timeoutTimer:Start(ResponseTimeout())
end

function CommandQueue.Timeout()
  if currentCommand == nil then
    return
  end
  if currentCommand.retries < RetryCount() then
    currentCommand.retries = currentCommand.retries + 1
    CommandQueue.SendCurrent()
  else
    SetStatus(Status.Fault, "Response timeout")
    currentCommand = nil
    CommandQueue.Process()
  end
end

function CommandQueue.Clear()
  queue = {}
  currentCommand = nil
  timeoutTimer:Stop()
end

local function AddRead(command, priority)
  local item = {frame = ReadFrame(command), command = command, rw = 0x01, values = {}, retries = 0}
  if priority then
    CommandQueue.AddPriority(item)
  else
    CommandQueue.Add(item)
  end
end

local function AddWrite(command, values)
  CommandQueue.AddPriority({frame = WriteFrame(command, values), command = command, rw = 0x04, values = values, retries = 0})
end

local function Poll()
  AddRead(Commands.Power)
  AddRead(Commands.Input)
  AddRead(Commands.Volume)
  AddRead(Commands.Brightness)
  AddRead(Commands.Contrast)
  if PropIsYes("Enable Touch Control", true) then
    AddRead(Commands.Touch)
  end
  if PropIsYes("Enable Diagnostics", true) then
    AddRead(Commands.Temperature)
    AddRead(Commands.Lifetime)
  end
end

local function FastPoll()
  AddRead(Commands.Power, true)
  AddRead(Commands.Input, true)
  AddRead(Commands.Volume, true)
  AddRead(Commands.Brightness, true)
  AddRead(Commands.Contrast, true)
  fastPollTimer:Stop()
end

local function CompleteCurrent(frame)
  local parsed = ParseFrame(frame)
  if parsed == nil then
    return
  end
  DebugPrint("Rx", "RX: " .. Hex(frame))
  if currentCommand ~= nil and parsed.command == currentCommand.command then
    if currentCommand.rw == 0x04 then
      HandleWriteAck(parsed.command, parsed.rwOrError)
    else
      HandleReadResponse(parsed.command, parsed.data)
    end
    timeoutTimer:Stop()
    currentCommand = nil
    SetStatus(Status.OK, "OK")
    CommandQueue.Process()
  else
    HandleReadResponse(parsed.command, parsed.data)
  end
end

local function CloseSocket()
  CommandQueue.Clear()
  pollTimer:Stop()
  fastPollTimer:Stop()
  if socket ~= nil then
    socket:Disconnect()
  end
  SetConnected(false)
  SetStatus(Status.NotPresent, "Offline")
end

local function ScheduleRetry(reason)
  pollTimer:Stop()
  fastPollTimer:Stop()
  SetConnected(false)
  if reason ~= nil and reason ~= "" then
    SetStatus(Status.Fault, reason)
  end
  retryTimer:Start(RetryDelay())
  SetStatus(Status.Compromised, "Reconnecting")
end

local function OpenSocket()
  local ip = IPAddress()
  if ip == "" then
    SetConnected(false)
    SetStatus(Status.Missing, "Missing IP Address")
    retryTimer:Stop()
    return
  end

  retryTimer:Stop()
  CommandQueue.Clear()
  pollTimer:Stop()
  fastPollTimer:Stop()

  if socket == nil then
    socket = TcpSocket.New()
    socket.EventHandler = function(sock, event, err)
      if event == TcpSocket.Events.Connected then
        SetConnected(true)
        SetStatus(Status.Compromised, "Connected, waiting for feedback")
        SetPowerUnknown()
        Poll()
        pollTimer:Start(PollInterval())
      elseif event == TcpSocket.Events.Data then
        local data = sock:Read(sock.BufferLength)
        rxBuffer = rxBuffer .. data
        for _, frame in ipairs(ExtractFrames()) do
          CompleteCurrent(frame)
        end
      elseif event == TcpSocket.Events.Closed or event == TcpSocket.Events.Error or event == TcpSocket.Events.Timeout then
        ScheduleRetry(err or "Connection Error")
      end
    end
  end

  SetStatus(Status.Compromised, "Connecting to " .. ip .. ":" .. Port())
  DebugPrint("Function Calls", "Connecting to " .. ip .. ":" .. Port())
  socket:Connect(ip, Port())
end

local function InitializeControls()
  SetControlString("IPAddress", IPAddress())
  SetControlString("TCPPort", Port())
  SetPowerUnknown()
  SetControlString("CurrentSource", "")
  SetControlString("VolumeFeedback", "")
  SetControlString("BrightnessFeedback", "")
  SetControlString("ContrastFeedback", "")
  SetConnected(false)
  SetStatus(Status.Initializing, "Initializing")
  OpenSocket()
end

local function QueuePower(powerState)
  local value = powerState and 0x01 or 0x05
  AddWrite(Commands.Power, {0x00, value})
  AddRead(Commands.Power)
  fastPollTimer:Start(FastPollInterval())
end

local function QueueSource(sourceName)
  local value = SourceValues[sourceName]
  if value ~= nil then
    AddWrite(Commands.Input, {value})
    AddRead(Commands.Input)
    fastPollTimer:Start(FastPollInterval())
  end
end

local function QueuePercent(command, value)
  value = ClampPercent(value)
  AddWrite(command, {0x00, value})
  AddRead(command)
end

local function BindDebouncedLevel(name, command, delay)
  if HasControl(name) then
    levelTimers[name] = Timer.New()
    levelTimers[name].EventHandler = function()
      levelTimers[name]:Stop()
      if pendingLevelValues[name] == nil then
        return
      end
      local value = pendingLevelValues[name]
      pendingLevelValues[name] = nil
      QueuePercent(command, value)
    end
    Control(name).EventHandler = function(control)
      if updatingFeedback then
        return
      end
      pendingLevelValues[name] = ClampPercent(control.Value or 0)
      levelTimers[name]:Stop()
      levelTimers[name]:Start(delay or 0.75)
    end
  end
end

timeoutTimer.EventHandler = CommandQueue.Timeout
pollTimer.EventHandler = Poll
fastPollTimer.EventHandler = FastPoll
retryTimer.EventHandler = OpenSocket

if HasControl("IPAddress") then
  Control("IPAddress").EventHandler = function()
    CloseSocket()
    OpenSocket()
  end
end

if HasControl("TCPPort") then
  Control("TCPPort").EventHandler = function()
    CloseSocket()
    OpenSocket()
  end
end

if HasControl("PowerOn") then
  Control("PowerOn").EventHandler = function(control)
    if not updatingFeedback and control.Boolean then
      QueuePower(true)
    end
  end
end

if HasControl("PowerOff") then
  Control("PowerOff").EventHandler = function(control)
    if not updatingFeedback and control.Boolean then
      QueuePower(false)
    end
  end
end

if HasControl("Power") then
  Control("Power").EventHandler = function(control)
    if not updatingFeedback then
      QueuePower(control.Boolean)
    end
  end
end

if HasControl("PowerPoll") then
  Control("PowerPoll").EventHandler = function()
    AddRead(Commands.Power, true)
  end
end

if HasControl("SourceSelect") then
  Control("SourceSelect").EventHandler = function(control)
    if not updatingFeedback then
      QueueSource(control.String)
    end
  end
end

if HasControl("SourceHDMI1") then Control("SourceHDMI1").EventHandler = function() QueueSource("HDMI 1") end end
if HasControl("SourceHDMI2") then Control("SourceHDMI2").EventHandler = function() QueueSource("HDMI 2") end end
if HasControl("SourceDP") then Control("SourceDP").EventHandler = function() QueueSource("DisplayPort") end end
if HasControl("SourceUSBC") then Control("SourceUSBC").EventHandler = function() QueueSource("USB-C") end end

BindDebouncedLevel("Volume", Commands.Volume, 0.75)
BindDebouncedLevel("Brightness", Commands.Brightness, 0.75)
BindDebouncedLevel("Contrast", Commands.Contrast, 0.75)

if HasControl("VolumeUp") then Control("VolumeUp").EventHandler = function() AddWrite(Commands.VolumeStep, {0x00, 0x01}); AddRead(Commands.Volume) end end
if HasControl("VolumeDown") then Control("VolumeDown").EventHandler = function() AddWrite(Commands.VolumeStep, {0x01, 0x01}); AddRead(Commands.Volume) end end

if HasControl("TouchEnabled") then
  Control("TouchEnabled").EventHandler = function(control)
    if not updatingFeedback then
      AddWrite(Commands.Touch, {0x00, control.Boolean and 0x01 or 0x00})
      AddRead(Commands.Touch)
    end
  end
end

if HasControl("ReadStatus") then
  Control("ReadStatus").EventHandler = function()
    Poll()
  end
end

if HasControl("RecallDefaults") then
  Control("RecallDefaults").EventHandler = function()
    AddWrite(Commands.RecallDefaults, {0x00, 0x01})
    fastPollTimer:Start(FastPollInterval())
  end
end

if HasControl("AutoAdjust") then
  Control("AutoAdjust").EventHandler = function()
    AddWrite(Commands.AutoAdjust, {0x00, 0x01})
  end
end

InitializeControls()
