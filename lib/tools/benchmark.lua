-- Benchmarking module for lust-next
-- Provides utilities for measuring and analyzing test performance

local benchmark = {}
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("benchmark")
logging.configure_from_config("benchmark")

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
  
  -- Log suite start
  logger.info("Running benchmark suite", {name = suite_name})
  
  -- Print header for console output
  if not options.quiet then
    io.write("\n" .. string.rep("-", 80) .. "\n")
    io.write("Running benchmark suite: " .. suite_name .. "\n")
    io.write(string.rep("-", 80) .. "\n")
  end
  
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
    
    -- Log benchmark start
    logger.debug("Running benchmark", {name = name})
    
    -- Print to console if not quiet
    if not options.quiet then
      io.write("\nRunning: " .. name .. "\n")
    end
    
    -- Execute the benchmark
    local benchmark_result = benchmark.measure(func, args, bench_options)
    table.insert(results.benchmarks, benchmark_result)
    
    -- Print results
    benchmark.print_result(benchmark_result)
  end
  
  -- Complete the suite
  results.end_time = os.time()
  results.duration = results.end_time - results.start_time
  
  -- Log suite completion
  logger.info("Benchmark suite completed", {
    name = suite_name,
    duration_seconds = results.duration,
    benchmark_count = #results.benchmarks
  })
  
  -- Print suite summary to console if not quiet
  if not options.quiet then
    io.write("\n" .. string.rep("-", 80) .. "\n")
    io.write("Suite complete: " .. suite_name .. "\n")
    io.write("Total runtime: " .. results.duration .. " seconds\n")
    io.write(string.rep("-", 80) .. "\n")
  end
  
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
  
  -- Log comparison results
  logger.info("Benchmark comparison", {
    benchmark1 = label1,
    benchmark2 = label2,
    time_ratio = time_ratio,
    memory_ratio = memory_ratio,
    faster = comparison.faster,
    time_percent = comparison.time_percent,
    less_memory = comparison.less_memory,
    memory_percent = comparison.memory_percent
  })
  
  -- Print comparison to console if not silent
  if not options.silent then
    io.write("\n" .. string.rep("-", 80) .. "\n")
    io.write("Benchmark Comparison: " .. label1 .. " vs " .. label2 .. "\n")
    io.write(string.rep("-", 80) .. "\n")
    
    io.write("\nExecution Time:\n")
    io.write(string.format("  %s: %s\n", label1, format_time(benchmark1.time_stats.mean)))
    io.write(string.format("  %s: %s\n", label2, format_time(benchmark2.time_stats.mean)))
    io.write(string.format("  Ratio: %.2fx\n", time_ratio))
    io.write(string.format("  %s is %.1f%% %s\n", 
      comparison.faster,
      comparison.time_percent,
      time_ratio < 1 and "faster" or "slower"
    ))
    
    io.write("\nMemory Usage:\n")
    io.write(string.format("  %s: %.2f KB\n", label1, benchmark1.memory_stats.mean))
    io.write(string.format("  %s: %.2f KB\n", label2, benchmark2.memory_stats.mean))
    io.write(string.format("  Ratio: %.2fx\n", memory_ratio))
    io.write(string.format("  %s uses %.1f%% %s memory\n", 
      comparison.less_memory,
      comparison.memory_percent,
      memory_ratio < 1 and "less" or "more"
    ))
    
    io.write(string.rep("-", 80) .. "\n")
  end
  
  return comparison
end

