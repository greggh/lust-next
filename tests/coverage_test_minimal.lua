-- Minimal test for coverage module
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect

-- Import modules for testing
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")

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
  
  it("should track basic code execution", function()
    -- Initialize with static analysis enabled
    coverage.init({
      enabled = true,
      debug = false,
      source_dirs = {"/tmp"},
      use_static_analysis = true,
      cache_parsed_files = true,
      pre_analyze_files = false
    })
    
    -- Start coverage tracking
    coverage.start()
    
    -- Load and run our test module
    dofile(test_module_path)
    
    -- Stop coverage tracking
    coverage.stop()
    
    -- Get coverage report data
    local data = coverage.get_report_data()
    
    -- Normalize path for comparison
    local normalized_path = fs.normalize_path(test_module_path)
    
    -- Verify file was tracked
    expect(data.files[normalized_path]).to.be.a("table")
    
    -- Basic assertions
    expect(data.files[normalized_path].total_lines).to.be_greater_than(0)
    expect(data.files[normalized_path].covered_lines).to.be_greater_than(0)
  end)
  
  -- Cleanup
  cleanup()
end)