-- Test script for lpeglabel integration
package.path = "/home/gregg/Projects/lua-library/lust-next/?.lua;" .. package.path

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

logger.info("Attempting to load lpeglabel module...")
local ok, lpeglabel = pcall(function()
  return require("lib.tools.vendor.lpeglabel")
end)

if not ok then
  logger.error("Failed to load lpeglabel: " .. tostring(lpeglabel))
  os.exit(1)
end

logger.info("LPegLabel loaded successfully!")
logger.info("Version: " .. (type(lpeglabel.version) == "function" and lpeglabel.version() or lpeglabel.version or "unknown"))

logger.info("Testing basic pattern matching...")
local lpeg = lpeglabel
local P, V, C, Ct = lpeg.P, lpeg.V, lpeg.C, lpeg.Ct

-- Simple grammar test
local grammar = P{
  "S";
  S = Ct(C(P"a"^1) * P"," * C(P"b"^1))
}

local result = grammar:match("aaa,bbb")
if result then
  logger.info("Grammar test passed: " .. table.concat(result, ", "))
else
  logger.error("Grammar test failed!")
end

logger.info("LPegLabel integration test completed successfully!")