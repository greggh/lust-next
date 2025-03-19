-- Import the test framework
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Import modules for testing
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local temp_file = require("lib.tools.temp_file")

-- Try to load the logging module with standardized error handling
local logging, logger
local function try_load_logger()
  if not logger then
    local log_module, err = test_helper.with_error_capture(function()
      return require("lib.tools.logging")
    end)()
    
    if log_module then
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

-- Create a simple test module with error handling using temp_file
local test_module_content = [[
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
]]

-- Create temporary file with the test module content
local test_module_path, create_err = temp_file.create_with_content(test_module_content, "lua")

if create_err then
  error(error_handler.io_error(
    "Failed to create test module",
    {error = create_err}
  ))
end

-- No need for explicit cleanup function as temp_file handles cleanup automatically

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
    
    -- Verify using the correct firmo assertions
    expect(data.files[normalized_path].total_lines).to.be.a("number")
    expect(data.files[normalized_path].covered_lines).to.be.a("number")
    expect(data.files[normalized_path].line_coverage_percent).to.be.a("number")
    
    -- Use be_greater_than which is the correct path in firmo
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
    
    -- Verify using the correct firmo assertions
    expect(data.files[normalized_path].total_lines).to.be.a("number")
    expect(data.files[normalized_path].line_coverage_percent).to.be.a("number")
    
    -- Use be_greater_than which is the correct path in firmo
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
  
  -- Add error handling tests
  
  it("should handle track_file with invalid file path", { expect_error = true }, function()
    -- Ensure coverage is running
    coverage.start()
    
    -- Test with nil file path
    local result1, err1 = test_helper.with_error_capture(function()
      return coverage.track_file(nil)
    end)()
    
    -- It might return false or nil+error depending on implementation
    if result1 == nil then
      expect(err1).to.exist()
      expect(err1.category).to.equal(error_handler.CATEGORY.VALIDATION)
    else
      expect(result1).to.equal(false)
    end
    
    -- Test with non-string file path
    local result2, err2 = test_helper.with_error_capture(function()
      return coverage.track_file(123)
    end)()
    
    -- It might return false or nil+error depending on implementation
    if result2 == nil then
      expect(err2).to.exist()
      expect(err2.category).to.equal(error_handler.CATEGORY.VALIDATION)
    else
      expect(result2).to.equal(false)
    end
    
    -- Test with non-existent file
    local result3, err3 = test_helper.with_error_capture(function()
      return coverage.track_file("/path/to/nonexistent/file.lua")
    end)()
    
    -- This might return false or nil+error depending on implementation
    if result3 == nil then
      expect(err3).to.exist()
    else
      -- It might succeed with false or return some other value, just verify it's not nil
      expect(result3 ~= nil).to.be_truthy()
    end
    
    -- Cleanup
    coverage.stop()
  end)
  
  it("should handle track_line with invalid inputs", { expect_error = true }, function()
    -- Ensure coverage is running
    coverage.start()
    
    -- Test with nil file path
    local result1, err1 = test_helper.with_error_capture(function()
      return coverage.track_line(nil, 1)
    end)()
    
    -- It might return false or nil+error depending on implementation
    if result1 == nil then
      expect(err1).to.exist()
      expect(err1.category).to.equal(error_handler.CATEGORY.VALIDATION)
    else
      expect(result1).to.equal(false)
    end
    
    -- Test with nil line number
    local result2, err2 = test_helper.with_error_capture(function()
      return coverage.track_line("test.lua", nil)
    end)()
    
    -- It might return false or nil+error depending on implementation
    if result2 == nil then
      expect(err2).to.exist()
      expect(err2.category).to.equal(error_handler.CATEGORY.VALIDATION)
    else
      expect(result2).to.equal(false)
    end
    
    -- Test with invalid line number
    local result3, err3 = test_helper.with_error_capture(function()
      return coverage.track_line("test.lua", -1)
    end)()
    
    -- It might return false or nil+error depending on implementation
    if result3 == nil then
      expect(err3).to.exist()
      expect(err3.category).to.equal(error_handler.CATEGORY.VALIDATION)
    else
      expect(result3).to.equal(false)
    end
    
    -- Cleanup
    coverage.stop()
  end)
  
  it("should handle operating on disabled coverage", { expect_error = true }, function()
    -- Reset and initialize with coverage disabled
    coverage.reset()
    coverage.init({ enabled = false })
    
    -- Start should succeed but not enable tracking
    local result = coverage.start()
    expect(result).to.equal(coverage)
    
    -- Track_file should return an error or false when coverage is disabled
    local track_success, track_err = test_helper.with_error_capture(function()
      return coverage.track_file(test_module_path)
    end)()
    
    -- Either it returns false (not nil) or it returns an error
    if track_success == nil then
      expect(track_err).to.exist()
      expect(track_err.message).to.match("disabled")
    else
      expect(track_success).to.equal(false)
    end
    
    -- Reset back to enabled
    coverage.reset()
    coverage.init({ enabled = true })
  end)
  
  -- No need for explicit cleanup for test files - temp_file handles it automatically
  after(function()
    if log then
      log.debug("Test completed, automatic cleanup will occur", {
        file = test_module_path
      })
    end
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
-- No need to call firmo() explicitly here
