-- junit_report_example.lua
-- Example demonstrating JUnit XML reporting for CI integration

-- Make sure we're using lust-next with globals
local lust_next = require('../lust-next')
lust_next.expose_globals()

-- Optional: Try to load reporting module directly
local reporting_module = package.loaded["src.reporting"] or require("src.reporting")

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

local function divide(a, b)
  if b == 0 then
    error("Division by zero")
  end
  return a / b
end

-- Example tests with various assertions
describe("JUnit XML Reporting Demo", function()
  describe("Math operations", function()
    it("should add numbers correctly", function()
      assert.equal(5, add(2, 3))
      assert.equal(0, add(-2, 2))
    end)
    
    it("should subtract numbers correctly", function()
      assert.equal(5, subtract(10, 5))
      assert.equal(-5, subtract(5, 10))
    end)
    
    it("should multiply numbers correctly", function()
      assert.equal(6, multiply(2, 3))
      assert.equal(-6, multiply(-2, 3))
    end)
    
    -- This test will pass
    it("should divide numbers correctly", function()
      assert.equal(2, divide(10, 5))
      assert.equal(-2, divide(-10, 5))
    end)
    
    -- This test will fail
    it("should handle floating point precision", function()
      -- This will fail due to floating point precision issues
      assert.equal(0.3, add(0.1, 0.2))
    end)
    
    -- This test will raise an error
    it("should throw error on division by zero", function()
      -- Forgot to wrap in a function, will cause an error
      assert.has_error(divide(5, 0))
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
  -- In real usage, this would be created automatically by lust-next
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
      framework = "lust-next"
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
  print('    run: lua lust-next.lua --dir ./tests --reporter junit > test-results.xml')
  print('  - name: Upload test results')
  print('    uses: actions/upload-artifact@v3')
  print('    with:')
  print('      name: test-results')
  print('      path: test-results.xml')
end

print("\nRunning JUnit XML reporting example...\n")