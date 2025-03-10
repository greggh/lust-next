#!/usr/bin/env lua
-- Enhanced test runner for lust-next that runs individual test files
-- properly handling module isolation to prevent cross-test interference

local lust_next = require("lust-next")

-- Initialize logging system
local logging
local ok, err = pcall(function() logging = require("lib.tools.logging") end)
if not ok or not logging then
  -- Fall back to standard print if logging module isn't available
  logging = {
    configure = function() end,
    get_logger = function() return {
      info = print,
      error = print,
      warn = print,
      debug = print,
      verbose = print
    } end
  }
end

-- Get logger for run_all_tests module
local logger = logging.get_logger("run_all_tests")
-- Configure from config if possible
logging.configure_from_config("run_all_tests")

logger.info("Starting test runner", {framework = "lust-next"})

-- Try to load module_reset for enhanced isolation
local module_reset_loaded, module_reset = pcall(require, "lib.core.module_reset")
if module_reset_loaded then
  logger.info("Module reset system loaded", {feature = "enhanced test isolation"})
  module_reset.register_with_lust(lust_next)
  
  -- Configure isolation options
  module_reset.configure({
    reset_modules = true,
    verbose = false
  })
else
  logger.warn("Module reset system unavailable", {fallback = "using basic isolation"})
end

-- Try to load benchmark module for performance reporting
local benchmark_loaded, benchmark = pcall(require, "lib.tools.benchmark")
if benchmark_loaded then
  benchmark.register_with_lust(lust_next)
end

-- Get command-line arguments
local args = {...}
local options = {
  verbose = false,    -- Verbose output
  memory = false,     -- Track memory usage
  performance = false,-- Show performance stats
  order = "name",     -- Test file order (name, natural, none)
  filter = nil,       -- Filter pattern for test files
  coverage = false,   -- Enable coverage tracking
  coverage_debug = false, -- Enable debug output for coverage
  discover_uncovered = true, -- Discover files that aren't executed by tests
  quality = false,    -- Enable quality validation
  quality_level = 3   -- Quality validation level
}

-- Parse command-line arguments
for i, arg in ipairs(args) do
  if arg == "--verbose" or arg == "-v" then
    options.verbose = true
  elseif arg == "--memory" or arg == "-m" then
    options.memory = true
  elseif arg == "--performance" or arg == "-p" then
    options.performance = true
  elseif arg == "--order" and args[i+1] then
    options.order = args[i+1]
  elseif arg == "--filter" and args[i+1] then
    options.filter = args[i+1]
  elseif arg == "--coverage" or arg == "-c" then
    options.coverage = true
  elseif arg == "--coverage-debug" then
    options.coverage_debug = true
  elseif arg == "--discover-uncovered" and args[i+1] then
    options.discover_uncovered = (args[i+1] == "true" or args[i+1] == "1")
  elseif arg == "--quality" or arg == "-q" then
    options.quality = true
  elseif arg == "--quality-level" and args[i+1] then
    options.quality_level = tonumber(args[i+1]) or 3
  end
end

-- Try to load coverage module
local coverage_loaded, coverage = pcall(require, "lib.coverage")
if coverage_loaded and options.coverage then
  logger.info("Coverage module loaded", {purpose = "test coverage analysis"})
  -- Configure coverage
  coverage.init({
    enabled = true,
    discover_uncovered = options.discover_uncovered,
    debug = options.coverage_debug,
    source_dirs = {".", "lib", "src"},
    threshold = 80,
    full_reset = true  -- Start with a clean slate
  })
  
  -- Start coverage tracking
  if coverage.start then
    coverage.start()
  else
    logger.error("Function not found", {function_name = "coverage.start"})
  end
end

-- Try to load quality module
local quality_loaded, quality = pcall(require, "lib.quality")
if quality_loaded and options.quality then
  logger.info("Quality module loaded", {purpose = "test quality analysis"})
  -- Configure quality validation
  quality.init({
    enabled = true,
    level = options.quality_level,
    debug = options.verbose,
    threshold = 80
  })
end

-- Add a counter for tests
lust_next.test_stats = {
  total = 0,
  passes = 0,
  failures = 0,
  pending = 0,
  by_file = {},
  total_time = 0,
  total_memory = 0,
  start_memory = collectgarbage("count")
}

