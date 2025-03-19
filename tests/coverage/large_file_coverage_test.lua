-- Test for coverage tracking on larger files
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Import modules for testing
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")

-- Try to load the logging module with standardized error handling
local logging, logger
local function try_load_logger()
  if not logger then
    local log_module, err = test_helper.with_error_capture(function()
      return require("lib.tools.logging")
    end)()
    
    if log_module then
      logging = log_module
      logger = logging.get_logger("test.large_file_coverage")
      
      if logger and logger.debug then
        logger.debug("Large file coverage test initialized", {
          module = "test.large_file_coverage",
          test_type = "unit",
          test_focus = "large file tracking"
        })
      end
    end
  end
  return logger
end

-- Initialize logger
local log = try_load_logger()

describe("Large File Coverage", function()
  -- Reset coverage before each test
  before(function()
    coverage.reset()
  end)
  
  it("should track coverage on the largest file in the project", function()
    -- Get project root directory (current directory for the test) with error handling
    local project_root, fs_err = test_helper.with_error_capture(function()
      return fs.get_absolute_path(".")
    end)()
    
    expect(project_root).to.exist()
    expect(fs_err).to_not.exist()
    
    -- Initialize coverage with optimized settings
    coverage.init({
      enabled = true,
      debug = false,
      source_dirs = {project_root},
      use_static_analysis = true,
      cache_parsed_files = true,
      pre_analyze_files = false
    })
    
    local file_path = fs.join_paths(project_root, "firmo.lua")
    
    -- Verify file exists before attempting to track it
    local file_exists, file_err = test_helper.with_error_capture(function()
      return fs.file_exists(file_path)
    end)()
    
    expect(file_exists).to.be_truthy()
    expect(file_err).to_not.exist()
    
    -- Start timing
    local start_time = os.clock()
    
    -- Start coverage tracking
    coverage.start()
    
    -- Explicitly track the file with error handling
    local track_result, track_err = test_helper.with_error_capture(function()
      return coverage.track_file(file_path)
    end)()
    
    expect(track_err).to_not.exist()
    
    -- Simply require the file to execute it
    local firmo_module = require("firmo")
    
    -- Stop coverage tracking
    coverage.stop()
    
    -- Get report data with error handling
    local data, report_err = test_helper.with_error_capture(function()
      return coverage.get_report_data()
    end)()
    
    expect(data).to.exist()
    expect(report_err).to_not.exist()
    
    -- Calculate duration
    local duration = os.clock() - start_time
    if log then
      log.info("Coverage tracking completed", {
        duration_seconds = string.format("%.2f", duration)
      })
    end
    
    -- Get normalized path with error handling
    local normalized_path, norm_err = test_helper.with_error_capture(function()
      return fs.normalize_path(file_path)
    end)()
    
    expect(normalized_path).to.exist()
    expect(norm_err).to_not.exist()
    
    -- Verify file was tracked
    expect(data.files[normalized_path]).to.be.a("table")
    
    -- Log coverage stats
    local file_data = data.files[normalized_path]
    if file_data and log then
      log.info("Coverage statistics", {
        file = normalized_path,
        total_lines = file_data.total_lines or 0,
        covered_lines = file_data.covered_lines or 0,
        coverage_percent = string.format("%.2f", file_data.line_coverage_percent or 0),
        total_functions = file_data.total_functions or 0,
        covered_functions = file_data.covered_functions or 0
      })
    end
  end)
  
  it("should handle non-existent file gracefully", { expect_error = true }, function()
    -- Start coverage tracking
    coverage.start()
    
    -- Try to track a non-existent file
    local result, err = test_helper.with_error_capture(function()
      return coverage.track_file("/path/to/nonexistent/file.lua")
    end)()
    
    -- It's acceptable to either:
    -- 1. Return nil, error object
    -- 2. Return false (operation failed but not a critical error)
    if result == nil then
      expect(err).to.exist()
      expect(err.category).to.exist()
      expect(err.message).to.match("exist") -- Should mention file doesn't exist
    else
      expect(result).to.equal(false) -- Should return false to indicate failure
    end
    
    -- Stop coverage
    coverage.stop()
  end)
  
  it("should handle extremely large files with reasonable memory usage", function()
    -- Start coverage with memory limits enabled
    coverage.init({
      enabled = true,
      memory_limit = true,
      debug = false
    })
    
    coverage.start()
    
    -- For this test, we don't actually need to create a massive file
    -- Instead, we can verify the memory limit protection behavior
    
    local before_memory = collectgarbage("count")
    
    -- Use a reasonable file in the project as a proxy
    local file_path = fs.join_paths(fs.get_absolute_path("."), "firmo.lua")
    coverage.track_file(file_path)
    
    -- Force garbage collection to get accurate memory usage
    collectgarbage("collect")
    local after_memory = collectgarbage("count")
    
    -- Expected limited memory growth (should be less than 5MB)
    local memory_growth_kb = after_memory - before_memory
    if log then
      log.info("Memory usage for large file coverage", {
        before_kb = math.floor(before_memory), 
        after_kb = math.floor(after_memory),
        growth_kb = math.floor(memory_growth_kb)
      })
    end
    
    -- Memory growth should be reasonable (adjust threshold based on actual values seen)
    expect(memory_growth_kb).to.be_less_than(5000) -- Less than 5MB
    
    coverage.stop()
  end)
  
  -- Cleanup after tests
  after(function()
    coverage.reset()
  end)
end)
