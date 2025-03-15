-- Demonstration of multiline comment coverage handling

print("Starting coverage demo for multiline comments")

-- Create output directory
os.execute("mkdir -p examples/reports/debug")
local output_file = "examples/reports/debug/multiline_comment_coverage.html"

local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect

-- Enable coverage
local coverage = require("lib.coverage")
coverage.start({
  include = { ".*/multiline_comment_demo%.lua$" },
  format = "html",
  output_file = output_file
})

-- Function to test with multiline comments
local function test_comments()
  -- Single line comment
  print("First executable line with print statement")
  
  --[[ This is a multiline comment
  spanning multiple
  lines ]]
  
  print("Second executable line")
  
  local x = 5 --[[ Inline multiline comment ]] local y = 10
  
  --[[ Another
  multiline comment ]]
  
  print("Third executable line")
  
  return x + y
end

-- Run the test function for coverage
print("> Running test_comments() function")
local result = test_comments()
print("> test_comments() returned:", result)

-- Stop coverage and generate report
print("> Generating coverage report...")
coverage.stop()

-- Generate the report directly
local success, err = coverage.generate_report("html", {
  output_file = output_file,
  include = { ".*/multiline_comment_demo%.lua$" }
})

if success then
  print("> Report saved to:", output_file)
  print("> Open this file to see if multiline comments are correctly marked as non-executable")
  print("> and print statements are correctly marked as executed")
else
  print("Failed to generate report:", err)
end