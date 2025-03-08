#!/usr/bin/env lua
-- Parallel test execution example for lust-next

local lust = require("lust-next")

-- Add the lib directory to the package path for loading the parallel module
package.path = "./lib/?.lua;" .. package.path

-- Load the parallel module and register it with lust
local parallel_loaded, parallel = pcall(require, "tools.parallel")
if not parallel_loaded then
  print("Warning: Could not load parallel module. Using fallback.")
else
  parallel.register_with_lust(lust)
end

print("lust-next Parallel Test Execution Example")
print("------------------------------------------")

-- Create a simple test to demonstrate parallel execution
lust.describe("Parallel Test Execution Demo", function()
  lust.it("can run tests in parallel", function()
    lust.expect(1 + 1).to.equal(2)
  end)
  
  lust.it("can also run this test", function()
    lust.expect("test").to.be.a("string")
  end)
  
  lust.it("demonstrates a longer-running test", function()
    -- Simulate a test that takes some time
    local function sleep(sec)
      local start = os.clock()
      while os.clock() - start < sec do end
    end
    
    sleep(0.1) -- Sleep for 100ms
    lust.expect(true).to.be.truthy()
  end)
end)

-- If running this file directly, print usage instructions
if arg[0]:match("parallel_execution_example%.lua$") then
  -- Run a small demo to showcase parallel execution
  print("\nDemonstrating parallel test execution...")
  print("----------------------------------------")
  
  local function create_test_files(dir, count)
    -- Create a temporary directory for test files
    os.execute("mkdir -p " .. dir)
    
    -- Create a few test files
    local files = {}
    for i = 1, count do
      local file_path = dir .. "/test_" .. i .. ".lua"
      local delay = math.random() * 0.3 -- Random delay between 0-300ms
      
      local f = io.open(file_path, "w")
      if f then
        f:write("-- Generated test file #" .. i .. "\n")
        f:write("local lust = require('lust-next')\n")
        f:write("local describe, it, expect = lust.describe, lust.it, lust.expect\n\n")
        f:write("-- Simulate work by sleeping\n")
        f:write("local function sleep(sec)\n")
        f:write("  local start = os.clock()\n")
        f:write("  while os.clock() - start < sec do end\n")
        f:write("end\n\n")
        f:write("describe('Test File " .. i .. "', function()\n")
        
        -- Create a few test cases in each file
        for j = 1, 3 do
          f:write("  it('test case " .. j .. "', function()\n")
          f:write("    sleep(" .. string.format("%.3f", delay) .. ") -- Sleep to simulate work\n")
          f:write("    expect(1 + " .. j .. ").to.equal(" .. (1 + j) .. ")\n")
          f:write("  end)\n")
        end
        
        f:write("end)\n")
        f:close()
        table.insert(files, file_path)
      end
    end
    
    return files
  end
  
  -- Create 10 test files in a temporary directory
  local temp_dir = "/tmp/lust_parallel_demo"
  local files = create_test_files(temp_dir, 10)
  
  -- Report what we created
  print("Created " .. #files .. " test files in " .. temp_dir)
  
  -- Basic sequential execution demo
  print("\n== Running tests sequentially ==")
  local start_time = os.clock()
  for _, file in ipairs(files) do
    lust.reset()
    dofile(file)
  end
  local sequential_time = os.clock() - start_time
  print("Sequential execution time: " .. string.format("%.3f", sequential_time) .. " seconds")
  
  -- Parallel execution demo
  if lust.parallel then
    print("\n== Running tests in parallel ==")
    local parallel_start = os.clock()
    
    -- Use the files as they are - they already have the correct path
    
    -- Run tests in parallel
    local results = lust.parallel.run_tests(files, {
      workers = 4,                  -- Use 4 worker processes
      show_worker_output = true,    -- Show individual worker output for the demo
      verbose = true                -- Display verbose output for the demo
    })
    local parallel_time = os.clock() - parallel_start
    print("Parallel execution time: " .. string.format("%.3f", parallel_time) .. " seconds")
    
    -- Show speedup
    local speedup = sequential_time / parallel_time
    print("\nParallel execution was " .. string.format("%.2fx", speedup) .. " faster")
    print("\nParallel execution results:")
    print("  Total tests: " .. results.total)
    print("  Passed: " .. results.passed)
    print("  Failed: " .. results.failed)
    print("  Skipped: " .. results.skipped)
  else
    print("\nParallel module not available. Cannot demonstrate parallel execution.")
  end
  
  -- Clean up temporary files
  print("\nCleaning up temporary test files...")
  for _, file in ipairs(files) do
    os.remove(file)
  end
  os.execute("rmdir " .. temp_dir)
  
  print("\nParallel Test Execution Example Complete")
  print("To use parallel execution in your own tests, run:")
  print("  lua run_all_tests.lua --parallel --workers 4")
  print("Or for a specific test file:")
  print("  lua scripts/run_tests.lua --parallel --workers 4 tests/your_test.lua")
end