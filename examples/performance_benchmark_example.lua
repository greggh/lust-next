#!/usr/bin/env lua
-- Performance benchmark example for firmo

local firmo = require("firmo")

print("firmo Performance Benchmark Example")
print("--------------------------------------")

-----------------------------------------------------------------------------
-- Embedded benchmark module
-----------------------------------------------------------------------------
local benchmark = {}

-- Default configuration
benchmark.options = {
  iterations = 5, -- Default iterations for each benchmark
  warmup = 1, -- Warmup iterations
  precision = 6, -- Decimal precision for times
  report_memory = true, -- Report memory usage
  report_stats = true, -- Report statistical information
  gc_before = true, -- Force GC before benchmarks
  include_warmup = false, -- Include warmup iterations in results
}

-- Return high-resolution time (with nanosecond precision if available)
local has_socket, socket = pcall(require, "socket")
local has_ffi = pcall(require, "ffi") -- FFI availability check, but we don't need the module itself

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
    variance = variance + (time - mean) ^ 2
  end
  variance = variance / #measurements
  local std_dev = math.sqrt(variance)

  return {
    mean = mean,
    min = min,
    max = max,
    std_dev = std_dev,
    count = #measurements,
    total = sum,
  }
end

-- Deep table clone helper
local function deep_clone(t)
  if type(t) ~= "table" then
    return t
  end
  local copy = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
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
    warmup = warmup,
  }

  -- Warmup phase
  for _ = 1, warmup do
    if gc_before then
      collectgarbage("collect")
    end

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
  for _ = 1, iterations do
    if gc_before then
      collectgarbage("collect")
    end

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
    benchmarks = { benchmark1, benchmark2 },
    time_ratio = time_ratio,
    memory_ratio = memory_ratio,
    faster = time_ratio < 1 and label1 or label2,
    less_memory = memory_ratio < 1 and label1 or label2,
    time_percent = time_ratio < 1 and (1 - time_ratio) * 100 or (time_ratio - 1) * 100,
    memory_percent = memory_ratio < 1 and (1 - memory_ratio) * 100 or (memory_ratio - 1) * 100,
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
    print(
      string.format(
        "  %s is %.1f%% %s",
        comparison.faster,
        comparison.time_percent,
        time_ratio < 1 and "faster" or "slower"
      )
    )

    print("\nMemory Usage:")
    print(string.format("  %s: %.2f KB", label1, benchmark1.memory_stats.mean))
    print(string.format("  %s: %.2f KB", label2, benchmark2.memory_stats.mean))
    print(string.format("  Ratio: %.2fx", memory_ratio))
    print(
      string.format(
        "  %s uses %.1f%% %s memory",
        comparison.less_memory,
        comparison.memory_percent,
        memory_ratio < 1 and "less" or "more"
      )
    )

    print(string.rep("-", 80))
  end

  return comparison
end

