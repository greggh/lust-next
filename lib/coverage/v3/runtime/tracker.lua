-- V3 Coverage Runtime Tracker
-- Provides runtime tracking functions for instrumented code

local data_store = require("lib.coverage.v3.runtime.data_store")
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.tracker")

local M = {
  _VERSION = "3.0.0"
}

-- Track function entry
function M.__firmo_v3_track_function_entry(filename, line)
  data_store.track_line(filename, line)
  
  logger.debug("Tracked function entry", {
    filename = filename,
    line = line
  })
end

-- Track line execution
function M.__firmo_v3_track_line(filename, line)
  data_store.track_line(filename, line)
  
  logger.debug("Tracked line execution", {
    filename = filename,
    line = line
  })
end

-- Track an assertion
function M.__firmo_v3_track_assertion(filename, line)
  data_store.start_assertion(filename, line)
  
  logger.debug("Started assertion tracking", {
    filename = filename,
    line = line
  })
  
  -- Return cleanup function
  return function()
    data_store.end_assertion()
    logger.debug("Ended assertion tracking")
  end
end

-- Reset tracking
function M.reset()
  data_store.reset()
  logger.debug("Reset tracking")
end

return M