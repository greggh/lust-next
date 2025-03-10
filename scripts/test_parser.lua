#!/usr/bin/env lua
-- Test script for the lust-next parser module

package.path = "/home/gregg/Projects/lua-library/lust-next/?.lua;" .. package.path

print("Testing parser module...")

local ok, parser = pcall(function()
  return require("lib.tools.parser")
end)

if not ok then
  print("Failed to load parser module: " .. tostring(parser))
  os.exit(1)
end

print("Parser module loaded successfully")

-- Test simple parsing
local code = [[
local function test(a, b, ...)
  local sum = a + b
  print("The sum is:", sum)
  
  if sum > 10 then
    return true
  else
    return false
  end
end

-- Call the function
test(5, 10)
]]

local ok, ast = pcall(function()
  return parser.parse(code, "test_code")
end)

if not ok then
  print("Parse error: " .. tostring(ast))
  os.exit(1)
end

print("Parsed sample code successfully")
print("Pretty printing AST sample...")
local pp_output = parser.pretty_print(ast)
print(string.sub(pp_output, 1, 100) .. "...")

print("\nTesting executable line detection...")
local executable_lines = parser.get_executable_lines(ast, code)
print("Executable lines found: " .. (function()
  local count = 0
  for _ in pairs(executable_lines) do count = count + 1 end
  return count
end)())

-- Print first few executable lines
local lines_str = "Executable lines: "
local count = 0
for line, _ in pairs(executable_lines) do
  if count < 5 then
    lines_str = lines_str .. line .. ", "
    count = count + 1
  else
    lines_str = lines_str .. "..."
    break
  end
end
print(lines_str)

print("\nTesting function detection...")
local functions = parser.get_functions(ast, code)
print("Functions found: " .. #functions)

-- Print function details
for i, func in ipairs(functions) do
  print(string.format("Function %d: %s (lines %d-%d, params: %s%s)",
    i,
    func.name,
    func.line_start,
    func.line_end,
    table.concat(func.params, ", "),
    func.is_vararg and ", ..." or ""
  ))
end

print("\nTesting code map creation...")
local code_map = parser.create_code_map(code, "test_code")
if code_map.valid then
  print("Created valid code map")
  print("Source lines: " .. code_map.source_lines)
else
  print("Error creating code map: " .. tostring(code_map.error))
  os.exit(1)
end

print("\nParser module test completed successfully!")