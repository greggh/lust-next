-- This file tests the improved multiline comment detection in coverage reports
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect

--[[ This is a multiline comment
that spans multiple lines
It should be correctly detected as non-executable
]]

-- Function with different comment types and print statements
local function test_function()
  -- Single line comment
  print("This line should be marked as executed") -- Comment at end of line
  
  --[[ Multiline comment within function ]]
  
  local x = 5 --[[ Inline multiline comment ]] local y = 10
  
  print("Another print statement that should be executed")
  
  --[[ Another multiline 
  comment that spans
  multiple lines ]]
  print("Final print statement")
  
  return x + y
end

describe("Multiline Comment Coverage Test", function()
  it("should execute all print statements", function()
    local result = test_function()
    expect(result).to.equal(15)
  end)
end)