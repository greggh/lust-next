-- Benchmarking module for lust-next
-- Provides utilities for measuring and analyzing test performance

local benchmark = {}

-- Default configuration
benchmark.options = {
  iterations = 5,        -- Default iterations for each benchmark
  warmup = 1,            -- Warmup iterations
  precision = 6,         -- Decimal precision for times
  report_memory = true,  -- Report memory usage
  report_stats = true,   -- Report statistical information
  gc_before = true,      -- Force GC before benchmarks
  include_warmup = false -- Include warmup iterations in results
}

-- Return high-resolution time (with nanosecond precision if available)
local has_socket, socket = pcall(require, "socket")
local has_ffi, ffi = pcall(require, "ffi")

local function high_res_time()
  if has_socket then
    return socket.gettime()
  elseif has_ffi then
    -- Use os.clock() as a fallback
    return os.clock()
  else
    -- If neither is available, use os.time() (low precision)
    return os.time()
  end
end

-- Format time value with proper units
local function format_time(time_seconds)
  if time_seconds < 0.000001 then
    return string.format("%.2f ns", time_seconds * 1e9)
  elseif time_seconds < 0.001 then
    return string.format("%.2f µs", time_seconds * 1e6)
  elseif time_seconds < 1 then
    return string.format("%.2f ms", time_seconds * 1e3)
  else
    return string.format("%.4f s", time_seconds)
  end
end

-- Calculate stats from a set of measurements
local function calculate_stats(measurements)
  local sum = 0
  local min = math.huge
  local max = -math.huge
  
  for _, time in ipairs(measurements) do
    sum = sum + time
    min = math.min(min, time)
    max = math.max(max, time)
  end
  
  local mean = sum / #measurements
  
  -- Calculate standard deviation
  local variance = 0
  for _, time in ipairs(measurements) do
    variance = variance + (time - mean)^2
  end
  variance = variance / #measurements
  local std_dev = math.sqrt(variance)
  
  return {
    mean = mean,
    min = min,
    max = max,
    std_dev = std_dev,
    count = #measurements,
    total = sum
  }
end

-- Deep table clone helper
local function deep_clone(t)
  if type(t) ~= 'table' then return t end
  local copy = {}
  for k, v in pairs(t) do
    if type(v) == 'table' then
      copy[k] = deep_clone(v)
    else
      copy[k] = v
    end
  end
  return copy
end

-- Measure function execution time
function benchmark.measure(func, args, options)
  options = options or {}
  local iterations = options.iterations or benchmark.options.iterations
  local warmup = options.warmup or benchmark.options.warmup
  local gc_before = options.gc_before or benchmark.options.gc_before
  local include_warmup = options.include_warmup or benchmark.options.include_warmup
  local label = options.label or "Benchmark"
  
  if not func or type(func) ~= "function" then
    error("benchmark.measure requires a function to benchmark")
  end
  
  -- Clone arguments to ensure consistent state between runs
  local args_clone = args and deep_clone(args) or {}
  
  -- Prepare results container
  local results = {
    times = {},
    memory = {},
    label = label,
    iterations = iterations,
    warmup = warmup
  }
  
  -- Warmup phase
  for i = 1, warmup do
    if gc_before then collectgarbage("collect") end
    
    -- Measure warmup execution
    local start_time = high_res_time()
    local start_memory = collectgarbage("count")
    
    -- Execute function with arguments
    func(table.unpack(args_clone))
    
    local end_time = high_res_time()
    local end_memory = collectgarbage("count")
    
    -- Store results if including warmup
    if include_warmup then
      table.insert(results.times, end_time - start_time)
      table.insert(results.memory, end_memory - start_memory)
    end
  end
  
  -- Main benchmark phase
  for i = 1, iterations do
    if gc_before then collectgarbage("collect") end
    
    -- Measure execution
    local start_time = high_res_time()
    local start_memory = collectgarbage("count")
    
    -- Execute function with arguments
    func(table.unpack(args_clone))
    
    local end_time = high_res_time()
    local end_memory = collectgarbage("count")
    
    -- Store results
    table.insert(results.times, end_time - start_time)
    table.insert(results.memory, end_memory - start_memory)
  end
  
  -- Calculate statistics
  results.time_stats = calculate_stats(results.times)
  results.memory_stats = calculate_stats(results.memory)
  
  return results
