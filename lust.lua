-- Compatibility layer for lust-next
-- This file allows existing code that requires "lust" to continue working
-- while providing a migration path to lust-next

-- Try to load logging module
local logger
local function try_require(name)
  local ok, mod = pcall(require, name)
  if ok then
    return mod
  else
    return nil
  end
end

local logging = try_require("lib.tools.logging")
if logging then
  logger = logging.get_logger("lust-compat")
  if logger and logger.warn then
    logger.warn("Using compatibility layer", {
      message = "You are using the compatibility layer for lust-next",
      recommendation = "For best results, please update your code to require 'lust-next' instead of 'lust'"
    })
  end
else
  print("\nNOTICE: You are using the compatibility layer for lust-next")
  print("For best results, please update your code to require 'lust-next' instead of 'lust'\n")
end

return require("lust-next")