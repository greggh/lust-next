-- Test for coverage tracking on larger files
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect

-- Import modules for testing
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")

describe("Large File Coverage", function()
  
  it("should track coverage on the largest file in the project", function()
    -- Initialize coverage with optimized settings
    coverage.init({
      enabled = true,
      debug = false,
      source_dirs = {"/home/gregg/Projects/lua-library/lust-next"},
      use_static_analysis = true,
      cache_parsed_files = true,
      pre_analyze_files = false
    })
    
    local file_path = "/home/gregg/Projects/lua-library/lust-next/lust-next.lua"
    
    -- Start timing
    local start_time = os.clock()
    
    -- Start coverage tracking
    coverage.start()
    
    -- Simply require the file to execute it
    local lust_next_module = require("lust-next")
    
    -- Stop coverage tracking
    coverage.stop()
    
    -- Get report data
    local data = coverage.get_report_data()
    
    -- Calculate duration
    local duration = os.clock() - start_time
    print(string.format("Coverage tracking completed in %.2f seconds", duration))
    
    -- Get normalized path
    local normalized_path = fs.normalize_path(file_path)
    
    -- Verify file was tracked
    expect(data.files[normalized_path]).to.be.a("table")
    
    -- Print coverage stats
    local file_data = data.files[normalized_path]
    if file_data then
      print(string.format("File: %s", normalized_path))
      print(string.format("  Total lines: %d", file_data.total_lines or 0))
      print(string.format("  Covered lines: %d", file_data.covered_lines or 0))
      print(string.format("  Coverage: %.2f%%", file_data.line_coverage_percent or 0))
      print(string.format("  Total functions: %d", file_data.total_functions or 0))
      print(string.format("  Covered functions: %d", file_data.covered_functions or 0))
    end
  end)
  
end)