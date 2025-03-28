-- Data store for coverage information
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local central_config = require("lib.core.central_config")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.runtime.data_store")

---@class coverage_v3_runtime_data_store
---@field record_execution fun(file: string, line: number): boolean Record line execution
---@field record_coverage fun(file: string, line: number): boolean Record line coverage
---@field get_line_state fun(file: string, line: number): string Get line state
---@field get_file_data fun(file: string): table Get file coverage data
---@field reset fun(): boolean Reset all data
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Coverage states
local STATES = {
  NOT_COVERED = "not_covered",
  EXECUTED = "executed",
  COVERED = "covered"
}

-- Store coverage data
local coverage_data = {}

-- Helper to ensure file data exists
local function ensure_file_data(file)
  if not coverage_data[file] then
    coverage_data[file] = {
      executed_lines = {},
      covered_lines = {}
    }
  end
  return coverage_data[file]
end

-- Record line execution
function M.record_execution(file, line)
  local data = ensure_file_data(file)
  data.executed_lines[line] = true
  return true
end

-- Record line coverage
function M.record_coverage(file, line)
  local data = ensure_file_data(file)
  data.covered_lines[line] = true
  return true
end

-- Get line state
function M.get_line_state(file, line)
  local data = coverage_data[file]
  if not data then
    return STATES.NOT_COVERED
  end
  
  if data.covered_lines[line] then
    return STATES.COVERED
  elseif data.executed_lines[line] then
    return STATES.EXECUTED
  else
    return STATES.NOT_COVERED
  end
end

-- Get file coverage data
function M.get_file_data(file)
  return coverage_data[file]
end

-- Reset all data
function M.reset()
  coverage_data = {}
  return true
end

return M