-- Patch lust_next.it to keep track of test counts
local original_it = lust_next.it
lust_next.it = function(name, fn, options)
  -- Get the source location to track which file this test is from
  local info = debug.getinfo(2, "S")
  local file = info.source:match("@(.+)") or info.source
  local file_name = file:match("([^/\\]+)%.lua$") or file
  
  -- Initialize file stats if needed
  if not lust_next.test_stats.by_file[file_name] then
    lust_next.test_stats.by_file[file_name] = {
      total = 0,
      passes = 0,
      failures = 0,
      pending = 0
    }
  end
  
  -- Wrap the function to track pass/fail status
  local wrapped_fn = nil
  if type(fn) == "function" then
    wrapped_fn = function(...)
      lust_next.test_stats.total = lust_next.test_stats.total + 1
      lust_next.test_stats.by_file[file_name].total = lust_next.test_stats.by_file[file_name].total + 1
      
      -- Handle excluded tests
      if options and options.excluded then
        lust_next.test_stats.pending = lust_next.test_stats.pending + 1
        lust_next.test_stats.by_file[file_name].pending = lust_next.test_stats.by_file[file_name].pending + 1
        return fn(...)
      end
      
      -- Count test results
      local success, result = pcall(fn, ...)
      if success then
        lust_next.test_stats.passes = lust_next.test_stats.passes + 1
        lust_next.test_stats.by_file[file_name].passes = lust_next.test_stats.by_file[file_name].passes + 1
      else
        lust_next.test_stats.failures = lust_next.test_stats.failures + 1
        lust_next.test_stats.by_file[file_name].failures = lust_next.test_stats.by_file[file_name].failures + 1
      end
      
      if not success then
        error(result, 2) -- Re-throw the error to maintain original behavior
      end
      return result
    end
  else
    wrapped_fn = fn -- Pass through non-function values (like pending tests)
  end
  
  return original_it(name, wrapped_fn, options)
end

-- Also patch pending for proper counting
local original_pending = lust_next.pending
lust_next.pending = function(message)
  -- Get the source location
  local info = debug.getinfo(2, "S")
  local file = info.source:match("@(.+)") or info.source
  local file_name = file:match("([^/\\]+)%.lua$") or file
  
  -- Initialize file stats if needed
  if not lust_next.test_stats.by_file[file_name] then
    lust_next.test_stats.by_file[file_name] = {
      total = 0,
      passes = 0,
      failures = 0,
      pending = 0
    }
  end
  
  -- Count this pending test
  lust_next.test_stats.total = lust_next.test_stats.total + 1
  lust_next.test_stats.pending = lust_next.test_stats.pending + 1
  lust_next.test_stats.by_file[file_name].total = lust_next.test_stats.by_file[file_name].total + 1
  lust_next.test_stats.by_file[file_name].pending = lust_next.test_stats.by_file[file_name].pending + 1
  
  return original_pending(message)
end

-- Get files from tests directory
local function get_test_files()
  local command = "ls -1 tests/*.lua"
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()
  
  local files = {}
  for file in result:gmatch("([^\n]+)") do
    table.insert(files, file)
  end
  
  return files
end

-- Timing function with high precision if available
local has_socket, socket = pcall(require, "socket")
local function get_time()
  if has_socket then
    return socket.gettime()
  else
    return os.time()
  end
end

-- Count test assertions in output text
local function extract_test_counts(output)
  local passes = 0
  local failures = 0
  local pending = 0
  
  -- Parse the output for colorized test results
  -- First try to capture using a more specific pattern
  for line in output:gmatch("[^\r\n]+") do
    if line:match(".*%[32mPASS%[0m") then
      passes = passes + 1
    elseif line:match(".*%[31mFAIL%[0m") then 
      failures = failures + 1
    elseif line:match(".*%[33mPENDING:%[0m") then
      pending = pending + 1
    end
  end
  
  return {
    passes = passes,
    failures = failures,
    pending = pending,
    total = passes + failures + pending
  }
end

-- Enable debug mode
local DEBUG = false

