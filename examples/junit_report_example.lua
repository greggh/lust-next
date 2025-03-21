-- junit_report_example.lua
-- Example demonstrating JUnit XML reporting for CI integration

-- Import the firmo framework
local firmo = require('firmo')

-- Extract testing functions (preferred way to import)
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local pending = firmo.pending

-- Optional: Try to load reporting module directly
local reporting_module = package.loaded["lib.reporting"] or require("lib.reporting")

-- Some sample code to test 
local function add(a, b)
  return a + b
end

local function subtract(a, b)
  return a - b
end

local function multiply(a, b)
  return a * b
end

-- Import error handling module
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")

local function divide(a, b)
  if b == 0 then
    return nil, error_handler.validation_error(
      "Division by zero",
      { parameter = "b", provided_value = b }
    )
  end
  return a / b
end

-- Example tests with various assertions
describe("JUnit XML Reporting Demo", function()
  describe("Math operations", function()
    it("should add numbers correctly", function()
      expect(add(2, 3)).to.equal(5)
      expect(add(-2, 2)).to.equal(0)
    end)
    
    it("should subtract numbers correctly", function()
      expect(subtract(10, 5)).to.equal(5)
      expect(subtract(5, 10)).to.equal(-5)
    end)
    
    it("should multiply numbers correctly", function()
      expect(multiply(2, 3)).to.equal(6)
      expect(multiply(-2, 3)).to.equal(-6)
    end)
    
    -- This test will pass
    it("should divide numbers correctly", function()
      expect(divide(10, 5)).to.equal(2)
      expect(divide(-10, 5)).to.equal(-2)
    end)
    
    -- This test will fail
    it("should handle floating point precision", function()
      -- This will fail due to floating point precision issues
      expect(add(0.1, 0.2)).to.equal(0.3)
    end)
    
    -- This test will test error handling
    it("should handle division by zero", { expect_error = true }, function()
      -- Properly testing errors with test_helper.with_error_capture
      local result, err = test_helper.with_error_capture(function()
        return divide(5, 0)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("Division by zero")
      expect(err.context.parameter).to.equal("b")
    end)
    
    -- This test will be skipped/pending
    it("should handle complex arithmetic", function()
      pending("Not implemented yet")
    end)
  end)
end)

-- After running tests, convert the results to JUnit XML
print("\nDemonstrating JUnit XML Reporting:")
do
  -- Normally this would be handled by the CLI, but for example purposes
  -- we're creating a mock test results data structure
  
  if not reporting_module then
    print("Reporting module not available, skipping demonstration")
    return
  end
  
  -- Create a demo test results data structure
  -- In real usage, this would be created automatically by firmo
  local test_results = {
    name = "JUnitDemo",
    timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
    tests = 7, -- Total number of tests
    failures = 1, -- Number of assertion failures
    errors = 1, -- Number of runtime errors
    skipped = 1, -- Number of skipped/pending tests
    time = 0.125, -- Total execution time
    properties = {
      lua_version = _VERSION,
      platform = package.config:sub(1,1) == "\\" and "Windows" or "Unix",
      framework = "firmo"
    },
    test_cases = {
      {
        name = "should add numbers correctly",
        classname = "JUnitDemo.Math operations",
        time = 0.02,
        status = "pass"
      },
      {
        name = "should subtract numbers correctly",
        classname = "JUnitDemo.Math operations",
        time = 0.02,
        status = "pass"
      },
      {
        name = "should multiply numbers correctly",
        classname = "JUnitDemo.Math operations",
        time = 0.02,
        status = "pass"
      },
      {
        name = "should divide numbers correctly",
        classname = "JUnitDemo.Math operations",
        time = 0.02,
        status = "pass"
      },
      {
        name = "should handle floating point precision",
        classname = "JUnitDemo.Math operations",
        time = 0.02,
        status = "fail",
        failure = {
          message = "Expected values to be equal",
          type = "AssertionError",
          details = "Expected 0.3, got 0.30000000000000004"
        }
      },
      {
        name = "should throw error on division by zero",
        classname = "JUnitDemo.Math operations",
        time = 0.02,
        status = "error",
        error = {
          message = "Runtime error",
          type = "Error",
          details = "Division by zero"
        }
      },
      {
        name = "should handle complex arithmetic",
        classname = "JUnitDemo.Math operations",
        time = 0.005,
        status = "skipped",
        skip_message = "Not implemented yet"
      }
    }
  }
  
  -- Generate JUnit XML
  local junit_xml = reporting_module.format_results(test_results, "junit")
  
  -- Print sample of the XML
  print("\nJUnit XML example (first 10 lines):")
  for i, line in ipairs({junit_xml:match("([^\n]*)\n?"):gmatch("[^\n]+")} or {}) do
    if i <= 10 then
      print(line)
    else
      break
    end
  end
  print("... (truncated)")
  
  -- Save the XML to a file (commented out by default)
  -- local success, err = reporting_module.save_results_report("./junit-example.xml", test_results, "junit")
  -- if success then
  --   print("\nSaved JUnit XML report to ./junit-example.xml")
  -- else
  --   print("\nFailed to save JUnit XML report: " .. tostring(err))
  -- end
  
  print("\nIn CI environments, you would use this XML for integration with test reporting systems.")
  print("Example usage with GitHub Actions:")
  print('  - name: Run tests')
  print('    run: lua firmo.lua --dir ./tests --reporter junit > test-results.xml')
  print('  - name: Upload test results')
  print('    uses: actions/upload-artifact@v3')
  print('    with:')
  print('      name: test-results')
  print('      path: test-results.xml')
end

print("\nRunning JUnit XML reporting example...\n")

-- Note: Run this example using the standard test runner:
-- lua test.lua examples/junit_report_example.lua