end

-- Run a suite of benchmarks
function benchmark.suite(suite_def, options)
  options = options or {}
  local suite_name = suite_def.name or "Benchmark Suite"
  local benchmarks = suite_def.benchmarks or {}
  
  -- Prepare results container
  local results = {
    name = suite_name,
    benchmarks = {},
    start_time = os.time(),
    options = deep_clone(options)
  }
  
  -- Print header
  print("\n" .. string.rep("-", 80))
  print("Running benchmark suite: " .. suite_name)
  print(string.rep("-", 80))
  
  -- Run each benchmark
  for _, benchmark_def in ipairs(benchmarks) do
    local name = benchmark_def.name or "Unnamed benchmark"
    local func = benchmark_def.func
    local args = benchmark_def.args or {}
    
    -- Merge suite options with benchmark options
    local bench_options = deep_clone(options)
    for k, v in pairs(benchmark_def.options or {}) do
      bench_options[k] = v
    end
    bench_options.label = name
    
    print("\nRunning: " .. name)
    
    -- Execute the benchmark
    local benchmark_result = benchmark.measure(func, args, bench_options)
    table.insert(results.benchmarks, benchmark_result)
    
    -- Print results
    benchmark.print_result(benchmark_result)
  end
  
  -- Complete the suite
  results.end_time = os.time()
  results.duration = results.end_time - results.start_time
  
  -- Print suite summary
  print("\n" .. string.rep("-", 80))
  print("Suite complete: " .. suite_name)
  print("Total runtime: " .. results.duration .. " seconds")
  print(string.rep("-", 80))
  
  return results
end

-- Comparison function for benchmarks
function benchmark.compare(benchmark1, benchmark2, options)
  options = options or {}
  
  if not benchmark1 or not benchmark2 then
    error("benchmark.compare requires two benchmark results to compare")
  end
  
  local label1 = benchmark1.label or "Benchmark 1"
  local label2 = benchmark2.label or "Benchmark 2"
  
  -- Calculate comparison
  local time_ratio = benchmark1.time_stats.mean / benchmark2.time_stats.mean
  local memory_ratio = benchmark1.memory_stats.mean / benchmark2.memory_stats.mean
  
  local comparison = {
    benchmarks = {benchmark1, benchmark2},
    time_ratio = time_ratio,
    memory_ratio = memory_ratio,
    faster = time_ratio < 1 and label1 or label2,
    less_memory = memory_ratio < 1 and label1 or label2,
    time_percent = time_ratio < 1 
      and (1 - time_ratio) * 100 
      or (time_ratio - 1) * 100,
    memory_percent = memory_ratio < 1
      and (1 - memory_ratio) * 100
      or (memory_ratio - 1) * 100
  }
  
  -- Print comparison
  if not options.silent then
    print("\n" .. string.rep("-", 80))
    print("Benchmark Comparison: " .. label1 .. " vs " .. label2)
    print(string.rep("-", 80))
    
    print("\nExecution Time:")
    print(string.format("  %s: %s", label1, format_time(benchmark1.time_stats.mean)))
    print(string.format("  %s: %s", label2, format_time(benchmark2.time_stats.mean)))
    print(string.format("  Ratio: %.2fx", time_ratio))
    print(string.format("  %s is %.1f%% %s", 
      comparison.faster,
      comparison.time_percent,
      time_ratio < 1 and "faster" or "slower"
    ))
    
    print("\nMemory Usage:")
    print(string.format("  %s: %.2f KB", label1, benchmark1.memory_stats.mean))
    print(string.format("  %s: %.2f KB", label2, benchmark2.memory_stats.mean))
    print(string.format("  Ratio: %.2fx", memory_ratio))
    print(string.format("  %s uses %.1f%% %s memory", 
      comparison.less_memory,
      comparison.memory_percent,
      memory_ratio < 1 and "less" or "more"
    ))
    
    print(string.rep("-", 80))
  end
  
  return comparison
