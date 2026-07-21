table.insert(props, {Name = "IP Address", Type = "string", Value = ""})
table.insert(props, {Name = "TCP Port", Type = "integer", Min = 1, Max = 65535, Value = 23})
table.insert(props, {Name = "Poll Interval", Type = "integer", Min = 1, Max = 300, Value = 15})
table.insert(props, {Name = "Fast Poll Interval", Type = "integer", Min = 1, Max = 300, Value = 5})
table.insert(props, {Name = "Response Timeout", Type = "integer", Min = 1, Max = 60, Value = 5})
table.insert(props, {Name = "Retry Count", Type = "integer", Min = 0, Max = 10, Value = 2})
table.insert(props, {Name = "Retry Delay", Type = "integer", Min = 1, Max = 300, Value = 5})
table.insert(props, {Name = "Enable Touch Control", Type = "enum", Choices = {"Yes", "No"}, Value = "Yes"})
table.insert(props, {Name = "Enable Diagnostics", Type = "enum", Choices = {"Yes", "No"}, Value = "Yes"})
table.insert(props, {
  Name = "Debug Level",
  Type = "enum",
  Choices = {"None", "Tx/Rx", "Function Calls", "All"},
  Value = "None"
})
