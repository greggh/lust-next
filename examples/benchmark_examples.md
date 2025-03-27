# Benchmark Examples

This document provides practical examples for using the Firmo benchmark module to measure code performance and optimize your implementations.

## Basic Benchmarking

### Measuring Function Execution Time

```lua
local benchmark = require("lib.tools.benchmark")

-- Define a function to benchmark
local function factorial(n)
  if n <= 1 then
    return 1
  else
    return n * factorial(n - 1)
  end
end

-- Measure its performance
local result = benchmark.measure(factorial, {10}, {
  iterations = 10,
  warmup = 2,
  label = "Factorial calculation"
})

-- Print the results
benchmark.print_result(result)
```

### Measuring Memory Usage

```lua
local benchmark = require("lib.tools.benchmark")

-- Function that creates a large table
local function create_large_table(size)
  local tbl = {}
  for i = 1, size do
    tbl[i] = string.rep("a", 10)
  end
  return tbl
end

-- Measure with memory tracking
local result = benchmark.measure(create_large_table, {10000}, {
  iterations = 5,
  gc_before = true,
  report_memory = true,
  label = "Table creation"
})

-- Print memory usage statistics
print(string.format("Average memory used: %.2f KB", result.memory_stats.mean))
print(string.format("Peak memory used: %.2f KB", result.memory_stats.max))
```

## Comparing Different Implementations

### String Concatenation vs Table Concat

```lua
local benchmark = require("lib.tools.benchmark")

-- String concatenation approach
local function string_concat(size)
  local result = ""
  for i = 1, size do
    result = result .. "a"
  end
  return result
end

-- Table concat approach
local function table_concat(size)
  local parts = {}
  for i = 1, size do
    parts[i] = "a"
  end
  return table.concat(parts)
end

-- String repeat approach
local function string_repeat(size)
  return string.rep("a", size)
end

-- Benchmark each approach
local concat_result = benchmark.measure(string_concat, {10000}, {
  label = "String concatenation",
  iterations = 5
})

local table_result = benchmark.measure(table_concat, {10000}, {
  label = "Table concat",
  iterations = 5
})

local repeat_result = benchmark.measure(string_repeat, {10000}, {
  label = "String repeat",
  iterations = 5
})

-- Compare the approaches
benchmark.compare(concat_result, table_result)
benchmark.compare(concat_result, repeat_result)
benchmark.compare(table_result, repeat_result)
```

### Comparing Different Sorting Algorithms

```lua
local benchmark = require("lib.tools.benchmark")

-- Generate a random array of specified size
local function generate_random_array(size)
  local array = {}
  for i = 1, size do
    array[i] = math.random(1, 1000)
  end
  return array
end

-- Bubble sort implementation
local function bubble_sort(arr)
  local n = #arr
  local result = {unpack(arr)} -- Create a copy to avoid modifying original
  
  for i = 1, n do
    for j = 1, n - i do
      if result[j] > result[j + 1] then
        result[j], result[j + 1] = result[j + 1], result[j]
      end
    end
  end
  
  return result
end

-- Insertion sort implementation
local function insertion_sort(arr)
  local n = #arr
  local result = {unpack(arr)} -- Create a copy
  
  for i = 2, n do
    local key = result[i]
    local j = i - 1
    
    while j > 0 and result[j] > key do
      result[j + 1] = result[j]
      j = j - 1
    end
    
    result[j + 1] = key
  end
  
  return result
end

-- Lua's built-in table.sort (usually quicksort or mergesort)
local function lua_sort(arr)
  local result = {unpack(arr)} -- Create a copy
  table.sort(result)
  return result
end

-- Generate a dataset
local data_size = 1000
local dataset = generate_random_array(data_size)

-- Benchmark each sorting algorithm
local bubble_result = benchmark.measure(bubble_sort, {dataset}, {
  label = "Bubble sort",
  iterations = 3
})

local insertion_result = benchmark.measure(insertion_sort, {dataset}, {
  label = "Insertion sort",
  iterations = 3
})

local lua_result = benchmark.measure(lua_sort, {dataset}, {
  label = "Lua's table.sort",
  iterations = 3
})

-- Compare the results
benchmark.compare(bubble_result, insertion_result)
benchmark.compare(bubble_result, lua_result)
benchmark.compare(insertion_result, lua_result)
```