-- Print benchmark results
function benchmark.print_result(result, options)
  options = options or {}
  -- Extract configuration options with defaults
  local report_memory = (options.report_memory ~= nil) and options.report_memory or benchmark.options.report_memory
  local report_stats = (options.report_stats ~= nil) and options.report_stats or benchmark.options.report_stats

  -- Note: label is not currently used but might be in a future version
  -- local label = result.label or "Benchmark"

  -- Basic execution time
  print(string.format("  Mean execution time: %s", format_time(result.time_stats.mean)))

  if report_stats then
    print(string.format("  Min: %s  Max: %s", format_time(result.time_stats.min), format_time(result.time_stats.max)))
    print(
      string.format(
        "  Std Dev: %s (%.1f%%)",
        format_time(result.time_stats.std_dev),
        (result.time_stats.std_dev / result.time_stats.mean) * 100
      )
    )
  end

  -- Memory stats
  if report_memory then
    print(string.format("  Mean memory delta: %.2f KB", result.memory_stats.mean))

    if report_stats then
      print(string.format("  Memory Min: %.2f KB  Max: %.2f KB", result.memory_stats.min, result.memory_stats.max))
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

  -- Load filesystem module
  local fs_ok, fs = pcall(require, "lib.tools.filesystem")
  if not fs_ok then
    error("Filesystem module required for generate_large_test_suite")
    return nil
  end

  -- Ensure output directory exists
  local dir_success, dir_err = fs.ensure_directory_exists(output_dir)
  if not dir_success then
    error("Failed to create output directory: " .. (dir_err or "unknown error"))
    return nil
  end

  -- Create test files
  for i = 1, file_count do
    local file_path = fs.join_paths(output_dir, "test_" .. i .. ".lua")

    -- Build file content
    local content = "-- Generated large test suite file #" .. i .. "\n"
    content = content .. "local firmo = require('firmo')\n"
    content = content .. "local describe, it, expect = firmo.describe, firmo.it, firmo.expect\n\n"

    -- Create nested tests
    local function generate_tests(level, prefix)
      if level <= 0 then
        return ""
      end

      local tests_at_level = level == nesting_level and tests_per_file or math.ceil(tests_per_file / level)
      local result = ""

      for j = 1, tests_at_level do
        if level == nesting_level then
          -- Leaf test case
          result = result .. string.rep("  ", nesting_level - level)
          result = result .. "it('test " .. prefix .. "." .. j .. "', function()\n"
          result = result .. string.rep("  ", nesting_level - level + 1)
          result = result .. "expect(1 + 1).to.equal(2)\n"
          result = result .. string.rep("  ", nesting_level - level)
          result = result .. "end)\n\n"
        else
          -- Nested describe block
          result = result .. string.rep("  ", nesting_level - level)
          result = result .. "describe('suite " .. prefix .. "." .. j .. "', function()\n"
          result = result .. generate_tests(level - 1, prefix .. "." .. j)
          result = result .. string.rep("  ", nesting_level - level)
          result = result .. "end)\n\n"
        end
      end

      return result
    end

    -- Start the top level describe block
    content = content .. "describe('benchmark test file " .. i .. "', function()\n"
    content = content .. generate_tests(nesting_level, i)
    content = content .. "end)\n"

    -- Write file
    local success, err = fs.write_file(file_path, content)
    if not success then
      print("Error: Failed to create test file " .. file_path .. ": " .. (err or "unknown error"))
    end
  end

  print(
    "Generated "
      .. file_count
      .. " test files with approximately "
      .. (file_count * tests_per_file)
      .. " total tests in "
      .. output_dir
  )

  return {
    output_dir = output_dir,
    file_count = file_count,
    tests_per_file = tests_per_file,
    total_tests = file_count * tests_per_file,
  }
end

-----------------------------------------------------------------------------
-- Embedded module_reset module
-----------------------------------------------------------------------------
local module_reset = {
  -- Default configuration
  reset_modules = true,
  verbose = false,

  -- Configure isolation options for firmo
  configure = function(self, options)
    options = options or {}
    self.reset_modules = options.reset_modules ~= nil and options.reset_modules or true
    self.verbose = options.verbose ~= nil and options.verbose or false
  end,
}

-- Register the modules with firmo
benchmark.register_with_firmo = function(firmo)
  -- Add benchmarking capabilities to firmo
  firmo.benchmark = benchmark
  return firmo
end

module_reset.register_with_firmo = function(firmo)
  -- Add module reset capabilities to firmo
  firmo.module_reset = module_reset
  return firmo
end

-- Register the modules with firmo
benchmark.register_with_firmo(firmo)
module_reset.register_with_firmo(firmo)

-- Create directories for benchmarks
local small_suite_dir = "/tmp/firmo_benchmark_small"
local large_suite_dir = "/tmp/firmo_benchmark_large"

-- Ensure benchmark directories exist
local fs = require("lib.tools.filesystem")
fs.ensure_directory_exists(small_suite_dir)
fs.ensure_directory_exists(large_suite_dir)

-- Generate test suites for benchmarking
print("\nGenerating test suites for benchmarking...")

local small_suite = firmo.benchmark.generate_large_test_suite({
  file_count = 5,
  tests_per_file = 10,
  output_dir = small_suite_dir,
})

local large_suite = firmo.benchmark.generate_large_test_suite({
  file_count = 20,
  tests_per_file = 30,
  output_dir = large_suite_dir,
})

print("Generated test suites:")
print(
  "  Small suite: "
    .. small_suite.file_count
    .. " files with "
    .. small_suite.tests_per_file
    .. " tests each ("
    .. small_suite.total_tests
    .. " total tests)"
)
print(
  "  Large suite: "
    .. large_suite.file_count
    .. " files with "
    .. large_suite.tests_per_file
    .. " tests each ("
    .. large_suite.total_tests
    .. " total tests)"
)

-- Define benchmark functions
-- Track if module_reset is loaded
local module_reset_loaded = firmo.module_reset ~= nil