-- Print benchmark results
function benchmark.print_result(result, options)
  options = options or {}
  local precision = options.precision or benchmark.options.precision
  local report_memory = options.report_memory ~= nil and options.report_memory or benchmark.options.report_memory
  local report_stats = options.report_stats ~= nil and options.report_stats or benchmark.options.report_stats
  local quiet = options.quiet or false
  
  local label = result.label or "Benchmark"
  
  -- Log benchmark results
  logger.debug("Benchmark result", {
    label = label,
    mean_time_seconds = result.time_stats.mean,
    min_time_seconds = result.time_stats.min,
    max_time_seconds = result.time_stats.max,
    std_dev_seconds = result.time_stats.std_dev,
    mean_memory_kb = result.memory_stats.mean,
    min_memory_kb = result.memory_stats.min,
    max_memory_kb = result.memory_stats.max
  })
  
  -- If quiet mode, don't print to console
  if quiet then return end
  
  -- Basic execution time
  io.write(string.format("  Mean execution time: %s\n", format_time(result.time_stats.mean)))
  
  if report_stats then
    io.write(string.format("  Min: %s  Max: %s\n", 
      format_time(result.time_stats.min), 
      format_time(result.time_stats.max)
    ))
    io.write(string.format("  Std Dev: %s (%.1f%%)\n", 
      format_time(result.time_stats.std_dev),
      (result.time_stats.std_dev / result.time_stats.mean) * 100
    ))
  end
  
  -- Memory stats
  if report_memory then
    io.write(string.format("  Mean memory delta: %.2f KB\n", result.memory_stats.mean))
    
    if report_stats then
      io.write(string.format("  Memory Min: %.2f KB  Max: %.2f KB\n", 
        result.memory_stats.min, 
        result.memory_stats.max
      ))
    end
  end
end

-- Load the filesystem module
local fs = require("lib.tools.filesystem")
logger.debug("Filesystem module loaded successfully", {
  version = fs._VERSION
})

-- Generate benchmark data for large test suites
function benchmark.generate_large_test_suite(options)
  options = options or {}
  local file_count = options.file_count or 100
  local tests_per_file = options.tests_per_file or 50
  local nesting_level = options.nesting_level or 3
  local output_dir = options.output_dir or "./benchmark_tests"
  
  logger.debug("Generating benchmark test suite", {
    file_count = file_count,
    tests_per_file = tests_per_file,
    nesting_level = nesting_level,
    output_dir = output_dir
  })
  
  -- Ensure output directory exists
  local success, err = fs.ensure_directory_exists(output_dir)
  if not success then
    logger.error("Failed to create output directory", {
      directory = output_dir,
      error = err
    })
    return nil, "Failed to create output directory: " .. (err or "unknown error")
  end
  
  -- Create test files
  for i = 1, file_count do
    local file_path = fs.join_paths(output_dir, "test_" .. i .. ".lua")
    
    -- Generate the test file content
    local content = "-- Generated large test suite file #" .. i .. "\n" ..
                   "local lust = require('lust-next')\n" ..
                   "local describe, it, expect = lust.describe, lust.it, lust.expect\n\n"
    
    -- Create nested tests
    local function generate_tests(level, prefix)
      if level <= 0 then return "" end
      
      local tests_at_level = level == nesting_level and tests_per_file or math.ceil(tests_per_file / level)
      local test_content = ""
      
      for j = 1, tests_at_level do
        if level == nesting_level then
          -- Leaf test case
          test_content = test_content .. string.rep("  ", nesting_level - level)
          test_content = test_content .. "it('test " .. prefix .. "." .. j .. "', function()\n"
          test_content = test_content .. string.rep("  ", nesting_level - level + 1)
          test_content = test_content .. "expect(1 + 1).to.equal(2)\n"
          test_content = test_content .. string.rep("  ", nesting_level - level)
          test_content = test_content .. "end)\n\n"
        else
          -- Nested describe block
          test_content = test_content .. string.rep("  ", nesting_level - level)
          test_content = test_content .. "describe('suite " .. prefix .. "." .. j .. "', function()\n"
          test_content = test_content .. generate_tests(level - 1, prefix .. "." .. j)
          test_content = test_content .. string.rep("  ", nesting_level - level)
          test_content = test_content .. "end)\n\n"
        end
      end
      
      return test_content
    end
    
    -- Start the top level describe block
    content = content .. "describe('benchmark test file " .. i .. "', function()\n"
    content = content .. generate_tests(nesting_level, i)
    content = content .. "end)\n"
    
    -- Write the file
    logger.debug("Writing benchmark test file", {
      file_path = file_path,
      content_size = #content
    })
    
    local success = fs.write_file(file_path, content)
    
    if not success then
      logger.error("Failed to create test file", {path = file_path})
    end
  end
  
  -- Log test generation results
  logger.info("Generated test files for benchmark", {
    file_count = file_count,
    test_count = file_count * tests_per_file,
    output_dir = output_dir
  })
  
  -- Print to console if not silent
  if not options.silent then
    io.write("Generated " .. file_count .. " test files with approximately " .. 
          (file_count * tests_per_file) .. " total tests in " .. output_dir .. "\n")
  end
  
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