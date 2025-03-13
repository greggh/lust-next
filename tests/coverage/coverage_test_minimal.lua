-- Minimal test for coverage module
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local before, after = lust.before, lust.after

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
      logger = logging.get_logger("test.coverage_minimal")
      
      if logger and logger.debug then
        logger.debug("Coverage minimal test initialized", {
          module = "test.coverage_minimal",
          test_type = "unit",
          test_focus = "minimal coverage tracking"
        })
      end
    end
  end
  return logger
end

-- Initialize logger
local log = try_load_logger()

-- Create an extremely simple test module
local test_module_path = os.tmpname() .. ".lua"
fs.write_file(test_module_path, [[
local function add(a, b)
  return a + b
end

local function subtract(a, b)
  return a - b
end

print(add(5, 3))
print(subtract(10, 4))
]])

-- Clean up function to run after tests
local function cleanup()
  os.remove(test_module_path)
end

describe("Coverage Module Minimal Test", function()
  if log then
    log.info("Beginning minimal coverage tests", {
      test_group = "coverage_minimal",
      test_focus = "basic execution tracking"
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
  
  it("should track basic code execution", function()
    -- Configure central_config first with coverage settings
    central_config.set("coverage", {
      enabled = true,
      debug = false,
      source_dirs = {"/tmp"},
      use_static_analysis = true,
      cache_parsed_files = true,
      pre_analyze_files = false
    })
    
    -- Initialize coverage with settings from central_config
    coverage.init()
    
    if log then
      log.debug("Starting coverage tracking", {
        test = "basic code execution",
        mode = "static analysis"
      })
    end
    
    -- Start coverage tracking
    coverage.start()
    
    -- Explicitly track the test module file
    coverage.track_file(test_module_path)
    
    -- Load and run our test module
    dofile(test_module_path)
    
    -- Stop coverage tracking
    coverage.stop()
    
    -- Get coverage report data
    local data = coverage.get_report_data()
    
    -- Normalize path for comparison
    local normalized_path = fs.normalize_path(test_module_path)
    
    -- Verify file was tracked
    if log then
      log.debug("Coverage data received", {
        tracked_file = normalized_path,
        has_data = data.files[normalized_path] ~= nil
      })
    end
    
    expect(data.files[normalized_path]).to.be.a("table")
    
    -- Basic assertions
    expect(data.files[normalized_path].total_lines).to.be_greater_than(0)
    expect(data.files[normalized_path].covered_lines).to.be_greater_than(0)
    
    if log then
      log.debug("Coverage results verified", {
        total_lines = data.files[normalized_path].total_lines,
        covered_lines = data.files[normalized_path].covered_lines
      })
    end
  end)
  
  if log then
    log.info("Minimal coverage tests completed", {
      status = "success",
      test_group = "coverage_minimal"
    })
  end
end)

-- Tests are run by run_all_tests.lua or scripts/runner.lua
-- No need to call lust() explicitly here