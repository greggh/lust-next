#!/usr/bin/env lua
-- Test script for the firmo parser module

package.path = "/home/gregg/Projects/lua-library/firmo/?.lua;" .. package.path

-- Initialize logging system
local logging
local ok, err = pcall(function() logging = require("lib.tools.logging") end)
if not ok or not logging then
  -- Fall back to standard print if logging module isn't available
  logging = {
    configure = function() end,
    get_logger = function() return {
      info = print,
      error = print,
      warn = print,
      debug = print,
      verbose = print
    } end
  }
end

-- Get logger for test_parser module
local logger = logging.get_logger("test_parser")
-- Configure from config if possible
logging.configure_from_config("test_parser")

logger.info("Testing parser module...")

local ok, parser = pcall(function()
  return require("lib.tools.parser")
end)

if not ok then
  logger.error("Failed to load parser module: " .. tostring(parser))
  os.exit(1)
end

logger.info("Parser module loaded successfully")

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
  logger.error("Parse error: " .. tostring(ast))
  os.exit(1)
end

logger.info("Parsed sample code successfully")
logger.info("Pretty printing AST sample...")
local pp_output = parser.pretty_print(ast)
logger.info(string.sub(pp_output, 1, 100) .. "...")

logger.info("\nTesting executable line detection...")
local executable_lines = parser.get_executable_lines(ast, code)
logger.info("Executable lines found: " .. (function()
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
logger.info(lines_str)

logger.info("\nTesting function detection...")
local functions = parser.get_functions(ast, code)
logger.info("Functions found: " .. #functions)

-- Print function details
for i, func in ipairs(functions) do
  logger.info(string.format("Function %d: %s (lines %d-%d, params: %s%s)",
    i,
    func.name,
    func.line_start,
    func.line_end,
    table.concat(func.params, ", "),
    func.is_vararg and ", ..." or ""
  ))
end

logger.info("\nTesting code map creation...")
local code_map = parser.create_code_map(code, "test_code")
if code_map.valid then
  logger.info("Created valid code map")
  logger.info("Source lines: " .. code_map.source_lines)
else
  logger.error("Error creating code map: " .. tostring(code_map.error))
  os.exit(1)
end

logger.info("\nParser module test completed successfully!")
