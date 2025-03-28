-- Runtime tracking for instrumented code
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local central_config = require("lib.core.central_config")
local data_store = require("lib.coverage.v3.runtime.data_store")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.runtime.tracker")

---@class coverage_v3_runtime_tracker
---@field track fun(line: number, type: string): boolean Track code execution
---@field start fun(): boolean Start tracking
---@field stop fun(): boolean Stop tracking
---@field reset fun(): boolean Reset tracking data
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Track whether tracking is active
local is_active = false

-- Track code execution
function M.track(line, type)
  if not is_active then
    return false
  end
  
  -- Get current file
  local info = debug.getinfo(2, "S")
  if not info or not info.source or info.source:sub(1,1) ~= "@" then
    return false
  end
  
  local file = info.source:sub(2)
  
  -- Record execution
  data_store.record_execution(file, line)
  
  -- Record coverage based on type
  if type == "assertion" then
    data_store.record_coverage(file, line)
  end
  
  return true
end

-- Start tracking
function M.start()
  is_active = true
  logger.debug("Started coverage tracking")
  return true
end

-- Stop tracking
function M.stop()
  is_active = false
  logger.debug("Stopped coverage tracking")
  return true
end

-- Reset tracking data
function M.reset()
  data_store.reset()
  logger.debug("Reset coverage tracking data")
  return true
end

return M