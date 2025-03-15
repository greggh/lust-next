-- Test script for lpeglabel integration
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

-- Get logger for test_lpeglabel module
local logger = logging.get_logger("test_lpeglabel")
-- Configure from config if possible
logging.configure_from_config("test_lpeglabel")

logger.info("Starting LPegLabel test", {
  component = "TestScript",
  module = "lpeglabel"
})

-- Attempt to load the lpeglabel module
logger.debug("Attempting to load lpeglabel module", {
  module_path = "lib.tools.vendor.lpeglabel"
})

local ok, lpeglabel = pcall(function()
  return require("lib.tools.vendor.lpeglabel")
end)

if not ok then
  logger.error("Failed to load lpeglabel module", {
    error = tostring(lpeglabel),
    component = "TestScript"
  })
  os.exit(1)
end

local version = type(lpeglabel.version) == "function" and lpeglabel.version() or lpeglabel.version or "unknown"

logger.info("LPegLabel module loaded successfully", {
  component = "TestScript",
  version = version
})

-- Test basic pattern matching
logger.debug("Testing basic pattern matching", {
  component = "TestScript",
  test = "SimpleGrammar"
})

local lpeg = lpeglabel
local P, V, C, Ct = lpeg.P, lpeg.V, lpeg.C, lpeg.Ct

-- Simple grammar test
local grammar = P{
  "S";
  S = Ct(C(P"a"^1) * P"," * C(P"b"^1))
}

logger.debug("Grammar defined", {
  component = "TestScript",
  grammar_type = "Simple Concatenation"
})

local test_string = "aaa,bbb"
logger.debug("Attempting to match", {
  component = "TestScript",
  input = test_string
})

local result = grammar:match(test_string)
if result then
  logger.info("Grammar test passed", {
    component = "TestScript",
    result = table.concat(result, ", "),
    match_count = #result
  })
else
  logger.error("Grammar test failed", {
    component = "TestScript",
    input = test_string,
    expected = "Capture table with two elements"
  })
end

logger.info("LPegLabel integration test completed", {
  component = "TestScript",
  status = "success",
  tests_run = 1
})
