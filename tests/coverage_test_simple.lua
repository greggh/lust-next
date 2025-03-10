-- Simple focused test for the coverage module
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect

-- Import modules for testing
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")

-- Add simple profiling
local function time(name, fn)
  local start = os.clock()
  local result = fn()
  local elapsed = os.clock() - start
  print(string.format("[PROFILE] %s took %.4f seconds", name, elapsed))
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
  
  it("should track code execution with performance stats", function()
    -- Initialize coverage with performance profiling
    time("initialize coverage", function()
      coverage.init({
        enabled = true,
        debug = false, -- Disable debug output
        source_dirs = {"/tmp"},
        use_static_analysis = true, -- Re-enable now that we've fixed the bugs
        cache_parsed_files = true,
        pre_analyze_files = false
      })
    end)
    
    -- Start coverage tracking
    time("start coverage", function()
      coverage.start()
    end)
    
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
    
    -- Print debug info
    print("Function data for " .. normalized_path .. ":")
    for key, func_data in pairs(data.files[normalized_path].functions) do
      print(string.format("  [%s] line: %d, executed: %s, calls: %s", 
        func_data.name, func_data.line, 
        tostring(func_data.executed), tostring(func_data.calls or 0)))
    end
    
    print("Coverage stats:")
    print(string.format("  Line coverage: %.2f%%", data.files[normalized_path].line_coverage_percent))
    print(string.format("  Function coverage: %.2f%%", data.files[normalized_path].function_coverage_percent))
    
    -- Basic assertions
    expect(data.files[normalized_path].total_lines).to.be_greater_than(0)
    expect(data.files[normalized_path].covered_lines).to.be_greater_than(0)
    expect(data.files[normalized_path].line_coverage_percent).to.be_greater_than(0)
  end)
  
  -- Cleanup
  cleanup()
end)