-- Test for multiline comment detection in static analyzer
local static_analyzer = require("lib.coverage.static_analyzer")
local fs = require("lib.tools.filesystem")

-- Initialize static analyzer
static_analyzer.init()

-- Create a test file with various comment types
local test_file_path = "/tmp/multiline_comment_test.lua"
local test_content = [=[
-- This is a single line comment
print("Line 2: This should be executable")

--[[ This is a multiline comment
spanning multiple lines
and should be detected as non-executable ]]

print("Line 7: This should be executable")

local x = 5 --[[ Inline multiline comment ]] local y = 10
print("Line 10: Final executable line")
]=]

-- Write the test file
fs.write_file(test_file_path, test_content)

-- Analyze all lines in the file and report their classification
print("\nStatic Analyzer Classification Test")
print("===================================")
print("Legend: [E] = Executable, [N] = Non-executable")
print("")

-- Split into lines for reference
local lines = {}
for line in test_content:gmatch("[^\r\n]+") do
  table.insert(lines, line)
end

for i = 1, #lines do
  local line_type = static_analyzer.classify_line_simple(test_file_path, i)
  local is_executable = static_analyzer.is_line_executable(test_file_path, i)
  
  local status = is_executable and "[E]" or "[N]"
  print(string.format("Line %d: %s %s", i, status, lines[i]))
end

-- Clean up
os.remove(test_file_path)
print("\nTest completed. All lines should be correctly classified.")
print("Lines with print statements should be [E] (executable).")
print("Comment lines should be [N] (non-executable).")