-- Run a single test file with isolated environment
local function run_test_file(file_path)
  logger.info("Running test", {file_path = file_path})
  
  -- Memory stats before test
  local before_memory = collectgarbage("count")
  
  -- Reset lust_next state and stats before running tests
  lust_next.reset()
  
  -- Reset the test stats for this file
  local file_name = file_path:match("([^/\\]+)%.lua$") or file_path
  lust_next.test_stats.by_file[file_name] = {
    total = 0,
    passes = 0,
    failures = 0,
    pending = 0,
    file_path = file_path,
    time = 0,
    memory_delta = 0
  }
  
  -- Capture all output to count test results
  local original_print = print
  local captured_output = {}
  
  -- Override print to capture output
  _G.print = function(...)
    local args = {...}
    local line = ""
    for i, v in ipairs(args) do
      line = line .. tostring(v)
      if i < #args then line = line .. "\t" end
    end
    
    -- Check if this line has a test result marker and log for debugging
    if DEBUG then
      if line:match(".*%[32mPASS%[0m") then
        if logger.would_log("debug") then
          logger.debug("Found test result", {result = "pass", line = line})
        end
      elseif line:match(".*%[31mFAIL%[0m") then 
        if logger.would_log("debug") then
          logger.debug("Found test result", {result = "fail", line = line})
        end
      elseif line:match(".*%[33mPENDING:%[0m") then
        if logger.would_log("debug") then
          logger.debug("Found test result", {result = "pending", line = line})
        end
      end
    end
    
    table.insert(captured_output, line)
    original_print(...)
  end
  
  -- Track if this file is coverage-related
  local is_coverage_test = file_path:match("coverage_test%.lua$") ~= nil
  
  -- Special handling for coverage tests
  if is_coverage_test and coverage_loaded and options.coverage then
    if options.coverage_debug then
      logger.debug("Running coverage test file", {state = "preserving"})
    end
  end
  
  -- Time the test execution
  local start_time = get_time()
  
  -- Run the test in isolated environment
  local success, result = pcall(function()
    -- Reset lust_next state before each test file, but preserve coverage data
    -- Only reset lust-next framework state, not coverage data
    lust_next.reset()
    
    -- Load and execute the test file
    local chunk, err = loadfile(file_path)
    if not chunk then
      error("Error loading file: " .. tostring(err), 2)
    end
    
    return chunk()
  end)
  
  -- Calculate execution time
  local end_time = get_time()
  local execution_time = end_time - start_time
  
  -- Restore original print function
  _G.print = original_print
  
  -- Combine captured output
  local output = table.concat(captured_output, "\n")
  
  -- Extract test counts from output
  local counts = extract_test_counts(output)
  
  -- Force garbage collection after test
  collectgarbage("collect")
  
  -- Memory stats after test
  local after_memory = collectgarbage("count")
  local memory_delta = after_memory - before_memory
  
  -- Update total stats
  lust_next.test_stats.total_time = lust_next.test_stats.total_time + execution_time
  lust_next.test_stats.total_memory = lust_next.test_stats.total_memory + memory_delta
  
  -- Store performance metrics in file stats
  lust_next.test_stats.by_file[file_name].time = execution_time
  lust_next.test_stats.by_file[file_name].memory_delta = memory_delta
  
  -- Show performance stats if requested
  if options.performance then
    logger.info("Performance metrics", {
      execution_time_sec = string.format("%.4f", execution_time),
      memory_delta_kb = options.memory and string.format("%.2f", memory_delta) or nil
    })
  end
  
  return {
    success = success,
    result = result,
    output = output,
    counts = counts,
    file_path = file_path,
    file_name = file_path:match("([^/\\]+)%.lua$") or file_path,
    time = execution_time,
    memory_delta = memory_delta
  }
end

-- Get all test files
local test_files = get_test_files()
if #test_files == 0 then
  logger.error("No test files found", {directory = "tests/"})
  os.exit(1)
end

