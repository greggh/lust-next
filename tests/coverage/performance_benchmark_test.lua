--[[
  performance_benchmark_test.lua
  
  Benchmarks for the coverage module to ensure reasonable performance 
  with various codebase sizes and complexity.
--]]

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

local coverage = require("lib.coverage")
local debug_hook = require("lib.coverage.debug_hook")
local fs = require("lib.tools.filesystem")
local benchmark = require("lib.tools.benchmark")

-- Helper function to generate a lua file with specified complexity
local function generate_test_file(options)
  options = options or {}
  local line_count = options.line_count or 1000
  local branch_count = options.branch_count or 10
  local function_count = options.function_count or 5
  local has_complex_conditions = options.complex_conditions or false

  local lines = {
    "local M = {}", 
    "",
    "-- Generated test file with:",
    string.format("-- %d lines", line_count),
    string.format("-- %d branches", branch_count),
    string.format("-- %d functions", function_count),
    string.format("-- complex conditions: %s", has_complex_conditions and "true" or "false"),
    ""
  }

  -- Generate functions
  for f = 1, function_count do
    table.insert(lines, string.format("function M.function_%d(input)", f))
    table.insert(lines, "  local result = 0")
    
    -- Generate branches (if/elseif/else blocks)
    local branches_per_function = math.floor(branch_count / function_count)
    
    -- Generate the first if statement
    if has_complex_conditions then
      table.insert(lines, string.format("  if input > %d and input < %d or input == %d then", 
        f * 10, f * 20, f * 5))
    else
      table.insert(lines, string.format("  if input > %d then", f * 10))
    end
    table.insert(lines, "    result = input * 2")
    
    -- Generate elseif statements
    for b = 2, branches_per_function - 1 do
      if has_complex_conditions and b % 2 == 0 then
        table.insert(lines, string.format("  elseif (input > %d and input < %d) or input == %d then", 
          b * 5, b * 15, b * 3))
      else
        table.insert(lines, string.format("  elseif input > %d then", b * 5))
      end
      table.insert(lines, string.format("    result = input * %d", b))
    end
    
    -- Generate else branch
    table.insert(lines, "  else")
    table.insert(lines, "    result = input")
    table.insert(lines, "  end")
    
    -- Add some loops for complexity
    table.insert(lines, "  for i = 1, 5 do")
    table.insert(lines, "    result = result + i")
    table.insert(lines, "  end")
    
    -- Add a while loop
    table.insert(lines, "  local counter = 0")
    table.insert(lines, "  while counter < 3 do")
    table.insert(lines, "    result = result + counter")
    table.insert(lines, "    counter = counter + 1")
    table.insert(lines, "  end")
    
    table.insert(lines, "  return result")
    table.insert(lines, "end")
    table.insert(lines, "")
  end
  
  -- Add a run function that calls all the other functions
  table.insert(lines, "function M.run_all(value)")
  table.insert(lines, "  local results = {}")
  for f = 1, function_count do
    table.insert(lines, string.format("  results[%d] = M.function_%d(value)", f, f))
  end
  table.insert(lines, "  return results")
  table.insert(lines, "end")
  
  -- Fill remaining lines with comments to reach line_count
  local current_lines = #lines
  if current_lines < line_count then
    for i = current_lines + 1, line_count do
      table.insert(lines, string.format("-- This is line %d of the generated file", i))
    end
  end
  
  -- Add return statement at the end
  table.insert(lines, "return M")
  
  -- Create a temporary directory if needed
  local temp_dir = "./temp_test_files"
  os.execute("mkdir -p " .. temp_dir)
  
  -- Generate a unique filename in our own temp directory (not using os.tmpname())
  local timestamp = os.time()
  local random_suffix = math.random(1000, 9999)
  local filename = string.format("test_file_%d_%d.lua", timestamp, random_suffix)
  local file_path = temp_dir .. "/" .. filename
  
  -- Write to file
  local file = io.open(file_path, "w")
  file:write(table.concat(lines, "\n"))
  file:close()
  
  return file_path
end

