-- Test script for static analyzer

-- Initialize logging system
local logging
---@diagnostic disable-next-line: unused-local
local ok, err = pcall(function()
  logging = require("lib.tools.logging")
end)
if not ok or not logging then
  -- Fall back to standard print if logging module isn't available
  logging = {
    configure = function() end,
    get_logger = function()
      return {
        info = print,
        error = print,
        warn = print,
        debug = print,
        verbose = print,
      }
    end,
  }
end

-- Get logger for test_static_analyzer module
---@diagnostic disable-next-line: redundant-parameter
local logger = logging.get_logger("test_static_analyzer")
-- Configure from config if possible
logging.configure_from_config("test_static_analyzer")

local static_analyzer = require("lib.coverage.static_analyzer")

local function test_analyzer()
  logger.info("Testing Static Analyzer")
  logger.info("------------------------")

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

  logger.info("\nTesting with simple code:")
  local ast, code_map = static_analyzer.parse_content(simple_code)

  if not ast then
    logger.error("Failed to parse code")
    return
  end

  logger.info("  Parsed successfully")
  logger.info("  Line count: " .. code_map.line_count)

  logger.info("\n  Functions found:")
  for i, func in ipairs(code_map.functions) do
    logger.info(
      string.format(
        "    Function %d: lines %d-%d, params: %s",
        i,
        func.start_line,
        func.end_line,
        table.concat(func.params, ", ")
      )
    )
  end

  logger.info("\n  Executable lines:")
  local executable_lines = static_analyzer.get_executable_lines(code_map)
  logger.info("    " .. table.concat(executable_lines, ", "))

  logger.info("\n  Line classification:")
  for i = 1, code_map.line_count do
    local line_type = code_map.lines[i].type
    local executable = code_map.lines[i].executable and "executable" or "non-executable"
    logger.info(string.format("    Line %2d: %s (%s)", i, executable, line_type))
  end

  -- Test with a file
  logger.info("\nTesting with an actual file:")
  local file_path = "./lib/coverage/static_analyzer.lua"
  local file_ast, file_code_map = static_analyzer.parse_file(file_path)

  if not file_ast then
    logger.error("Failed to parse file: " .. file_path)
    return
  end

  logger.info("  Successfully parsed: " .. file_path)
  logger.info("  Line count: " .. file_code_map.line_count)
  logger.info("  Functions: " .. #file_code_map.functions)
  logger.info("  Executable lines: " .. #static_analyzer.get_executable_lines(file_code_map))
end

test_analyzer()
