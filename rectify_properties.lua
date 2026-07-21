local function IsNo(name)
  return props[name] ~= nil and tostring(props[name].Value) == "No"
end

if props.plugin_show_debug ~= nil and props.plugin_show_debug.Value == false and props["Debug Level"] ~= nil then
  props["Debug Level"].IsHidden = true
end

if IsNo("Enable Diagnostics") then
  if props["Fast Poll Interval"] ~= nil then
    props["Fast Poll Interval"].IsHidden = true
  end
end
