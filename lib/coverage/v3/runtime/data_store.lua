-- V3 Coverage Data Store
-- Stores coverage data during test execution

local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.data_store")

local M = {
  _VERSION = "3.0.0"
}

-- Coverage data structure
local coverage_data = {
  files = {},
  assertions = {},
  current_assertion = nil,
  current_lines = {}
}

-- Track a line execution
function M.track_line(filename, line)
  coverage_data.files[filename] = coverage_data.files[filename] or {
    executed_lines = {},
    covered_lines = {}
  }
  
  -- Record line execution
  coverage_data.files[filename].executed_lines[line] = true
  
  -- If we're in an assertion context, mark as covered
  if coverage_data.current_assertion then
    coverage_data.files[filename].covered_lines[line] = true
    coverage_data.current_lines[line] = true
  end
  
  logger.debug("Tracked line execution", {
    filename = filename,
    line = line,
    in_assertion = coverage_data.current_assertion ~= nil
  })
end

-- Start tracking an assertion
function M.start_assertion(filename, line)
  coverage_data.current_assertion = {
    file = filename,
    line = line,
    covered_lines = {}
  }
  coverage_data.current_lines = {}
  table.insert(coverage_data.assertions, coverage_data.current_assertion)
  
  logger.debug("Started assertion tracking", {
    filename = filename,
    line = line
  })
end

-- End tracking the current assertion
function M.end_assertion()
  if coverage_data.current_assertion then
    -- Add covered lines to assertion
    for line in pairs(coverage_data.current_lines) do
      table.insert(coverage_data.current_assertion.covered_lines, {
        line = line
      })
    end
    
    logger.debug("Ended assertion tracking", {
      covered_lines = #coverage_data.current_assertion.covered_lines
    })
  end
  
  coverage_data.current_assertion = nil
  coverage_data.current_lines = {}
end

-- Get assertion mappings for a file
function M.get_assertion_mappings(filename)
  local mappings = {}
  for _, assertion in ipairs(coverage_data.assertions) do
    if assertion.file == filename then
      table.insert(mappings, assertion)
    end
  end
  
  logger.debug("Got assertion mappings", {
    filename = filename,
    count = #mappings
  })
  
  return mappings
end

-- Reset all coverage data
function M.reset()
  coverage_data = {
    files = {},
    assertions = {},
    current_assertion = nil,
    current_lines = {}
  }
  logger.debug("Reset coverage data")
end

return M