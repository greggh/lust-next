#!/usr/bin/env lua
-- Parallel test execution example for firmo

local firmo = require("firmo")

-- Add the lib directory to the package path for loading the parallel module
package.path = "./lib/?.lua;" .. package.path

-- Load the parallel module and register it with firmo
local parallel_loaded, parallel = pcall(require, "tools.parallel")
if not parallel_loaded then
  print("Warning: Could not load parallel module. Using fallback.")
else
  parallel.register_with_firmo(firmo)
end

print("firmo Parallel Test Execution Example")
print("------------------------------------------")

-- Create a simple test to demonstrate parallel execution
firmo.describe("Parallel Test Execution Demo", function()
  firmo.it("can run tests in parallel", function()
    firmo.expect(1 + 1).to.equal(2)
  end)
  
  firmo.it("can also run this test", function()
    firmo.expect("test").to.be.a("string")
  end)
  
  firmo.it("demonstrates a longer-running test", function()
    -- Simulate a test that takes some time
    local function sleep(sec)
      local start = os.clock()
      while os.clock() - start < sec do end
    end
    
    sleep(0.1) -- Sleep for 100ms
    firmo.expect(true).to.be.truthy()
  end)
end)

-- If running this file directly, print usage instructions
if arg[0]:match("parallel_execution_example%.lua$") then
  -- Run a small demo to showcase parallel execution
  print("\nDemonstrating parallel test execution...")
  print("----------------------------------------")
  
  -- Load the filesystem module
  local fs = require("lib.tools.filesystem")
  
  local function create_test_files(dir, count)
    -- Create a temporary directory for test files
    fs.ensure_directory_exists(dir)
    
    -- Create a few test files
    local files = {}
    for i = 1, count do
      local file_path = fs.join_paths(dir, "test_" .. i .. ".lua")
      local delay = math.random() * 0.3 -- Random delay between 0-300ms
      
      -- Build file content
      local content = "-- Generated test file #" .. i .. "\n"
      content = content .. "local firmo = require('firmo')\n"
      content = content .. "local describe, it, expect = firmo.describe, firmo.it, firmo.expect\n\n"
      content = content .. "-- Simulate work by sleeping\n"
      content = content .. "local function sleep(sec)\n"
      content = content .. "  local start = os.clock()\n"
      content = content .. "  while os.clock() - start < sec do end\n"
      content = content .. "end\n\n"
      content = content .. "describe('Test File " .. i .. "', function()\n"
      
      -- Create a few test cases in each file
      for j = 1, 3 do
        content = content .. "  it('test case " .. j .. "', function()\n"
        content = content .. "    sleep(" .. string.format("%.3f", delay) .. ") -- Sleep to simulate work\n"
        content = content .. "    expect(1 + " .. j .. ").to.equal(" .. (1 + j) .. ")\n"
        content = content .. "  end)\n"
      end
      
      content = content .. "end)\n"
      
      -- Write the file
      local success, err = fs.write_file(file_path, content)
      if success then
        table.insert(files, file_path)
      else
        print("Error writing test file: " .. (err or "unknown error"))
      end
    end
    
    return files
  end
  
  -- Create 10 test files in a temporary directory
  local temp_dir = "/tmp/firmo_parallel_demo"
  local files = create_test_files(temp_dir, 10)
  
  -- Report what we created
  print("Created " .. #files .. " test files in " .. temp_dir)
  
  -- Basic sequential execution demo
  print("\n== Running tests sequentially ==")
  local start_time = os.clock()
  for _, file in ipairs(files) do
    firmo.reset()
    dofile(file)
  end
  local sequential_time = os.clock() - start_time
  print("Sequential execution time: " .. string.format("%.3f", sequential_time) .. " seconds")
  
  -- Parallel execution demo
  if firmo.parallel then
    print("\n== Running tests in parallel ==")
    local parallel_start = os.clock()
    
    -- Use the files as they are - they already have the correct path
    
    -- Run tests in parallel
    local results = firmo.parallel.run_tests(files, {
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
    fs.delete_file(file)
  end
  fs.delete_directory(temp_dir)
  
  print("\nParallel Test Execution Example Complete")
  print("To use parallel execution in your own tests, run:")
  print("  lua run_all_tests.lua --parallel --workers 4")
  print("Or for a specific test file:")
  print("  lua scripts/run_tests.lua --parallel --workers 4 tests/your_test.lua")
end
