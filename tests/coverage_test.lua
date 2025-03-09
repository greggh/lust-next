-- Coverage Module Tests

local lust = require("lust-next")
local expect, describe, it, before, after = lust.expect, lust.describe, lust.it, lust.before, lust.after

describe("Coverage Module", function()
  local fs = require("lib.tools.filesystem")
  local coverage_module = require("lib.coverage")
  local temp_dir = "/tmp/coverage-test-" .. os.time()
  local test_file_path = fs.join_paths(temp_dir, "test_file.lua")
  local test_content = [[
local test_module = {}

function test_module.add(a, b)
  return a + b
end

function test_module.subtract(a, b)
  return a - b
end

function test_module.multiply(a, b)
  return a * b
end

function test_module.divide(a, b)
  if b == 0 then
    error("Division by zero")
  end
  return a / b
end

-- This function won't be called in our tests
function test_module.unused_function(x)
  return x * x
end

return test_module
]]

  before(function()
    fs.create_directory(temp_dir)
    fs.write_file(test_file_path, test_content)
    
    -- Initialize coverage with just our test file
    coverage_module.init({
      enabled = true,
      source_dirs = {temp_dir},
      exclude = {},
      include = {test_file_path}, -- Only include our specific test file
      use_default_patterns = false, -- Don't use default patterns
      debug = true,  -- Enable debug to see what's happening
      discover_uncovered = true
    })
  end)
  
  after(function()
    -- Stop coverage and reset
    coverage_module.stop()
    coverage_module.reset()
    
    -- Clean up test files
    if fs.file_exists(test_file_path) then
      fs.delete_file(test_file_path)
    end
    if fs.directory_exists(temp_dir) then
      fs.delete_directory(temp_dir)
    end
  end)
  
  it("should track line execution", function()
    -- Start coverage
    coverage_module.start()
    
    -- Load our test module
    local test_module = dofile(test_file_path)
    
    -- Call some functions
    test_module.add(1, 2)
    test_module.subtract(5, 3)
    test_module.multiply(2, 3)
    
    -- Calculate stats
    coverage_module.calculate_stats()
    
    -- Get report data
    local report_data = coverage_module.get_report_data()
    
    -- Check that our file was tracked
    expect(report_data.files[test_file_path]).to.exist()
    
    -- Check that we have some coverage but not 100%
    local file_stats = report_data.files[test_file_path]
    expect(file_stats.covered_lines).to.be.greater_than(0)
    expect(file_stats.covered_lines).to.be.less_than(file_stats.total_lines)
    
    -- The division and unused functions should not be covered
    expect(report_data.summary.line_coverage_percent).to.be.less_than(100)
  end)

  it("should detect files with 0% coverage", function()
    -- Create another file that won't be executed
    local zero_coverage_file = fs.join_paths(temp_dir, "zero_coverage.lua")
    fs.write_file(zero_coverage_file, [[
local unused_module = {}

function unused_module.func1()
  return "unused"
end

function unused_module.func2()
  return "also unused"
end

return unused_module
]])

    -- Reset and re-initialize coverage with discover_uncovered enabled
    coverage_module.reset()
    coverage_module.init({
      enabled = true,
      source_dirs = {temp_dir},
      exclude = {},
      include = {test_file_path, zero_coverage_file}, -- Include both files
      use_default_patterns = false, -- Don't use default patterns
      debug = true,
      discover_uncovered = true
    })
    
    -- Start coverage
    coverage_module.start()
    
    -- Load only our first test module
    local test_module = dofile(test_file_path)
    test_module.add(1, 2)
    
    -- Calculate stats
    coverage_module.calculate_stats()
    
    -- Get report data
    local report_data = coverage_module.get_report_data()
    
    -- Both files should be in the report
    expect(report_data.files[test_file_path]).to.exist()
    expect(report_data.files[zero_coverage_file]).to.exist()
    
    -- The zero_coverage file should have 0 covered lines
    local zero_file_stats = report_data.files[zero_coverage_file]
    expect(zero_file_stats.covered_lines).to.equal(0)
    
    -- Clean up
    fs.delete_file(zero_coverage_file)
  end)

  it("should generate various report formats", function()
    -- Start coverage
    coverage_module.start()
    
    -- Load our test module
    local test_module = dofile(test_file_path)
    
    -- Call some functions
    test_module.add(1, 2)
    test_module.subtract(5, 3)
    
    -- Generate different reports
    local summary = coverage_module.report("summary")
    local json = coverage_module.report("json")
    local html = coverage_module.report("html")
    local lcov = coverage_module.report("lcov")
    
    -- Check that all formats were generated
    expect(summary).to.exist()
    expect(json).to.exist()
    expect(html).to.exist()
    expect(lcov).to.exist()
    
    -- Check that summary format has expected structure
    expect(summary.total_lines).to.be.greater_than(0)
    expect(summary.covered_lines).to.be.greater_than(0)
    expect(summary.files).to.exist()
    
    -- HTML should contain HTML tags
    expect(html:match("<html>")).to.exist()
    
    -- LCOV should have the right format
    expect(lcov:match("SF:")).to.exist()
    expect(lcov:match("end_of_record")).to.exist()
  end)

  it("should handle threshold checking", function()
    -- Start coverage
    coverage_module.start()
    
    -- Load our test module and call functions
    local test_module = dofile(test_file_path)
    test_module.add(1, 2)
    
    -- Test meets_threshold with a low threshold
    expect(coverage_module.meets_threshold(10)).to.be.truthy()
    
    -- Test meets_threshold with a high threshold
    expect(coverage_module.meets_threshold(100)).to.be.falsey()
    
    -- Test with the default threshold
    local default_result = coverage_module.meets_threshold()
    expect(default_result).to.be.a("boolean")
    
    -- Test saving reports
    local report_path = fs.join_paths(temp_dir, "coverage-report.html")
    local success = coverage_module.save_report(report_path, "html")
    expect(success).to.be.truthy()
    expect(fs.file_exists(report_path)).to.be.truthy()
    
    -- Clean up
    fs.delete_file(report_path)
  end)
end)