## Running Benchmark Suites

### Creating a Benchmark Suite

```lua
local benchmark = require("lib.tools.benchmark")

-- A suite of string operations
local suite_results = benchmark.suite({
  name = "String Operations",
  benchmarks = {
    {
      name = "String length",
      func = function(str)
        return #str
      end,
      args = {"This is a test string for benchmarking string length operations"}
    },
    {
      name = "String pattern matching",
      func = function(str, pattern)
        return string.match(str, pattern)
      end,
      args = {"This is a test string with numbers 12345", "%d+"}
    },
    {
      name = "String split",
      func = function(str, sep)
        local result = {}
        for part in string.gmatch(str, "[^" .. sep .. "]+") do
          table.insert(result, part)
        end
        return result
      end,
      args = {"word1,word2,word3,word4,word5", ","}
    },
    {
      name = "String upper",
      func = function(str)
        return string.upper(str)
      end,
      args = {"This is a test string that will be converted to uppercase"}
    }
  }
}, {
  iterations = 5,
  warmup = 2,
  report_memory = true
})
```

### Complex Data Processing Suite

```lua
local benchmark = require("lib.tools.benchmark")

-- Define some data processing functions
local function process_data_v1(data)
  local result = {}
  for i, value in ipairs(data) do
    if value % 2 == 0 then
      result[i] = value * 2
    else
      result[i] = value + 1
    end
  end
  return result
end

local function process_data_v2(data)
  local result = {}
  for i = 1, #data do
    local value = data[i]
    result[i] = value % 2 == 0 and value * 2 or value + 1
  end
  return result
end

local function process_data_v3(data)
  local result = {}
  local process = {
    [0] = function(x) return x * 2 end,
    [1] = function(x) return x + 1 end
  }
  
  for i = 1, #data do
    local value = data[i]
    result[i] = process[value % 2](value)
  end
  return result
end

-- Create test data
local function create_test_data(size)
  local data = {}
  for i = 1, size do
    data[i] = math.random(1, 100)
  end
  return data
end

-- Run the suite with different data sizes
local data_sizes = {100, 1000, 10000}

for _, size in ipairs(data_sizes) do
  local test_data = create_test_data(size)
  
  local suite_results = benchmark.suite({
    name = "Data Processing (size = " .. size .. ")",
    benchmarks = {
      {
        name = "Implementation V1",
        func = process_data_v1,
        args = {test_data}
      },
      {
        name = "Implementation V2",
        func = process_data_v2,
        args = {test_data}
      },
      {
        name = "Implementation V3",
        func = process_data_v3,
        args = {test_data}
      }
    }
  })
end
```

## Benchmarking Real-World Scenarios

### File Processing Performance

