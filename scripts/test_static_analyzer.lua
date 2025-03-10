-- Test script for static analyzer
local static_analyzer = require("lib.coverage.static_analyzer")

local function test_analyzer()
  print("Testing Static Analyzer")
  print("------------------------")
  
  -- Test simple code
  local simple_code = [[
local function add(a, b)
  return a + b
end

local result = add(5, 10)
print("Result: " .. result)

-- This is a comment
local x = 20 -- With a trailing comment

if x > 10 then
  print("x is greater than 10")
else
  print("x is not greater than 10")
end
]]

  print("\nTesting with simple code:")
  local ast, code_map = static_analyzer.parse_content(simple_code)
  
  if not ast then
    print("Failed to parse code")
    return
  end
  
  print("  Parsed successfully")
  print("  Line count: " .. code_map.line_count)
  
  print("\n  Functions found:")
  for i, func in ipairs(code_map.functions) do
    print(string.format("    Function %d: lines %d-%d, params: %s", 
      i, func.start_line, func.end_line, table.concat(func.params, ", ")))
  end
  
  print("\n  Executable lines:")
  local executable_lines = static_analyzer.get_executable_lines(code_map)
  print("    " .. table.concat(executable_lines, ", "))
  
  print("\n  Line classification:")
  for i = 1, code_map.line_count do
    local line_type = code_map.lines[i].type
    local executable = code_map.lines[i].executable and "executable" or "non-executable"
    print(string.format("    Line %2d: %s (%s)", i, executable, line_type))
  end
  
  -- Test with a file
  print("\nTesting with an actual file:")
  local file_path = "./lib/coverage/static_analyzer.lua"
  local file_ast, file_code_map = static_analyzer.parse_file(file_path)
  
  if not file_ast then
    print("Failed to parse file: " .. file_path)
    return
  end
  
  print("  Successfully parsed: " .. file_path)
  print("  Line count: " .. file_code_map.line_count)
  print("  Functions: " .. #file_code_map.functions)
  print("  Executable lines: " .. #static_analyzer.get_executable_lines(file_code_map))
end

test_analyzer()