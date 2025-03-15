-- Test for coverage tracking on larger files
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import modules for testing
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("test.large_file_coverage")

describe("Large File Coverage", function()
  
  it("should track coverage on the largest file in the project", function()
    -- Get project root directory (current directory for the test)
    local project_root = fs.get_absolute_path(".")
    
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
    
    -- Start timing
    local start_time = os.clock()
    
    -- Start coverage tracking
    coverage.start()
    
    -- Explicitly track the file
    coverage.track_file(file_path)
    
    -- Simply require the file to execute it
    local firmo_module = require("firmo")
    
    -- Stop coverage tracking
    coverage.stop()
    
    -- Get report data
    local data = coverage.get_report_data()
    
    -- Calculate duration
    local duration = os.clock() - start_time
    logger.info("Coverage tracking completed", {
      duration_seconds = string.format("%.2f", duration)
    })
    
    -- Get normalized path
    local normalized_path = fs.normalize_path(file_path)
    
    -- Verify file was tracked
    expect(data.files[normalized_path]).to.be.a("table")
    
    -- Log coverage stats
    local file_data = data.files[normalized_path]
    if file_data then
      logger.info("Coverage statistics", {
        file = normalized_path,
        total_lines = file_data.total_lines or 0,
        covered_lines = file_data.covered_lines or 0,
        coverage_percent = string.format("%.2f", file_data.line_coverage_percent or 0),
        total_functions = file_data.total_functions or 0,
        covered_functions = file_data.covered_functions or 0
      })
    end
  end)
  
end)
