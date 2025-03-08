-- Comprehensive coverage example 
-- Demonstrates advanced configuration and usage of the coverage module
local lust_next = require('lust-next')

print("Comprehensive Coverage Example")
print("-----------------------------")

-- Mock project structure - in a real project, these would be actual files
local project_files = {
  ["calculator.lua"] = [[
    local calculator = {}
    function calculator.add(a, b) return a + b end
    function calculator.subtract(a, b) return a - b end
    function calculator.multiply(a, b) return a * b end
    function calculator.divide(a, b) 
      if b == 0 then error("Division by zero") end
      return a / b 
    end
    function calculator.power(a, b) return a ^ b end
    function calculator.factorial(n)
      if n < 0 then error("Factorial of negative number") end
      if n == 0 then return 1 end
      return n * calculator.factorial(n - 1)
    end
    return calculator
  ]],
  
  ["string_utils.lua"] = [[
    local utils = {}
    function utils.trim(s) return s:match("^%s*(.-)%s*$") end
    function utils.split(s, sep)
      local result = {}
      for part in string.gmatch(s, "([^"..sep.."]+)") do
        table.insert(result, part)
      end
      return result
    end
    function utils.join(t, sep) return table.concat(t, sep) end
    function utils.capitalize(s) return s:sub(1,1):upper() .. s:sub(2) end
    function utils.reverse(s) return s:reverse() end
    return utils
  ]],
  
  ["data_processor.lua"] = [[
    local processor = {}
    processor.calculator = require("calculator")
    processor.string_utils = require("string_utils")
    
    function processor.process_numbers(numbers, operation)
      if #numbers == 0 then return 0 end
      local result = numbers[1]
      for i=2, #numbers do
        if operation == "add" then
          result = processor.calculator.add(result, numbers[i])
        elseif operation == "multiply" then
          result = processor.calculator.multiply(result, numbers[i])
        else
          error("Unknown operation: " .. operation)
        end
      end
      return result
    end
    
    function processor.format_result(result, format)
      if format == "scientific" then
        return string.format("%.2e", result)
      elseif format == "percent" then
        return string.format("%.2f%%", result * 100)
      else
        return tostring(result)
      end
    end
    
    function processor.unused_function()
      -- This function will show up as uncovered
      return "I'm never called"
    end
    
    return processor
  ]]
}

-- Simulate reading files by loading strings
for file_name, content in pairs(project_files) do
  -- In a real project, these would be real files, not loadstring
  package.loaded[file_name:gsub("%.lua$", "")] = loadstring(content)()
end

-- Get the modules we created
local calculator = require("calculator")
local string_utils = require("string_utils")
local processor = require("data_processor")

-- Define tests that will have incomplete coverage
describe("Comprehensive Coverage Tests", function()
  describe("Calculator", function()
    it("should add numbers correctly", function()
      assert.equal(calculator.add(2, 3), 5)
      assert.equal(calculator.add(-1, 1), 0)
    end)
    
    it("should subtract numbers correctly", function()
      assert.equal(calculator.subtract(5, 3), 2)
      assert.equal(calculator.subtract(3, 5), -2)
    end)
    
    it("should multiply numbers correctly", function()
      assert.equal(calculator.multiply(2, 3), 6)
      assert.equal(calculator.multiply(-2, -3), 6)
    end)
    
    -- Note: We don't test divide, power, or factorial
    -- This will show up as incomplete coverage
  end)
  
  describe("String Utils", function()
    it("should trim strings correctly", function()
      assert.equal(string_utils.trim("  hello  "), "hello")
      assert.equal(string_utils.trim("\t\nhello\n\t"), "hello")
    end)
    
    it("should split strings correctly", function()
      local result = string_utils.split("a,b,c", ",")
      assert.equal(#result, 3)
      assert.equal(result[1], "a")
      assert.equal(result[2], "b")
      assert.equal(result[3], "c")
    end)
    
    -- Note: We don't test join, capitalize, or reverse
    -- This will show up as incomplete coverage
  end)
  
  describe("Data Processor", function()
    it("should process numbers with addition", function()
      assert.equal(processor.process_numbers({1, 2, 3}, "add"), 6)
      assert.equal(processor.process_numbers({5}, "add"), 5)
      assert.equal(processor.process_numbers({}, "add"), 0)
    end)
    
    -- Note: We don't test multiplication or format_result
    -- This will show up as incomplete coverage
  end)
end)

-- Configure coverage with advanced options
lust_next.coverage_options = {
  enabled = true,                      -- Enable coverage tracking
  source_dirs = {"."},                 -- Look in current directory for source files
  discover_uncovered = true,           -- Include files not touched by tests
  debug = true,                        -- Show detailed debug output
  use_default_patterns = false,        -- Don't use default include/exclude patterns
  
  -- Include our simulated modules
  include = {
    "calculator",
    "string_utils",
    "data_processor"
  },
  
  -- No excludes needed for this example
  exclude = {},
  
  -- Set a moderate threshold
  threshold = 60
}

-- Initialize coverage with custom configuration
if lust_next.start_coverage then
  print("\nStarting coverage with advanced configuration...")
  lust_next.start_coverage(lust_next.coverage_options)
end

-- Run all tests
print("\nRunning tests...")
lust_next.run()

-- Stop coverage tracking
if lust_next.stop_coverage then
  print("\nStopping coverage tracking...")
  lust_next.stop_coverage()
end

-- Generate and display multiple report formats
if lust_next.generate_coverage_report then
  print("\nGenerating coverage reports...")
  
  -- Summary report
  print("\n=== Summary Coverage Report ===")
  local summary = lust_next.generate_coverage_report("summary")
  print(summary)
  
  -- Save reports in different formats
  local formats = {"html", "json", "lcov"}
  for _, format in ipairs(formats) do
    local output_path = "./coverage-reports/comprehensive-report." .. format
    local success = lust_next.save_coverage_report(output_path, format)
    if success then
      print("Saved " .. format .. " report to: " .. output_path)
    else
      print("Failed to save " .. format .. " report!")
    end
  end
  
  -- Report specific statistics
  local report_data = lust_next.get_coverage_data()
  if report_data then
    print("\n=== Coverage Statistics ===")
    print("Overall coverage: " .. string.format("%.2f%%", report_data.summary.overall_percent))
    print("Line coverage: " .. string.format("%.2f%%", report_data.summary.line_coverage_percent))
    print("Function coverage: " .. string.format("%.2f%%", report_data.summary.function_coverage_percent))
    
    -- Display file-specific stats
    print("\n=== Coverage by File ===")
    for file_name, file_stats in pairs(report_data.files) do
      local line_pct = file_stats.covered_lines / math.max(1, file_stats.total_lines) * 100
      print(string.format("%s: %.2f%% (%d/%d lines)", 
        file_name, line_pct, file_stats.covered_lines, file_stats.total_lines))
    end
  end
  
  -- Check against threshold
  print("\n=== Threshold Check ===")
  if lust_next.coverage_meets_threshold(60) then
    print("✓ Coverage meets the threshold of 60%!")
  else
    print("✗ Coverage is below the threshold of 60%!")
  end
end

-- Clean up (remove our mock modules from package.loaded)
package.loaded["calculator"] = nil
package.loaded["string_utils"] = nil
package.loaded["data_processor"] = nil

print("\nComprehensive coverage example complete!")