local function run_tests_with_isolation(suite_dir, iterations)
  collectgarbage("collect")

  if module_reset_loaded then
    firmo.module_reset.configure({
      reset_modules = true,
      verbose = false,
    })
  end

  -- Get all test files using filesystem module
  local files = {}

  -- Find all Lua files in the directory
  local all_files = fs.scan_directory(suite_dir, false) -- non-recursive

  -- Filter for .lua files
  for _, file in ipairs(all_files or {}) do
    if file:match("%.lua$") then
      table.insert(files, file)
    end
  end

  -- Limit files to iterations (for quicker benchmarks)
  local limited_files = {}
  for i = 1, math.min(iterations, #files) do
    table.insert(limited_files, files[i])
  end

  -- Run each test file
  for _, file in ipairs(limited_files) do
    firmo.reset()
    dofile(file)
  end
end

local function run_tests_without_isolation(suite_dir, iterations)
  collectgarbage("collect")

  if module_reset_loaded then
    firmo.module_reset.configure({
      reset_modules = false,
      verbose = false,
    })
  end

  -- Get all test files using filesystem module
  local files = {}

  -- Find all Lua files in the directory
  local all_files = fs.scan_directory(suite_dir, false) -- non-recursive

  -- Filter for .lua files
  for _, file in ipairs(all_files or {}) do
    if file:match("%.lua$") then
      table.insert(files, file)
    end
  end

  -- Limit files to iterations (for quicker benchmarks)
  local limited_files = {}
  for i = 1, math.min(iterations, #files) do
    table.insert(limited_files, files[i])
  end

  -- Run each test file
  for _, file in ipairs(limited_files) do
    firmo.reset()
    dofile(file)
  end
end

-- Benchmark options
local options = {
  warmup = 1, -- Warmup iterations
  iterations = 3, -- Main iterations
  report_memory = true,
}

-- Run benchmarks
print("\nRunning benchmarks...")

-- Small suite benchmarks
print("\n== Small Test Suite Benchmarks ==")

local small_with_isolation = firmo.benchmark.measure(
  run_tests_with_isolation,
  { small_suite_dir, small_suite.file_count },
  {
    label = "Small suite with isolation",
    iterations = options.iterations,
    warmup = options.warmup,
  }
)

local small_without_isolation = firmo.benchmark.measure(
  run_tests_without_isolation,
  { small_suite_dir, small_suite.file_count },
  {
    label = "Small suite without isolation",
    iterations = options.iterations,
    warmup = options.warmup,
  }
)

-- Compare results
local small_comparison = firmo.benchmark.compare(small_with_isolation, small_without_isolation)

-- Large suite benchmarks
print("\n== Large Test Suite Benchmarks ==")

local large_with_isolation = firmo.benchmark.measure(
  run_tests_with_isolation,
  { large_suite_dir, 5 }, -- Only run 5 files for large suite to keep example quick
  {
    label = "Large suite with isolation",
    iterations = options.iterations,
    warmup = options.warmup,
  }
)

local large_without_isolation = firmo.benchmark.measure(
  run_tests_without_isolation,
  { large_suite_dir, 5 }, -- Only run 5 files for large suite to keep example quick
  {
    label = "Large suite without isolation",
    iterations = options.iterations,
    warmup = options.warmup,
  }
)

-- Compare results
local large_comparison = firmo.benchmark.compare(large_with_isolation, large_without_isolation)

-- Summary
print("\n== Performance Summary ==")
print("1. Module Isolation Performance:")
print("   - Small suite overhead: " .. string.format("%.1f%%", small_comparison.time_percent))
print("   - Large suite overhead: " .. string.format("%.1f%%", large_comparison.time_percent))
print("   - Memory usage impact: " .. string.format("%.1f%%", large_comparison.memory_percent))

print("\n2. Recommendations:")
if large_comparison.time_percent < 20 then
  print("   - Use module isolation by default for better test reliability")
  print("   - The overhead is minimal and worth the improved test isolation")
elseif large_comparison.time_percent < 50 then
  print("   - Consider using module isolation for critical tests")
  print("   - The overhead is moderate but may be acceptable for better reliability")
else
  print("   - Use module isolation selectively for tests that need it")
  print("   - The overhead is significant, so consider optimizing your modules")
end

-- Clean up benchmark directories
fs.delete_directory(small_suite_dir, true) -- true means recursive deletion
fs.delete_directory(large_suite_dir, true)

print("\nBenchmark complete!")
