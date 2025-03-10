--[[
  control_flow_test.lua
  
  A simple file used to demonstrate how control flow keywords
  affect coverage reporting.
]]

local function example_with_control_flow()
  local result = 0
  
  -- Simple if statement with else branch
  if result == 0 then
    result = 1
  else
    result = 2
  end
  
  -- Simple for loop
  for i = 1, 3 do
    result = result + i
  end
  
  -- While loop
  local i = 0
  while i < 3 do
    result = result + 1
    i = i + 1
  end
  
  return result
end

return example_with_control_flow()