-- Filter test files if a pattern is provided
if options.filter then
  local filtered_files = {}
  for _, file in ipairs(test_files) do
    if file:match(options.filter) then
      table.insert(filtered_files, file)
    end
  end
  test_files = filtered_files
  logger.info("Filtered test files", {count = #test_files, pattern = options.filter})
end

-- Sort test files based on order option
if options.order == "name" then
  table.sort(test_files)
elseif options.order == "natural" then
  -- Sort by natural order (numbers in filenames sorted numerically)
  table.sort(test_files, function(a, b)
    local a_name = a:match("([^/\\]+)%.lua$") or a
    local b_name = b:match("([^/\\]+)%.lua$") or b
    
    -- Extract prefix and number
    local a_prefix, a_num = a_name:match("(.-)(%d+)$")
    local b_prefix, b_num = b_name:match("(.-)(%d+)$")
    
    if a_prefix and b_prefix and a_prefix == b_prefix then
      -- Same prefix, compare numbers
      return tonumber(a_num) < tonumber(b_num)
    else
      -- Different prefixes or no numbers, compare as strings
      return a_name < b_name
    end
  end)
end

-- Start the tests
local start_time = get_time()

-- Run all test files and collect results
local test_results = {}
local passed_files = 0
local failed_files = 0
local total_passes = 0
local total_failures = 0
local total_pending = 0

for _, file_path in ipairs(test_files) do
  local result = run_test_file(file_path)
  
  -- Store results
  test_results[#test_results + 1] = result
  
  -- Update totals
  total_passes = total_passes + result.counts.passes
  total_failures = total_failures + result.counts.failures
  total_pending = total_pending + result.counts.pending
  
  -- Track file success/failure
  -- A file fails if:
  -- 1. It had Lua runtime errors (result.success is false)
  -- 2. It explicitly returned a false value (result.result is false)
  -- 3. It has any test assertion failures (result.counts.failures > 0)
  if result.success and 
     (result.result == nil or result.result == true) and 
     result.counts.failures == 0 then
    passed_files = passed_files + 1
  else
    failed_files = failed_files + 1
  end
end

local end_time = get_time()
local total_time = end_time - start_time
local total_tests = total_passes + total_failures + total_pending

-- Final garbage collection
collectgarbage("collect")
local end_memory = collectgarbage("count")
local total_memory_delta = end_memory - lust_next.test_stats.start_memory

-- Print summary
logger.info("Test run completed", {
  total_files = #test_files,
  passed_files = passed_files,
  failed_files = failed_files
})

logger.info("Generating detailed results")

-- Define column format based on options
local column_format
if options.performance then
  column_format = "%-36s %8s %8s %8s %8s %10s"
  logger.info("Result table headers", {
    columns = {"Test File", "Total", "Passed", "Failed", "Pending", "Time (s)"},
    with_timing = true
  })
else
  column_format = "%-40s %10s %10s %10s %10s"
  logger.info("Result table headers", {
    columns = {"Test File", "Total", "Passed", "Failed", "Pending"},
    with_timing = false
  })
end
logger.info("Table separator")

-- Convert by_file table to array for sorting
local file_results = {}
for file_name, stats in pairs(lust_next.test_stats.by_file) do
  table.insert(file_results, {
    file_name = file_name,
    stats = stats
  })
end

-- Sort results by file name for readability
table.sort(file_results, function(a, b) return a.file_name < b.file_name end)

-- Print each file's results
for _, result in ipairs(file_results) do
  local stats = result.stats
  local status_indicator = " "
  
  -- Add colored status indicators
  if stats.failures > 0 then
    status_indicator = "\27[31m✗\27[0m" -- Red X for failures
  elseif stats.passes > 0 and stats.failures == 0 then
    status_indicator = "\27[32m✓\27[0m" -- Green check for passes
  elseif stats.pending > 0 then
    status_indicator = "\27[33m⚠\27[0m" -- Yellow warning for pending tests
  elseif stats.total == 0 then
    status_indicator = "\27[34m•\27[0m" -- Blue dot for zero tests
  end
  
  -- Print with or without performance stats
  if options.performance then
    logger.info(string.format("%s %-34s %8d %8d %8d %8d %10.4f", 
      status_indicator,
      result.file_name,
      stats.total,
      stats.passes,
      stats.failures,
      stats.pending,
      stats.time
    ))
  else
    logger.info(string.format("%s %-38s %10d %10d %10d %10d", 
      status_indicator,
      result.file_name,
      stats.total,
      stats.passes,
      stats.failures,
      stats.pending
    ))
  end
end

-- Print totals row
logger.info("Table separator")
if options.performance then
  logger.info("Test totals", {
    total_tests = lust_next.test_stats.total,
    passed = lust_next.test_stats.passes,
    failed = lust_next.test_stats.failures,
    pending = lust_next.test_stats.pending,
    time_seconds = total_time
  })
else
  logger.info("Test totals", {
    total_tests = lust_next.test_stats.total,
    passed = lust_next.test_stats.passes,
    failed = lust_next.test_stats.failures,
    pending = lust_next.test_stats.pending
  })
end

-- Test assertions summary
if lust_next.test_stats.total > 0 then
  local pass_percentage = lust_next.test_stats.passes / lust_next.test_stats.total * 100
  logger.info("Assertion summary", {
    total = lust_next.test_stats.total,
    passed = lust_next.test_stats.passes,
    passed_percentage = string.format("%.1f", pass_percentage),
    failed = lust_next.test_stats.failures,
    pending = lust_next.test_stats.pending
  })
else
  logger.info("Assertion summary", {total = 0, status = "no assertions detected"})
end

-- Performance summary
logger.info("Performance summary", {
  total_time_seconds = string.format("%.4f", total_time),
  average_time_seconds = string.format("%.4f", total_time / #test_files),
  total_memory_delta_kb = options.memory and string.format("%.2f", total_memory_delta) or nil,
  final_memory_kb = options.memory and string.format("%.2f", end_memory) or nil
})

-- Module reset stats if available
if module_reset_loaded then
  logger.info("Module isolation status", {
    status = "active",
    protected_modules_count = #module_reset.get_loaded_modules()
  })
  
  if options.verbose then
    logger.info("Protected modules list", {modules = module_reset.get_loaded_modules()})
  end
end

-- Print failed files if any
if failed_files > 0 then
  logger.error("Failed tests detected", {count = failed_files})
  
  for _, result in ipairs(test_results) do
    -- Show files with:
    -- 1. Runtime errors
    -- 2. Explicit false return values
    -- 3. Any test assertion failures
    if not result.success or 
       (result.result ~= nil and result.result ~= true) or 
       result.counts.failures > 0 then
      
      local failure_info = {
        file_path = result.file_path
      }
      
      -- Add error info for runtime errors
      if not result.success then
        failure_info.error = tostring(result.result)
      end
      
      -- Add failed assertions count
      if result.counts.failures > 0 then
        failure_info.failed_assertions = result.counts.failures
      end
      
      logger.error("Test file failed", failure_info)
    end
  end
  
  -- Generate coverage/quality reports even if tests failed
  -- Stop coverage tracking and generate report
  if coverage_loaded and options.coverage then
    if coverage.stop then
      coverage.stop()
    else
      logger.error("Function not found", {function_name = "coverage.stop"})
    end
    
    -- Calculate and save coverage reports
    logger.info("Generating coverage report")
    
    if coverage.calculate_stats then
      coverage.calculate_stats()
    else
      logger.error("Function not found", {function_name = "coverage.calculate_stats"})
    end
    
    -- Print coverage data status before generating reports
    if options.coverage_debug then
      -- Count how many files we're tracking
      local tracked_files = 0
      for _ in pairs(coverage.data.files) do
        tracked_files = tracked_files + 1
      end
      
      logger.debug("Coverage file tracking status:")
      logger.debug("  Tracked files: " .. tracked_files)
      
      -- Show first few tracked files for debugging
      local file_count = 0
      for file, data in pairs(coverage.data.files) do
        if file_count < 5 or options.coverage_debug == "verbose" then
          -- Count covered lines
          local covered_lines = 0
          for _ in pairs(data.lines) do
            covered_lines = covered_lines + 1
          end
          
          local line_count = data.line_count or 0
          local cov_pct = line_count > 0 and (covered_lines / line_count * 100) or 0
          
          logger.debug("  File: " .. file)
          logger.debug("    Lines: " .. covered_lines .. "/" .. line_count .. " (" .. string.format("%.1f%%", cov_pct) .. ")")
        end
        file_count = file_count + 1
      end
      
      if file_count > 5 and options.coverage_debug ~= "verbose" then
        logger.debug("  ... and " .. (file_count - 5) .. " more files")
      end
      
      if file_count == 0 then
        logger.warn("  WARNING: No files are being tracked for coverage!")
      end
    end
    
    -- Generate reports in different formats
    local formats = {"html", "json", "lcov", "cobertura"}
    for _, format in ipairs(formats) do
      if coverage.save_report then
        local success = coverage.save_report("./coverage-reports/coverage-report." .. format, format)
        if success then
          logger.info("Generated " .. format .. " coverage report")
        else
          logger.error("Failed to generate " .. format .. " coverage report")
        end
      else
        logger.error("ERROR: coverage.save_report function not found!")
        break
      end
    end
    
    -- Print coverage summary
    if coverage.summary_report then
      local report = coverage.summary_report()
      logger.info("Overall coverage: " .. string.format("%.2f%%", report.overall_pct))
      logger.info("Line coverage: " .. string.format("%.2f%%", report.lines_pct))
      logger.info("Function coverage: " .. string.format("%.2f%%", report.functions_pct))
      
      -- Check if coverage meets threshold
      if coverage.meets_threshold and coverage.meets_threshold() then
        logger.info("✅ Coverage meets the threshold")
      else
        logger.warn("❌ Coverage is below the threshold")
      end
    else
      logger.error("ERROR: coverage.summary_report function not found!")
    end
  end
  
  -- Generate quality report if enabled
  if quality_loaded and options.quality then
    logger.info("\n=== Quality Report ===")
    quality.calculate_stats()
    
    -- Generate quality report
    local success = quality.save_report("./coverage-reports/quality-report.html", "html")
    if success then
      logger.info("Generated HTML quality report")
    end
    
    -- Generate JSON quality report
    success = quality.save_report("./coverage-reports/quality-report.json", "json")
    if success then
      logger.info("Generated JSON quality report")
    end
    
    -- Print quality summary
    local report = quality.summary_report()
    logger.info("Quality score: " .. string.format("%.2f%%", report.quality_score))
    logger.info("Tests analyzed: " .. report.tests_analyzed)
    logger.info("Quality level: " .. report.level .. " (" .. report.level_name .. ")")
  end
  
  os.exit(1)
else
  logger.info("\n✅ ALL TESTS PASSED")
  
  -- Generate coverage/quality reports for passing tests
  -- Stop coverage tracking and generate report
  if coverage_loaded and options.coverage then
    if coverage.stop then
      coverage.stop()
    else
      logger.error("coverage.stop function not found!")
    end
    
    -- Calculate and save coverage reports
    logger.info("\n=== Coverage Report ===")
    
    if coverage.calculate_stats then
      coverage.calculate_stats()
    else
      logger.error("coverage.calculate_stats function not found!")
    end
    
    -- Print coverage data status before generating reports
    if options.coverage_debug then
      -- Count how many files we're tracking
      local tracked_files = 0
      for _ in pairs(coverage.data.files) do
        tracked_files = tracked_files + 1
      end
      
      logger.debug("Coverage file tracking status:")
      logger.debug("  Tracked files: " .. tracked_files)
      
      -- Show first few tracked files for debugging
      local file_count = 0
      for file, data in pairs(coverage.data.files) do
        if file_count < 5 or options.coverage_debug == "verbose" then
          -- Count covered lines
          local covered_lines = 0
          for _ in pairs(data.lines) do
            covered_lines = covered_lines + 1
          end
          
          local line_count = data.line_count or 0
          local cov_pct = line_count > 0 and (covered_lines / line_count * 100) or 0
          
          logger.debug("  File: " .. file)
          logger.debug("    Lines: " .. covered_lines .. "/" .. line_count .. " (" .. string.format("%.1f%%", cov_pct) .. ")")
        end
        file_count = file_count + 1
      end
      
      if file_count > 5 and options.coverage_debug ~= "verbose" then
        logger.debug("  ... and " .. (file_count - 5) .. " more files")
      end
      
      if file_count == 0 then
        logger.warn("  WARNING: No files are being tracked for coverage!")
      end
    end
    
    -- Generate reports in different formats
    local formats = {"html", "json", "lcov", "cobertura"}
    for _, format in ipairs(formats) do
      if coverage.save_report then
        local success = coverage.save_report("./coverage-reports/coverage-report." .. format, format)
        if success then
          logger.info("Generated " .. format .. " coverage report")
        else
          logger.error("Failed to generate " .. format .. " coverage report")
        end
      else
        logger.error("coverage.save_report function not found!")
        break
      end
    end
    
    -- Print coverage summary
    if coverage.summary_report then
      local report = coverage.summary_report()
      logger.info("Overall coverage: " .. string.format("%.2f%%", report.overall_pct))
      logger.info("Line coverage: " .. string.format("%.2f%%", report.lines_pct))
      logger.info("Function coverage: " .. string.format("%.2f%%", report.functions_pct))
      
      -- Check if coverage meets threshold
      if coverage.meets_threshold and coverage.meets_threshold() then
        logger.info("✅ Coverage meets the threshold")
      else
        logger.warn("❌ Coverage is below the threshold")
      end
    else
      logger.error("coverage.summary_report function not found!")
    end
  end
  
  -- Generate quality report if enabled
  if quality_loaded and options.quality then
    logger.info("\n=== Quality Report ===")
    quality.calculate_stats()
    
    -- Generate quality report
    local success = quality.save_report("./coverage-reports/quality-report.html", "html")
    if success then
      logger.info("Generated HTML quality report")
    end
    
    -- Generate JSON quality report
    success = quality.save_report("./coverage-reports/quality-report.json", "json")
    if success then
      logger.info("Generated JSON quality report")
    end
    
    -- Print quality summary
    local report = quality.summary_report()
    logger.info("Quality score: " .. string.format("%.2f%%", report.quality_score))
    logger.info("Tests analyzed: " .. report.tests_analyzed)
    logger.info("Quality level: " .. report.level .. " (" .. report.level_name .. ")")
  end
  
  os.exit(0)
end