end

-- Print benchmark results
function benchmark.print_result(result, options)
  options = options or {}
  local precision = options.precision or benchmark.options.precision
  local report_memory = options.report_memory !== nil and options.report_memory or benchmark.options.report_memory
  local report_stats = options.report_stats !== nil and options.report_stats or benchmark.options.report_stats
  
  local label = result.label or "Benchmark"
  
  -- Basic execution time
  print(string.format("  Mean execution time: %s", format_time(result.time_stats.mean)))
  
  if report_stats then
    print(string.format("  Min: %s  Max: %s", 
      format_time(result.time_stats.min), 
      format_time(result.time_stats.max)
    ))
    print(string.format("  Std Dev: %s (%.1f%%)", 
      format_time(result.time_stats.std_dev),
      (result.time_stats.std_dev / result.time_stats.mean) * 100
    ))
  end
  
  -- Memory stats
  if report_memory then
    print(string.format("  Mean memory delta: %.2f KB", result.memory_stats.mean))
    
    if report_stats then
      print(string.format("  Memory Min: %.2f KB  Max: %.2f KB", 
        result.memory_stats.min, 
        result.memory_stats.max
      ))
    end
  end
end

-- Generate benchmark data for large test suites
function benchmark.generate_large_test_suite(options)
  options = options or {}
  local file_count = options.file_count or 100
  local tests_per_file = options.tests_per_file or 50
  local nesting_level = options.nesting_level or 3
  local output_dir = options.output_dir or "./benchmark_tests"
  
  -- Ensure output directory exists
  os.execute("mkdir -p " .. output_dir)
  
  -- Create test files
  for i = 1, file_count do
    local file_path = output_dir .. "/test_" .. i .. ".lua"
    local file = io.open(file_path, "w")
    
    if file then
      -- Write test file header
      file:write("-- Generated large test suite file #" .. i .. "\n")
      file:write("local lust = require('lust-next')\n")
      file:write("local describe, it, expect = lust.describe, lust.it, lust.expect\n\n")
      
      -- Create nested tests
      local function generate_tests(level, prefix)
        if level <= 0 then return end
        
        local tests_at_level = level == nesting_level and tests_per_file or math.ceil(tests_per_file / level)
        
        for j = 1, tests_at_level do
          if level == nesting_level then
            -- Leaf test case
            file:write(string.rep("  ", nesting_level - level))
            file:write("it('test " .. prefix .. "." .. j .. "', function()\n")
            file:write(string.rep("  ", nesting_level - level + 1))
            file:write("expect(1 + 1).to.equal(2)\n")
            file:write(string.rep("  ", nesting_level - level))
            file:write("end)\n\n")
          else
            -- Nested describe block
            file:write(string.rep("  ", nesting_level - level))
            file:write("describe('suite " .. prefix .. "." .. j .. "', function()\n")
            generate_tests(level - 1, prefix .. "." .. j)
            file:write(string.rep("  ", nesting_level - level))
            file:write("end)\n\n")
          end
        end
      end
      
      -- Start the top level describe block
      file:write("describe('benchmark test file " .. i .. "', function()\n")
      generate_tests(nesting_level, i)
      file:write("end)\n")
      
      file:close()
    else
      print("Error: Failed to create test file " .. file_path)
    end
  end
  
  print("Generated " .. file_count .. " test files with approximately " .. 
        (file_count * tests_per_file) .. " total tests in " .. output_dir)
  
  return {
    output_dir = output_dir,
    file_count = file_count,
    tests_per_file = tests_per_file,
    total_tests = file_count * tests_per_file
  }
end

-- Register the module with lust-next
function benchmark.register_with_lust(lust_next)
  -- Store reference to lust-next
  benchmark.lust_next = lust_next
  
  -- Add benchmarking capabilities to lust_next
  lust_next.benchmark = benchmark
  
  return lust_next
end

return benchmark