```lua
local benchmark = require("lib.tools.benchmark")
local fs = require("lib.tools.filesystem")

-- Create a temporary test file
local function create_test_file(path, size)
  local file = io.open(path, "w")
  if not file then
    error("Could not create test file: " .. path)
  end
  
  -- Write lines with random data
  for i = 1, size do
    file:write("Line " .. i .. ": " .. string.rep("DATA", math.random(1, 10)) .. "\n")
  end
  
  file:close()
end

-- Process a file line by line
local function process_file_line_by_line(path)
  local result = {lines = 0, chars = 0}
  
  for line in io.lines(path) do
    result.lines = result.lines + 1
    result.chars = result.chars + #line
  end
  
  return result
end

-- Process a file in chunks
local function process_file_in_chunks(path, chunk_size)
  local result = {lines = 0, chars = 0}
  local file = io.open(path, "r")
  if not file then
    error("Could not open file: " .. path)
  end
  
  while true do
    local chunk = file:read(chunk_size)
    if not chunk then break end
    
    result.chars = result.chars + #chunk
    for _ in chunk:gmatch("\n") do
      result.lines = result.lines + 1
    end
  end
  
  file:close()
  return result
end

-- Process a file all at once
local function process_file_all_at_once(path)
  local result = {lines = 0, chars = 0}
  local file = io.open(path, "r")
  if not file then
    error("Could not open file: " .. path)
  end
  
  local content = file:read("*a")
  result.chars = #content
  for _ in content:gmatch("\n") do
    result.lines = result.lines + 1
  end
  
  file:close()
  return result
end

-- Create test files
local test_file = os.tmpname()
local file_size = 10000 -- lines
create_test_file(test_file, file_size)

-- Benchmark different file processing approaches
local line_by_line_result = benchmark.measure(process_file_line_by_line, {test_file}, {
  label = "Line by line processing",
  iterations = 5
})

local chunk_result = benchmark.measure(process_file_in_chunks, {test_file, 4096}, {
  label = "Chunk processing (4KB)",
  iterations = 5
})

local all_at_once_result = benchmark.measure(process_file_all_at_once, {test_file}, {
  label = "All at once processing",
  iterations = 5
})

-- Compare the results
benchmark.compare(line_by_line_result, chunk_result)
benchmark.compare(line_by_line_result, all_at_once_result)
benchmark.compare(chunk_result, all_at_once_result)

-- Clean up
os.remove(test_file)
```

### Test Runner Performance Analysis

```lua
local benchmark = require("lib.tools.benchmark")
local fs = require("lib.tools.filesystem")

-- Generate test suite with the benchmark module
local test_suite = benchmark.generate_large_test_suite({
  file_count = 20,
  tests_per_file = 30,
  nesting_level = 3,
  output_dir = "/tmp/benchmark_tests"
})

-- Prepare to measure test runner performance
local firmo = require("firmo")

-- Function to reset Firmo's state between runs
local function reset_firmo()
  firmo.reset()
  collectgarbage("collect")
end

-- Benchmark running tests with module isolation
local with_isolation = benchmark.measure(function()
  -- Configure module isolation
  if firmo.module_reset then
    firmo.module_reset.configure({
      reset_modules = true,
      verbose = false
    })
  end
  
  -- Get all test files
  local files = {}
  local all_files = fs.scan_directory(test_suite.output_dir, false)
  
  -- Filter for Lua files
  for _, file in ipairs(all_files) do
    if file:match("%.lua$") then
      table.insert(files, file)
    end
  end
  
  -- Run tests with isolation
  for _, file_path in ipairs(files) do
    reset_firmo()
    dofile(file_path)
  end
end, nil, {
  label = "Test runner with isolation",
  iterations = 3,
  warmup = 1
})

-- Benchmark running tests without module isolation
local without_isolation = benchmark.measure(function()
  -- Disable module isolation
  if firmo.module_reset then
    firmo.module_reset.configure({
      reset_modules = false,
      verbose = false
    })
  end
  
  -- Get all test files
  local files = {}
  local all_files = fs.scan_directory(test_suite.output_dir, false)
  
  -- Filter for Lua files
  for _, file in ipairs(all_files) do
    if file:match("%.lua$") then
      table.insert(files, file)
    end
  end
  
  -- Run tests without isolation
  for _, file_path in ipairs(files) do
    reset_firmo()
    dofile(file_path)
  end
end, nil, {
  label = "Test runner without isolation",
  iterations = 3,
  warmup = 1
})

-- Compare the results
local comparison = benchmark.compare(with_isolation, without_isolation)

-- Clean up
fs.delete_directory(test_suite.output_dir, true)

-- Make recommendations based on the performance difference
print("\nRecommendation based on performance analysis:")
if comparison.time_percent < 10 then
  print("The overhead of module isolation is minimal (<10%). Use isolation by default for better test reliability.")
elseif comparison.time_percent < 30 then
  print("Module isolation has moderate overhead (" .. string.format("%.1f", comparison.time_percent) .. "%). Consider using it for critical tests.")
else
  print("Module isolation has significant overhead (" .. string.format("%.1f", comparison.time_percent) .. "%). Use selectively when tests require isolation.")
end
```

