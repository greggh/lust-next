-- Simple focused test for the coverage module
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import modules for testing
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")

-- Try to load the logging module
local logging, logger
local function try_load_logger()
  if not logger then
    local ok, log_module = pcall(require, "lib.tools.logging")
    if ok and log_module then
      logging = log_module
      logger = logging.get_logger("test.coverage_simple")
      
      if logger and logger.debug then
        logger.debug("Coverage simple test initialized", {
          module = "test.coverage_simple",
          test_type = "unit",
          test_focus = "coverage tracking with performance"
        })
      end
    end
  end
  return logger
end

-- Initialize logger
local log = try_load_logger()

-- Add simple profiling with logging
local function time(name, fn)
  local start = os.clock()
  local result = fn()
  local elapsed = os.clock() - start
  
  if log then
    log.info("Performance measurement", {
      operation = name,
      elapsed_seconds = elapsed
    })
  else
    print(string.format("[PROFILE] %s took %.4f seconds", name, elapsed))
  end
  
  return result
end

-- Create a simple test module
local test_module_path = os.tmpname() .. ".lua"
fs.write_file(test_module_path, [[
local M = {}

function M.add(a, b)
  return a + b
end

function M.subtract(a, b)
  return a - b
end

function M.conditional_func(value)
  if value > 10 then
    return "greater"
  else
    return "lesser"
  end
end

return M
]])

-- Clean up function to run after tests
local function cleanup()
  os.remove(test_module_path)
end

describe("Coverage Module Simple Test", function()
  if log then
    log.info("Beginning simple coverage tests", {
      test_group = "coverage_simple",
      test_focus = "performance tracking"
    })
  end
  
  -- Run cleanup after each test
  after(function()
    if log then
      log.debug("Running test cleanup", {
        file = test_module_path
      })
    end
    
    cleanup()
  end)
  
  it("should track code execution with performance stats", function()
    -- Configure central_config first with coverage settings
    central_config.set("coverage", {
      enabled = true,
      debug = false, -- Disable debug output
      source_dirs = {"/tmp"},
      use_static_analysis = true, -- Re-enable now that we've fixed the bugs
      cache_parsed_files = true,
      pre_analyze_files = false
    })
    
    -- Initialize coverage with settings from central_config
    time("initialize coverage", function()
      coverage.init()
    end)
    
    -- Start coverage tracking
    time("start coverage", function()
      coverage.start()
    end)
    
    -- Explicitly track the test module file
    coverage.track_file(test_module_path)
    
    -- Load and run our test module
    local test_module
    time("load and execute test module", function()
      test_module = dofile(test_module_path)
      test_module.add(5, 10)
      test_module.subtract(20, 5)
      test_module.conditional_func(15)  -- Only execute the "greater" branch
    end)
    
    -- Stop coverage tracking
    time("stop coverage", function()
      coverage.stop()
    end)
    
    -- Get coverage report data
    local data
    time("get report data", function()
      data = coverage.get_report_data()
    end)
    
    -- Normalize path for comparison
    local normalized_path = fs.normalize_path(test_module_path)
    
    -- Verify file was tracked
    expect(data.files[normalized_path]).to.be.a("table")
    
    -- Log function data
    if log then
      local function_summary = {}
      for key, func_data in pairs(data.files[normalized_path].functions) do
        table.insert(function_summary, {
          name = func_data.name,
          line = func_data.line,
          executed = func_data.executed,
          calls = func_data.calls or 0
        })
      end
      
      log.debug("Function coverage data", {
        file = normalized_path,
        functions = function_summary
      })
      
      log.debug("Coverage statistics", {
        line_coverage_percent = data.files[normalized_path].line_coverage_percent,
        function_coverage_percent = data.files[normalized_path].function_coverage_percent
      })
    end
    
    -- Basic assertions
    expect(data.files[normalized_path].total_lines).to.be_greater_than(0)
    expect(data.files[normalized_path].covered_lines).to.be_greater_than(0)
    expect(data.files[normalized_path].line_coverage_percent).to.be_greater_than(0)
  end)
  
  if log then
    log.info("Simple coverage tests completed", {
      status = "success",
      test_group = "coverage_simple"
    })
  end
end)

-- Tests are run by run_all_tests.lua or scripts/runner.lua
-- No need to call firmo() explicitly here
