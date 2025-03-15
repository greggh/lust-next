--[[
  multiline_comment_detection_test.lua
  
  This example demonstrates the improved multiline comment detection in coverage reports.
  It contains various comment types including:
  
  1. Standard single-line comments
  2. Multiline comments spanning multiple lines
  3. Inline multiline comments
  
  Running this with coverage will test if all print statements are correctly marked as
  executed and all comments are properly identified as non-executable.
]]

local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect

-- A function with various comment types and print statements
local function test_comments()
  -- Single line comment
  print("Executing line after single-line comment") -- End-of-line comment
  
  --[[ This is a multiline comment
  spanning across multiple
  lines that should be detected
  as non-executable ]]
  
  print("Executing line after multiline comment")
  
  local x = 5 --[[ Inline multiline comment ]] local y = 10
  
  --[[ Another multiline
  comment block ]]
  
  print("Final executable line")
  
  return x + y
end

describe("Multiline Comment Detection", function()
  it("should execute all print statements", function()
    local result = test_comments()
    expect(result).to.equal(15)
    -- The expect statement validates execution, ensuring the function ran
  end)
end)

-- Display instructions
print("\nRunning this example with the coverage flag will generate an HTML report.")
print("Execute the following command to see the HTML coverage report:")
print("\n  lua test.lua --coverage --format=html examples/multiline_comment_detection_test.lua\n")
print("The HTML report should correctly show:")
print("1. All print statements as executed")
print("2. All comment lines (both single-line and multiline) as non-executable")
print("3. No incorrectly marked lines where print statements were executed but shown as not executed")
print("\nAfter running the command, open the generated HTML file in a web browser.\n")