### Benchmarking Coverage Approaches

```lua
local benchmark = require("lib.tools.benchmark")
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")

-- Create a sample Lua file for testing coverage approaches
local function create_test_file(complexity)
    local temp_dir = os.tmpname():gsub("([^/]+)$", "")
    local file_path = temp_dir .. "/benchmark_test_" .. complexity .. ".lua"
    
    -- Create content with configurable complexity
    local content = [[
    -- Benchmark test file with complexity level ]] .. complexity .. [[
    
    local M = {}
    
    function M.factorial(n)
        if n <= 1 then
            return 1
        else
            return n * M.factorial(n - 1)
        end
    end
    
    function M.fibonacci(n)
        if n <= 1 then
            return n
        else
            return M.fibonacci(n - 1) + M.fibonacci(n - 2)
        end
    end
    ]]
    
    -- Add varying number of functions based on complexity
    local function_count = complexity * 5
    for i = 1, function_count do
        content = content .. [[
    function M.test_function_]] .. i .. [[(x)
        local result = 0
        for j = 1, x do
            result = result + j
        end
        return result
    end
    
    ]]
    end
    
    -- Add a complex function with branches
    content = content .. [[
    function M.process_value(value)
        if type(value) ~= "number" then
            return "not_a_number"
        end
        
        if value < 0 then
            return "negative"
        elseif value == 0 then
            return "zero"
        end
        
        if value < 10 then
            if value % 2 == 0 then
                return "small_even"
            else
                return "small_odd"
            end
        else
            if value % 2 == 0 then
                return "large_even"
            else
                return "large_odd"
            end
        end
    end
    
    return M
    ]]
    
    -- Write to file
    fs.write_file(file_path, content)
    return file_path
end

-- Function to run benchmark with specified coverage approach
local function benchmark_coverage_approach(approach, complexity)
    -- Create test file
    local file_path = create_test_file(complexity)
    
    -- Configure coverage approach
    local function setup_coverage()
        if approach == "debug_hook" then
            coverage.init({
                enabled = true,
                use_instrumentation = false,  -- Use debug hook approach
                use_static_analysis = true,
                track_blocks = true
            })
        elseif approach == "instrumentation" then
            coverage.init({
                enabled = true,
                use_instrumentation = true,   -- Use instrumentation approach
                instrument_on_load = true,
                use_static_analysis = true,
                track_blocks = true,
                cache_instrumented_files = true
            })
        else
            -- No coverage
            coverage.init({
                enabled = false
            })
        end
        
        -- Reset coverage data
        coverage.reset()
    end
    
    -- Function to run with coverage
    local function run_with_coverage()
        -- Start coverage
        coverage.start()
        
        -- Load and exercise the module
        local mod = dofile(file_path)
        mod.factorial(5)
        mod.fibonacci(5)
        for i = 1, complexity do
            mod["test_function_" .. i](i * 2)
        end
        
        -- Exercise the complex function
        mod.process_value("string")
        mod.process_value(-5)
        mod.process_value(0)
        mod.process_value(5)
        mod.process_value(8)
        mod.process_value(50)
        
        -- Stop coverage
        coverage.stop()
        
        -- Generate report (but don't write to disk)
        local report = coverage.generate_report("html")
        return #report > 0
    end
    
    -- Set up coverage
    setup_coverage()
    
    -- Measure performance
    local result = benchmark.measure(run_with_coverage, {}, {
        iterations = 5,
        warmup = 1,
        label = approach .. " (complexity " .. complexity .. ")"
    })
    
    -- Clean up
    os.remove(file_path)
    
    return result
end

-- Benchmark different coverage approaches
local complexity_levels = {1, 3, 5}

for _, complexity in ipairs(complexity_levels) do
    print("\nBenchmarking coverage approaches with complexity level " .. complexity)
    
    -- No coverage (baseline)
    local baseline = benchmark_coverage_approach("none", complexity)
    
    -- Debug hook approach
    local debug_hook = benchmark_coverage_approach("debug_hook", complexity)
    
    -- Instrumentation approach
    local instrumentation = benchmark_coverage_approach("instrumentation", complexity)
    
    -- Compare approaches
    print("\nBaseline vs Debug Hook:")
    benchmark.compare(baseline, debug_hook)
    
    print("\nBaseline vs Instrumentation:")
    benchmark.compare(baseline, instrumentation)
    
    print("\nDebug Hook vs Instrumentation:")
    benchmark.compare(debug_hook, instrumentation)
    
    -- Performance summary
    print("\nPerformance Summary (Complexity " .. complexity .. "):")
    print("1. Debug Hook overhead: +" .. string.format("%.1f%%", ((debug_hook.time_stats.mean / baseline.time_stats.mean) - 1) * 100))
    print("2. Instrumentation overhead: +" .. string.format("%.1f%%", ((instrumentation.time_stats.mean / baseline.time_stats.mean) - 1) * 100))
    
    -- Recommendation
    local approach_diff = ((instrumentation.time_stats.mean / debug_hook.time_stats.mean) - 1) * 100
    print("\nRecommendation:")
    if approach_diff < -10 then
        print("For complexity level " .. complexity .. ", the Instrumentation approach is significantly faster")
    elseif approach_diff > 10 then
        print("For complexity level " .. complexity .. ", the Debug Hook approach is significantly faster")
    else
        print("For complexity level " .. complexity .. ", both approaches have similar performance")
    end
end
```

