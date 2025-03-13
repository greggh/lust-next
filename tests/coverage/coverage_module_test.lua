-- Import the test framework
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
      logger = logging.get_logger("test.coverage_module")
      
      if logger and logger.debug then
        logger.debug("Coverage module test initialized", {
          module = "test.coverage_module",
          test_type = "unit",
          test_focus = "coverage API"
        })
      end
    end
  end
  return logger
end

-- Initialize logger
local log = try_load_logger()

-- Add simple profiling
local function time(name, fn)
  local start = os.clock()
  local result = fn()
  local elapsed = os.clock() - start
  
  if log then
    log.info("Profiling information", {
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

-- Add a slightly more complex function
function M.complex_function(a, b, c)
  local result = 0
  
  if a > b then
    if b > c then
      -- a > b > c
      result = a * b - c
    elseif a > c then
      -- a > c > b
      result = a * c - b
    else
      -- c > a > b
      result = c * a - b
    end
  else
    if a > c then
      -- b > a > c
      result = b * a - c
    elseif b > c then
      -- b > c > a
      result = b * c - a
    else
      -- c > b > a
      result = c * b - a
    end
  end
  
  return result
end

return M
]])

-- Clean up function to run after tests
local function cleanup()
  os.remove(test_module_path)
end

describe("Coverage Module", function()
  if log then
    log.info("Beginning coverage module tests", {
      test_group = "coverage",
      test_focus = "API and functionality"
    })
  end
  
  it("should properly initialize", function()
    -- Configure central_config first with coverage settings
    central_config.set("coverage", {
      enabled = true,
      debug = true,
      source_dirs = {".", "lib", "/tmp"},
      use_static_analysis = true,
      pre_analyze_files = false, -- Disable pre-analysis which could be slow
      cache_parsed_files = true
    })
    
    time("initialize coverage", function()
      -- Now init will get settings from central_config
      coverage.init()
    end)
    
    expect(coverage).to.be.a("table")
  end)
  
  it("should track code execution", function()
    -- Start coverage tracking
    time("start coverage", function()
      coverage.start()
    end)
    
    -- Explicitly track our test module file
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
    
    -- Log debug info to understand what's in the file
    if log then
      log.debug("File data", {
        path = normalized_path,
        keys = table.concat(
          (function()
            local keys = {}
            for k, _ in pairs(data.files[normalized_path]) do
              table.insert(keys, k)
            end
            return keys
          end)(), 
          ", "
        )
      })
    end
    
    -- Verify using the correct lust-next assertions
    expect(data.files[normalized_path].total_lines).to.be.a("number")
    expect(data.files[normalized_path].covered_lines).to.be.a("number")
    expect(data.files[normalized_path].line_coverage_percent).to.be.a("number")
    
    -- Use be_greater_than which is the correct path in lust-next
    expect(data.files[normalized_path].total_lines).to.be_greater_than(0)
    expect(data.files[normalized_path].covered_lines).to.be_greater_than(0)
    
    -- For less than, we can check the inverse with not equal 
    expect(data.files[normalized_path].line_coverage_percent).to_not.equal(100)
  end)
  
  it("should handle patchup for non-executable lines", function()
    -- Reset coverage data
    coverage.full_reset()
    
    -- Configure central_config for the test
    central_config.set("coverage", { enabled = true })
    
    -- Initialize coverage again with new settings
    coverage.init()
    
    -- Start coverage tracking
    coverage.start()
    
    -- Explicitly track our test module file
    coverage.track_file(test_module_path)
    
    -- Load and run our test module again
    local test_module = dofile(test_module_path)
    test_module.add(2, 3)
    
    -- Stop coverage tracking (this will run the patchup)
    coverage.stop()
    
    -- Get coverage report data
    local data = coverage.get_report_data()
    
    -- Normalize path for comparison
    local normalized_path = fs.normalize_path(test_module_path)
    
    -- Verify file was tracked
    expect(data.files[normalized_path]).to.be.a("table")
    
    -- Log debug info
    if log then
      log.debug("File data after patchup", {
        path = normalized_path,
        keys = table.concat(
          (function()
            local keys = {}
            for k, _ in pairs(data.files[normalized_path]) do
              table.insert(keys, k)
            end
            return keys
          end)(), 
          ", "
        )
      })
    end
    
    -- Verify using the correct lust-next assertions
    expect(data.files[normalized_path].total_lines).to.be.a("number")
    expect(data.files[normalized_path].line_coverage_percent).to.be.a("number")
    
    -- Use be_greater_than which is the correct path in lust-next
    expect(data.files[normalized_path].total_lines).to.be_greater_than(0)
    expect(data.files[normalized_path].line_coverage_percent).to.be_greater_than(0)
  end)
  
  it("should generate report data correctly", function()
    -- Reset coverage data
    coverage.full_reset()
    
    -- Configure central_config for the test
    central_config.set("coverage", { 
      enabled = true, 
      threshold = 70 
    })
    
    -- Initialize coverage again with new settings
    coverage.init()
    
    -- Start coverage tracking
    coverage.start()
    
    -- Explicitly track our test module file
    coverage.track_file(test_module_path)
    
    -- Load and run our test module, executing all code paths
    local test_module = dofile(test_module_path)
    test_module.add(1, 2)
    test_module.subtract(5, 3)
    test_module.conditional_func(15)  -- "greater" branch
    test_module.conditional_func(5)   -- "lesser" branch
    
    -- Stop coverage tracking
    coverage.stop()
    
    -- Get coverage report data
    local data = coverage.get_report_data()
    
    -- Log debug info for summary
    if log then
      log.debug("Summary data", {
        total_files = data.summary.total_files,
        covered_files = data.summary.covered_files,
        total_lines = data.summary.total_lines,
        covered_lines = data.summary.covered_lines,
        line_coverage_percent = data.summary.line_coverage_percent,
        file_coverage_percent = data.summary.file_coverage_percent
      })
    end
    
    -- Check summary data
    expect(data.summary).to.be.a("table")
    
    expect(data.summary.total_files).to.be.a("number")
    expect(data.summary.total_files).to.be_greater_than(0)
    
    expect(data.summary.covered_files).to.be.a("number")
    expect(data.summary.covered_files).to.be_greater_than(0)
    
    expect(data.summary.total_lines).to.be.a("number")
    expect(data.summary.total_lines).to.be_greater_than(0)
    
    expect(data.summary.covered_lines).to.be.a("number")
    expect(data.summary.covered_lines).to.be_greater_than(0)
    
    expect(data.summary.line_coverage_percent).to.be.a("number")
    expect(data.summary.file_coverage_percent).to.be.a("number")
  end)
  
  -- Run cleanup for all tests
  after(function()
    if log then
      log.debug("Running test cleanup", {
        file = test_module_path
      })
    end
    
    cleanup()
  end)
end)

-- Log completion message outside of the test suite
if log then
  log.info("Coverage module tests completed", {
    status = "success",
    test_group = "coverage"
  })
end

-- Tests are run by run_all_tests.lua or scripts/runner.lua
-- No need to call lust() explicitly here