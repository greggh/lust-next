-- Optimized data store for v3 coverage system
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.runtime.optimized_store")

---@class coverage_v3_runtime_optimized_store
---@field reset fun(): boolean Reset all coverage data
---@field record_execution fun(file: string, line: number): boolean Record line execution
---@field record_coverage fun(file: string, line: number): boolean Record line coverage
---@field get_file_data fun(file: string): table|nil Get coverage data for a file
---@field get_line_state fun(file: string, line: number): string Get state of a line ("covered", "executed", "not_covered")
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Coverage data store
local store = {
  files = {}  -- file_path -> { data = { line -> flags }, counts = { line -> count } }
}

-- Coverage flags
local FLAGS = {
  EXECUTED = 1,  -- Line was executed
  COVERED = 2    -- Line was covered by an assertion
}

-- Reset all coverage data
function M.reset()
  logger.debug("Resetting coverage data store")
  store.files = {}
  return true
end

-- Get or create file data
local function get_or_create_file_data(file)
  if not store.files[file] then
    logger.debug("Creating new file data", {
      file = file
    })
    store.files[file] = {
      data = {},    -- line -> flags
      counts = {}   -- line -> count
    }
  end
  return store.files[file]
end

-- Record line execution
function M.record_execution(file, line)
  if not file or not line then
    logger.warn("Invalid file or line", {
      file = file,
      line = line
    })
    return false
  end
  
  local file_data = get_or_create_file_data(file)
  
  -- Initialize flags if needed
  file_data.data[line] = file_data.data[line] or 0
  
  -- Set executed flag
  file_data.data[line] = file_data.data[line] | FLAGS.EXECUTED
  
  -- Increment execution count
  file_data.counts[line] = (file_data.counts[line] or 0) + 1
  
  logger.debug("Recorded line execution", {
    file = file,
    line = line,
    flags = file_data.data[line],
    count = file_data.counts[line]
  })
  
  return true
end

-- Record line coverage
function M.record_coverage(file, line)
  if not file or not line then
    logger.warn("Invalid file or line", {
      file = file,
      line = line
    })
    return false
  end
  
  local file_data = get_or_create_file_data(file)
  
  -- Initialize flags if needed
  file_data.data[line] = file_data.data[line] or 0
  
  -- Set executed and covered flags
  file_data.data[line] = file_data.data[line] | FLAGS.EXECUTED | FLAGS.COVERED
  
  -- Ensure execution count exists
  file_data.counts[line] = file_data.counts[line] or 1
  
  logger.debug("Recorded line coverage", {
    file = file,
    line = line,
    flags = file_data.data[line],
    count = file_data.counts[line]
  })
  
  return true
end

-- Get coverage data for a file
function M.get_file_data(file)
  logger.debug("Getting file data", {
    file = file,
    has_data = store.files[file] ~= nil
  })
  return store.files[file]
end

-- Get state of a line
function M.get_line_state(file, line)
  local file_data = store.files[file]
  if not file_data then
    logger.debug("No data for file", {
      file = file
    })
    return "not_covered"
  end
  
  local flags = file_data.data[line]
  if not flags then
    logger.debug("No flags for line", {
      file = file,
      line = line
    })
    return "not_covered"
  end
  
  if flags & FLAGS.COVERED ~= 0 then
    logger.debug("Line is covered", {
      file = file,
      line = line,
      flags = flags
    })
    return "covered"
  elseif flags & FLAGS.EXECUTED ~= 0 then
    logger.debug("Line is executed", {
      file = file,
      line = line,
      flags = flags
    })
    return "executed"
  else
    logger.debug("Line is not covered", {
      file = file,
      line = line,
      flags = flags
    })
    return "not_covered"
  end
end

return M