## Using the Benchmark Module in Test Files

```lua
local firmo = require("firmo")
local benchmark = require("lib.tools.benchmark")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Register benchmark with firmo
benchmark.register_with_firmo(firmo)

describe("Performance tests", function()
  -- Function to create a large table
  local function create_large_table(size)
    local tbl = {}
    for i = 1, size do
      tbl[i] = i
    end
    return tbl
  end
  
  -- Function to sum all values in a table
  local function sum_table_loop(tbl)
    local sum = 0
    for i = 1, #tbl do
      sum = sum + tbl[i]
    end
    return sum
  end
  
  -- Function to sum using ipairs
  local function sum_table_ipairs(tbl)
    local sum = 0
    for _, v in ipairs(tbl) do
      sum = sum + v
    end
    return sum
  end
  
  it("should measure and compare table summing approaches", function()
    -- Create test data
    local test_data = create_large_table(10000)
    
    -- Benchmark different approaches
    local loop_result = firmo.benchmark.measure(sum_table_loop, {test_data}, {
      iterations = 10,
      label = "Sum with loop"
    })
    
    local ipairs_result = firmo.benchmark.measure(sum_table_ipairs, {test_data}, {
      iterations = 10,
      label = "Sum with ipairs"
    })
    
    -- Compare results
    local comparison = firmo.benchmark.compare(loop_result, ipairs_result)
    
    -- Make assertions about performance
    if comparison.faster == "Sum with loop" then
      expect(comparison.time_percent).to.be_greater_than(5)
      print("Direct loop is faster by " .. string.format("%.1f%%", comparison.time_percent))
    else
      expect(comparison.time_percent).to.be_greater_than(1)
      print("ipairs is faster by " .. string.format("%.1f%%", comparison.time_percent))
    end
  end)
  
  it("should ensure optimized operations meet performance thresholds", function()
    -- Measure a critical operation
    local result = firmo.benchmark.measure(function()
      local result = 0
      for i = 1, 100000 do
        result = result + i
      end
      return result
    end, nil, {iterations = 5})
    
    -- Assert performance meets requirements
    expect(result.time_stats.mean).to.be_less_than(0.1)
    expect(result.memory_stats.mean).to.be_less_than(10)
  end)
end)
```

These examples demonstrate a wide range of use cases for the benchmark module, from simple function timing to complex real-world scenarios and performance-based testing.