describe("Coverage Performance Benchmarks", function()
  -- Create temporary directory for test files
  local temp_dir = "./temp_test_files"
  os.execute("mkdir -p " .. temp_dir)
  
  -- Store test files to clean up later
  local test_files = {}
  
  -- Custom measure function to work around benchmark.measure issues
  local function measure_execution(func)
    local start_time = os.clock()
    func()
    local end_time = os.clock()
    return end_time - start_time
  end
  
  after(function()
    -- Clean up all test files
    for _, file_path in ipairs(test_files) do
      os.remove(file_path)
    end
    
    -- Try to remove the temp directory (only if empty)
    -- This is best-effort cleanup - we don't fail the test if this doesn't work
    os.execute("rmdir " .. temp_dir .. " 2>/dev/null || true")
  end)
  
  it("should have reasonable overhead for small files", function()
    -- Generate a small test file
    local small_file = generate_test_file({
      line_count = 200,
      branch_count = 5,
      function_count = 2
    })
    table.insert(test_files, small_file)
    
    -- Use dofile instead of require to load the module directly
    -- First run without coverage to establish baseline
    coverage.stop() -- Ensure coverage is off
    
    local baseline_time = measure_execution(function()
      local module = dofile(small_file)
      module.run_all(15)
      module.run_all(25)
      module.run_all(35)
    end)
    
    -- Now run with coverage enabled
    coverage.init({
      enabled = true,
      include = {small_file},
      track_blocks = true
    })
    coverage.start()
    
    local coverage_time = measure_execution(function()
      -- Use dofile again to reload the module
      local module = dofile(small_file)
      module.run_all(15)
      module.run_all(25)
      module.run_all(35)
    end)
    coverage.stop()
    
    -- Calculate overhead percentage
    local overhead_percent = ((coverage_time - baseline_time) / baseline_time) * 100
    
    -- A reasonable overhead for small files should be less than 1000%
    -- This is a high threshold, but coverage tracking does add substantial overhead
    -- On some systems, the overhead can be quite high for small files
    expect(overhead_percent).to.be_less_than(1000)
    
    print(string.format("Small file overhead: %.2f%% (Baseline: %.4fs, With Coverage: %.4fs)", 
      overhead_percent, baseline_time, coverage_time))
  end)
  
  it("should have reasonable overhead for medium files with complex conditions", function()
    -- Generate a medium test file with complex conditions
    local medium_file = generate_test_file({
      line_count = 1000,
      branch_count = 20,
      function_count = 5,
      complex_conditions = true
    })
    table.insert(test_files, medium_file)
    
    -- First run without coverage to establish baseline
    coverage.stop() -- Ensure coverage is off
    
    local baseline_time = measure_execution(function()
      local module = dofile(medium_file)
      module.run_all(15)
      module.run_all(25)
      module.run_all(35)
    end)
    
    -- Now run with coverage enabled
    coverage.init({
      enabled = true,
      include = {medium_file},
      track_blocks = true,
      track_conditions = true
    })
    coverage.start()
    
    local coverage_time = measure_execution(function()
      -- Use dofile again to reload the module
      local module = dofile(medium_file)
      module.run_all(15)
      module.run_all(25)
      module.run_all(35)
    end)
    coverage.stop()
    
    -- Calculate overhead percentage
    local overhead_percent = ((coverage_time - baseline_time) / baseline_time) * 100
    
    -- A reasonable overhead for medium files should be less than 1000%
    -- This is a high threshold, but coverage tracking with conditions does add substantial overhead
    expect(overhead_percent).to.be_less_than(1000)
    
    print(string.format("Medium file overhead: %.2f%% (Baseline: %.4fs, With Coverage: %.4fs)", 
      overhead_percent, baseline_time, coverage_time))
  end)
  
  it("should have reasonable overhead when tracking multiple files", function()
    -- Generate multiple files of different sizes
    local files = {
      generate_test_file({ line_count = 200, branch_count = 5, function_count = 2 }),
      generate_test_file({ line_count = 500, branch_count = 10, function_count = 3 }),
      generate_test_file({ line_count = 300, branch_count = 8, function_count = 4, complex_conditions = true })
    }
    
    -- Add files to cleanup list
    for _, file_path in ipairs(files) do
      table.insert(test_files, file_path)
    end
    
    -- First run without coverage to establish baseline
    coverage.stop() -- Ensure coverage is off
    
    local baseline_time = measure_execution(function()
      for _, file_path in ipairs(files) do
        local module = dofile(file_path)
        module.run_all(15)
        module.run_all(25)
      end
    end)
    
    -- Now run with coverage enabled for all files
    coverage.init({
      enabled = true,
      include = files,
      track_blocks = true,
      track_conditions = true
    })
    coverage.start()
    
    local coverage_time = measure_execution(function()
      -- Use dofile for each file to reload modules
      for _, file_path in ipairs(files) do
        local module = dofile(file_path)
        module.run_all(15)
        module.run_all(25)
      end
    end)
    coverage.stop()
    
    -- Calculate overhead percentage
    local overhead_percent = ((coverage_time - baseline_time) / baseline_time) * 100
    
    -- A reasonable overhead for multiple files should be less than 1500%
    -- This is a high threshold, but comprehensive coverage tracking does add substantial overhead
    -- When tracking multiple files, the overhead can be even higher
    expect(overhead_percent).to.be_less_than(1500)
    
    print(string.format("Multiple files overhead: %.2f%% (Baseline: %.4fs, With Coverage: %.4fs)", 
      overhead_percent, baseline_time, coverage_time))
  end)
  
  it("should measure memory usage during coverage tracking", function()
    -- Skip on platforms that don't support memory measurement
    if not collectgarbage("count") then
      print("Memory measurement not supported on this platform, skipping test")
      return
    end
    
    -- Generate a test file
    local test_file = generate_test_file({
      line_count = 1000,
      branch_count = 15,
      function_count = 5,
      complex_conditions = true
    })
    table.insert(test_files, test_file)
    
    -- Force garbage collection to get a clean baseline
    collectgarbage("collect")
    local baseline_memory = collectgarbage("count")
    
    -- Initialize coverage
    coverage.init({
      enabled = true,
      include = {test_file},
      track_blocks = true,
      track_conditions = true
    })
    coverage.start()
    
    -- Run with coverage using dofile
    local module = dofile(test_file)
    for i = 1, 10 do
      module.run_all(i * 5)
    end
    
    -- Measure memory after coverage tracking
    local coverage_memory = collectgarbage("count")
    local memory_overhead_kb = coverage_memory - baseline_memory
    
    -- Stop coverage
    coverage.stop()
    
    -- Force garbage collection
    collectgarbage("collect")
    local after_gc_memory = collectgarbage("count")
    local persistent_overhead_kb = after_gc_memory - baseline_memory
    
    -- Print memory usage information
    print(string.format("Memory usage: Baseline: %.2f KB, With Coverage: %.2f KB", 
      baseline_memory, coverage_memory))
    print(string.format("Memory overhead: %.2f KB (%.2f%% increase)", 
      memory_overhead_kb, (memory_overhead_kb / baseline_memory) * 100))
    print(string.format("Persistent memory after GC: %.2f KB (%.2f%% increase)", 
      persistent_overhead_kb, (persistent_overhead_kb / baseline_memory) * 100))
    
    -- Coverage tracking should not have extreme memory growth
    -- Allowing up to 200% memory growth during active tracking
    expect(memory_overhead_kb / baseline_memory).to.be_less_than(2.0)
  end)
  
  it("should handle large code bases efficiently", function()
    -- Generate a larger test file to simulate significant code
    local large_file = generate_test_file({
      line_count = 5000,
      branch_count = 50,
      function_count = 20,
      complex_conditions = true
    })
    table.insert(test_files, large_file)
    
    -- Rather than comparing execution time, we'll focus on ensuring coverage
    -- operations complete within reasonable timeframes
    
    -- Initialize coverage
    coverage.init({
      enabled = true,
      include = {large_file},
      track_blocks = true,
      track_conditions = true
    })
    
    -- Measure the time it takes to start coverage
    local start_time = measure_execution(function()
      coverage.start()
    end)
    
    -- Load and execute the module using dofile
    local module = dofile(large_file)
    module.run_all(25)
    
    -- Measure the time it takes to stop coverage
    local stop_time = measure_execution(function()
      coverage.stop()
    end)
    
    -- Get report data instead of saving to file
    local report_time = measure_execution(function()
      -- Get report data directly instead of saving to file
      local report_data = coverage.get_report_data()
      expect(report_data).to.exist()
      expect(report_data.summary).to.exist()
    end)
    
    -- Print performance metrics
    print(string.format("Large file performance:"))
    print(string.format("- Start time: %.4fs", start_time))
    print(string.format("- Stop time: %.4fs", stop_time))
    print(string.format("- Report generation time: %.4fs", report_time))
    
    -- Performance expectations for large files
    -- These thresholds might need adjustment based on real-world usage
    expect(start_time).to.be_less_than(1.0) -- Start should be fast
    expect(stop_time).to.be_less_than(2.0)  -- Stop might take longer due to data processing
    expect(report_time).to.be_less_than(5.0) -- Report generation for large files can take time
  end)
  
  it("should provide performance metrics through the API", function()
    -- Generate a test file
    local test_file = generate_test_file({
      line_count = 500,
      branch_count = 10,
      function_count = 3
    })
    table.insert(test_files, test_file)
    
    -- Initialize and start coverage
    coverage.init({
      enabled = true,
      include = {test_file},
      track_blocks = true,
      debug = true -- Enable debug mode to collect performance metrics
    })
    coverage.start()
    
    -- Execute the code using dofile instead of require
    local module = dofile(test_file)
    for i = 1, 5 do
      module.run_all(i * 10)
    end
    
    -- Stop coverage
    coverage.stop()
    
    -- Get performance metrics
    local metrics = debug_hook.get_performance_metrics()
    
    -- Verify metrics structure
    expect(metrics).to.exist()
    expect(metrics.hook_calls).to.exist()
    expect(metrics.line_events).to.exist()
    expect(metrics.call_events).to.exist()
    expect(metrics.execution_time).to.exist()
    expect(metrics.average_call_time).to.exist()
    
    -- Print performance metrics
    print("Performance metrics:")
    print(string.format("- Hook calls: %d", metrics.hook_calls))
    print(string.format("- Line events: %d", metrics.line_events))
    print(string.format("- Call events: %d", metrics.call_events))
    print(string.format("- Total execution time: %.4fs", metrics.execution_time))
    print(string.format("- Average call time: %.8fs", metrics.average_call_time))
    print(string.format("- Max call time: %.8fs", metrics.max_call_time))
    
    -- Basic expectations
    expect(metrics.hook_calls).to.be_greater_than(0)
    expect(metrics.line_events).to.be_greater_than(0)
    
    -- The average hook call time should be very small (microseconds)
    expect(metrics.average_call_time).to.be_less_than(0.001)
  end)
end)
