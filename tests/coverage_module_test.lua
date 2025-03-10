-- Import the test framework
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

-- Add a slightly more complex function
function M.complex_function(a, b, c)
  local result = 0
  
  if a > b then
    if b > c then
      -- a > b > c
      result = a * b - c
    else if a > c then
      -- a > c > b
      result = a * c - b
    else
      -- c > a > b
      result = c * a - b
    end
    end
  else
    if a > c then
      -- b > a > c
      result = b * a - c
    else if b > c then
      -- b > c > a
      result = b * c - a
    else
      -- c > b > a
      result = c * b - a
    end
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
  
  it("should properly initialize", function()
    time("initialize coverage", function()
      coverage.init({
        enabled = true,
        debug = true,
        source_dirs = {".", "lib", "/tmp"},
        use_static_analysis = true,
        pre_analyze_files = false, -- Disable pre-analysis which could be slow
        cache_parsed_files = true
      })
    end)
    
    expect(coverage).to.be.a("table")
  end)
  
  it("should track code execution", function()
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
    
    -- Print debug info to understand what's in the file
    print("File data: " .. normalized_path)
    for k, v in pairs(data.files[normalized_path]) do
      print("  " .. k .. ": " .. (type(v) == "table" and "table" or tostring(v)))
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
    coverage.init({ enabled = true })
    
    -- Start coverage tracking
    coverage.start()
    
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
    
    -- Print debug info to understand what's in the file
    print("File data after patchup: " .. normalized_path)
    for k, v in pairs(data.files[normalized_path]) do
      print("  " .. k .. ": " .. (type(v) == "table" and "table" or tostring(v)))
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
    coverage.init({ enabled = true, threshold = 70 })
    
    -- Start coverage tracking
    coverage.start()
    
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
    
    -- Print debug info for summary
    print("Summary data:")
    for k, v in pairs(data.summary) do
      print("  " .. k .. ": " .. tostring(v))
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
  
  -- Cleanup
  cleanup()
end)