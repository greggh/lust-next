-- Test runner for firmo
-- A universal test runner that can:
-- 1. Run a single test file
-- 2. Run all tests in a directory (recursively)
-- 3. Run tests matching a pattern
-- 4. Support a standardized set of command-line arguments
local runner = {}

-- Import required modules
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Set error handler to test mode since we're running tests
error_handler.set_test_mode(true)

-- Try to load watcher module if available
local watcher
local has_watcher = pcall(function()
  watcher = require("lib.tools.watcher")
end)

-- Initialize logger for runner module
local logger = logging.get_logger("runner")
logging.configure_from_config("runner")

-- Try to load module_reset for enhanced isolation
local module_reset_loaded, module_reset = pcall(require, "lib.core.module_reset")
if not module_reset_loaded then
  logger.warn("Module reset system unavailable", { fallback = "using basic isolation" })
end

-- ANSI color codes (keep them for compatibility with existing code)
local red = string.char(27) .. "[31m"
local green = string.char(27) .. "[32m"
local yellow = string.char(27) .. "[33m"
local cyan = string.char(27) .. "[36m"
local normal = string.char(27) .. "[0m"

-- Run a specific test file
function runner.run_file(file_path, firmo, options)
  options = options or {}

  -- Initialize counter properties if they don't exist
  if firmo.passes == nil then
    firmo.passes = 0
  end
  if firmo.errors == nil then
    firmo.errors = 0
  end
  if firmo.skipped == nil then
    firmo.skipped = 0
  end

  local prev_passes = firmo.passes
  local prev_errors = firmo.errors
  local prev_skipped = firmo.skipped

  logger.info("Running file", { file_path = file_path })

  -- Count PASS/FAIL from test output
  local pass_count = 0
  local fail_count = 0
  local skip_count = 0

  -- Keep track of the original print function
  local original_print = print
  local output_buffer = {}

  -- Override print to count test results
  _G.print = function(...)
    local output = table.concat({ ... }, " ")
    table.insert(output_buffer, output)

    -- Count PASS/FAIL/SKIP instances in the output
    if output:match("PASS") and not output:match("SKIP") then
      pass_count = pass_count + 1
    elseif output:match("FAIL") then
      fail_count = fail_count + 1
    elseif output:match("SKIP") or output:match("PENDING") then
      skip_count = skip_count + 1
    end

    -- Still show output
    original_print(...)
  end

  -- Execute the test file
  local start_time = os.clock()
  local success, err = pcall(function()
    -- Verify file exists
    if not fs.file_exists(file_path) then
      error("Test file does not exist: " .. file_path)
    end

    -- Ensure proper package path for test file
    local save_path = package.path
    local dir = fs.get_directory_name(file_path)
    if dir and dir ~= "" then
      package.path = fs.join_paths(dir, "?.lua") .. ";" .. fs.join_paths(dir, "../?.lua") .. ";" .. package.path
    end

    dofile(file_path)

    package.path = save_path
  end)
  local elapsed_time = os.clock() - start_time

  -- Restore original print function
  _G.print = original_print

  -- Use counted results if available, otherwise use firmo counters
  local results = {
    success = success,
    error = err,
    passes = pass_count > 0 and pass_count or (firmo.passes - prev_passes),
    errors = fail_count > 0 and fail_count or (firmo.errors - prev_errors),
    skipped = skip_count > 0 and skip_count or (firmo.skipped - prev_skipped),
    total = 0,
    elapsed = elapsed_time,
    output = table.concat(output_buffer, "\n"),
  }

  -- Calculate total tests
  results.total = results.passes + results.errors + results.skipped

  -- Add test file path
  results.file = file_path

  -- Add any test errors from the output
  results.test_errors = {}
  for line in results.output:gmatch("[^\r\n]+") do
    if line:match("FAIL") then
      local name = line:match("FAIL%s+(.+)")
      if name then
        table.insert(results.test_errors, {
          message = "Test failed: " .. name,
          file = file_path,
        })
      end
    end
  end

  if not success then
    logger.error("Execution error", { error = err })
    table.insert(results.test_errors, {
      message = tostring(err),
      file = file_path,
      traceback = debug.traceback(),
    })
  else
    -- Always show the completion status with test counts
    -- Use consistent terminology
    logger.info("Test completed", {
      passes = results.passes,
      failures = results.errors,
      skipped = results.skipped,
      tests_passed = results.passes, -- Add for consistency with run_all
      tests_failed = results.errors, -- Add for consistency with run_all
    })
  end

  -- Output JSON results if requested
  if options.json_output or options.results_format == "json" then
    -- Try to load JSON module
    local json_module
    local ok, mod = pcall(require, "lib.reporting.json")
    if not ok then
      ok, mod = pcall(require, "../lib/reporting/json")
    end

    if ok then
      json_module = mod

      -- Create test results data structure
      local test_results = {
        name = file_path:match("([^/\\]+)$") or file_path,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
        tests = results.total,
        failures = results.errors,
        errors = success and 0 or 1,
        skipped = results.skipped,
        time = results.elapsed,
        test_cases = {},
        file = file_path,
        success = success and results.errors == 0,
      }

      -- Extract test cases if possible
      for line in results.output:gmatch("[^\r\n]+") do
        if line:match("PASS%s+") or line:match("FAIL%s+") or line:match("SKIP%s+") or line:match("PENDING%s+") then
          local status, name
          if line:match("PASS%s+") then
            status = "pass"
            name = line:match("PASS%s+(.+)")
          elseif line:match("FAIL%s+") then
            status = "fail"
            name = line:match("FAIL%s+(.+)")
          elseif line:match("SKIP%s+") then
            status = "skipped"
            name = line:match("SKIP%s+(.+)")
          elseif line:match("PENDING%s+") then
            status = "pending"
            name = line:match("PENDING:%s+(.+)")
          end

          if name then
            local test_case = {
              name = name,
              classname = file_path:match("([^/\\]+)$"):gsub("%.lua$", ""),
              time = 0, -- We don't have individual test timing
              status = status,
            }

            -- Add failure details if available
            if status == "fail" then
              test_case.failure = {
                message = "Test failed: " .. name,
                type = "Assertion",
                details = "",
              }
            end

            table.insert(test_results.test_cases, test_case)
          end
        end
      end

      -- If we couldn't extract individual tests, add a single summary test case
      if #test_results.test_cases == 0 then
        table.insert(test_results.test_cases, {
          name = file_path:match("([^/\\]+)$"):gsub("%.lua$", ""),
          classname = file_path:match("([^/\\]+)$"):gsub("%.lua$", ""),
          time = results.elapsed,
          status = (success and results.errors == 0) and "pass" or "fail",
        })
      end

      -- Format as JSON with markers for parallel execution
      local json_results = json_module.encode(test_results)
      logger.info("JSON results", { results = "RESULTS_JSON_BEGIN" .. json_results .. "RESULTS_JSON_END" })
    end
  end

  return results
end

-- Find test files in a directory
function runner.find_test_files(dir_path, options)
  options = options or {}
  local pattern = options.pattern or "*.lua"
  local filter = options.filter
  local exclude_patterns = options.exclude_patterns or { "fixtures/*" }

  logger.info("Finding test files", {
    directory = dir_path,
    pattern = pattern,
    filter = filter,
    exclude_patterns = table.concat(exclude_patterns, ", "),
  })

  -- Handle directory existence check properly
  -- The fs.normalize_path() function automatically removes trailing slashes
  -- but fs.directory_exists() works fine with or without trailing slashes

  -- Simply check if directory exists
  if not fs.directory_exists(dir_path) then
    logger.error("Directory not found", { directory = dir_path })
    return {}
  end

  -- Use filesystem module to find test files
  local files, err = fs.discover_files({ dir_path }, { pattern }, exclude_patterns)

  if not files then
    logger.error("Failed to discover test files", {
      error = error_handler.format_error(err),
      directory = dir_path,
      pattern = pattern,
    })
    return {}
  end

  -- Apply filter if specified
  if filter and filter ~= "" then
    local filtered_files = {}
    for _, file in ipairs(files) do
      if file:match(filter) then
        table.insert(filtered_files, file)
      end
    end

    logger.info("Filtered test files", {
      count = #filtered_files,
      original_count = #files,
      filter = filter,
    })

    files = filtered_files
  end

  -- Sort files for consistent execution order
  table.sort(files)

  return files
end

-- Run tests in a directory or file list
function runner.run_all(files_or_dir, firmo, options)
  options = options or {}
  local files

  -- If files_or_dir is a string, treat it as a directory
  if type(files_or_dir) == "string" then
    files = runner.find_test_files(files_or_dir, options)
  else
    files = files_or_dir
  end

  logger.info("Running test files", { count = #files })

  local passed_files = 0
  local failed_files = 0
  local total_passes = 0
  local total_failures = 0
  local total_skipped = 0
  local start_time = os.clock()

  -- Initialize module reset if available
  if module_reset_loaded and module_reset then
    module_reset.register_with_firmo(firmo)

    -- Configure isolation options
    module_reset.configure({
      reset_modules = true,
      verbose = options.verbose == true,
    })
    logger.info("Module reset system activated", { feature = "enhanced test isolation" })
  end

  -- Try to load coverage module
  local coverage_loaded, coverage
  if options.coverage then
    coverage_loaded, coverage = pcall(require, "lib.coverage")
    if coverage_loaded then
      logger.info("Coverage module loaded", { purpose = "test coverage analysis" })
      -- Configure coverage
      coverage.init({
        enabled = true,
        discover_uncovered = options.discover_uncovered ~= false,
        debug = options.coverage_debug == true,
        source_dirs = { ".", "lib", "src" },
        threshold = options.threshold or 80,
        full_reset = true, -- Start with a clean slate
      })

      -- Start coverage tracking
      if coverage.start then
        coverage.start()
      else
        logger.error("Function not found", { function_name = "coverage.start" })
      end
    else
      logger.error("Failed to load coverage module", {
        error = error_handler.format_error(coverage),
      })
    end
  end

  -- Try to load quality module
  local quality_loaded, quality
  if options.quality then
    quality_loaded, quality = pcall(require, "lib.quality")
    if quality_loaded then
      logger.info("Quality module loaded", { purpose = "test quality analysis" })
      -- Configure quality validation
      quality.init({
        enabled = true,
        level = options.quality_level or 3,
        debug = options.verbose == true,
        threshold = options.threshold or 80,
      })
    else
      logger.error("Failed to load quality module", {
        error = error_handler.format_error(quality),
      })
    end
  end

  for _, file in ipairs(files) do
    local results = runner.run_file(file, firmo, options)

    -- Count passed/failed files
    if results.success and results.errors == 0 then
      passed_files = passed_files + 1
    else
      failed_files = failed_files + 1
    end

    -- Count total tests
    total_passes = total_passes + results.passes
    total_failures = total_failures + results.errors
    total_skipped = total_skipped + (results.skipped or 0)
  end

  local elapsed_time = os.clock() - start_time

  -- In the summary, use consistent terminology:
  -- - passes/failures => individual test cases passed/failed
  -- - files_passed/files_failed => test files that passed/failed
  logger.info("Test run summary", {
    files_passed = passed_files,
    files_failed = failed_files,
    tests_passed = total_passes, -- Same as 'passes' 
    tests_failed = total_failures, -- Same as 'failures'
    tests_skipped = total_skipped,
    passes = total_passes, -- Add these for consistency
    failures = total_failures, -- Add these for consistency 
    elapsed_time_seconds = string.format("%.2f", elapsed_time),
  })

  local all_passed = failed_files == 0
  if not all_passed then
    logger.error("Test run failed", { failed_files = failed_files })
  else
    logger.info("Test run successful", { all_passed = true })
  end

  -- Generate coverage reports if enabled
  if coverage_loaded and coverage and options.coverage then
    if coverage.stop then
      coverage.stop()
    else
      logger.error("Function not found", { function_name = "coverage.stop" })
    end

    -- Calculate and save coverage reports
    logger.info("Generating coverage report")

    if coverage.calculate_stats then
      coverage.calculate_stats()
    else
      logger.error("Function not found", { function_name = "coverage.calculate_stats" })
    end

    -- Generate reports in different formats
    local report_dir = options.report_dir or "./coverage-reports"
    fs.ensure_directory_exists(report_dir)
    local formats = { "html", "json", "lcov", "cobertura" }

    for _, format in ipairs(formats) do
      if coverage.save_report then
        local report_path = fs.join_paths(report_dir, "coverage-report." .. format)
        local success = coverage.save_report(report_path, format)
        if success then
          logger.info("Generated coverage report", { format = format, path = report_path })
        else
          logger.error("Failed to generate coverage report", { format = format })
        end
      else
        logger.error("Function not found", { function_name = "coverage.save_report" })
        break
      end
    end

    -- Print coverage summary
    if coverage.summary_report then
      local report = coverage.summary_report()
      logger.info("Coverage summary", {
        overall = string.format("%.2f%%", report.overall_pct),
        lines = string.format("%.2f%%", report.lines_pct),
        functions = string.format("%.2f%%", report.functions_pct),
        meets_threshold = coverage.meets_threshold and coverage.meets_threshold() or false,
      })
    else
      logger.error("Function not found", { function_name = "coverage.summary_report" })
    end
  end

  -- Generate quality reports if enabled
  if quality_loaded and quality and options.quality then
    logger.info("Generating quality report")
    quality.calculate_stats()

    -- Generate quality reports in different formats
    local report_dir = options.report_dir or "./coverage-reports"
    fs.ensure_directory_exists(report_dir)

    -- Generate HTML quality report
    local success = quality.save_report(fs.join_paths(report_dir, "quality-report.html"), "html")
    if success then
      logger.info("Generated HTML quality report")
    end

    -- Generate JSON quality report
    success = quality.save_report(fs.join_paths(report_dir, "quality-report.json"), "json")
    if success then
      logger.info("Generated JSON quality report")
    end

    -- Print quality summary
    local report = quality.summary_report()
    logger.info("Quality summary", {
      score = string.format("%.2f%%", report.quality_score),
      tests_analyzed = report.tests_analyzed,
      level = report.level,
      level_name = report.level_name,
    })
  end

  -- Output overall JSON results if requested
  if options.json_output or options.results_format == "json" then
    -- Try to load JSON module
    local json_module
    local ok, mod = pcall(require, "lib.reporting.json")
    if not ok then
      ok, mod = pcall(require, "../lib/reporting/json")
    end

    if ok then
      json_module = mod

      -- Create aggregated test results
      local test_results = {
        name = "firmo-tests",
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
        tests = total_passes + total_failures + total_skipped,
        failures = total_failures,
        errors = 0,
        skipped = total_skipped,
        time = elapsed_time,
        files_tested = #files,
        files_passed = passed_files,
        files_failed = failed_files,
        success = all_passed,
      }

      -- Format as JSON with markers for parallel execution
      local json_results = json_module.encode(test_results)
      logger.info("Overall JSON results", { results = "RESULTS_JSON_BEGIN" .. json_results .. "RESULTS_JSON_END" })
    end
  end

  return all_passed
end

-- Watch mode for continuous testing
function runner.watch_mode(path, firmo, options)
  if not has_watcher then
    logger.error("Watch mode unavailable", { reason = "Watcher module not found" })
    return false
  end

  options = options or {}
  local exclude_patterns = options.exclude_patterns or { "node_modules", "%.git" }
  local watch_interval = options.interval or 1.0

  -- Initialize the file watcher
  logger.info("Watch mode activated")
  logger.info("Press Ctrl+C to exit")

  -- Determine what to watch based on path type
  local directories = {}
  local files = {}

  -- Check if path is a directory or file
  if fs.directory_exists(path) then
    -- Watch the directory and run tests in it
    table.insert(directories, path)

    -- Find test files in the directory
    local test_pattern = options.pattern or "*_test.lua"
    local found = fs.discover_files({ path }, { test_pattern }, exclude_patterns)

    if found then
      for _, file in ipairs(found) do
        table.insert(files, file)
      end
    end

    logger.info("Watching directory", { path = path, files_found = #files })
  elseif fs.file_exists(path) then
    -- Watch the file's directory and run the specific file
    local dir = fs.get_directory_name(path)
    table.insert(directories, dir)
    table.insert(files, path)

    logger.info("Watching file", { file = path, directory = dir })
  else
    logger.error("Path not found for watch mode", { path = path })
    return false
  end

  watcher.set_check_interval(watch_interval)
  watcher.init(directories, exclude_patterns)

  local last_run_time = os.time()
  local debounce_time = 0.5 -- seconds to wait after changes before running tests
  local last_change_time = 0
  local need_to_run = true
  local run_success = true

  -- Create a copy of options for the runner
  local runner_options = {}
  for k, v in pairs(options) do
    runner_options[k] = v
  end

  -- Watch loop
  while true do
    local current_time = os.time()

    -- Check for file changes
    local changed_files = watcher.check_for_changes()
    if changed_files then
      last_change_time = current_time
      need_to_run = true

      logger.info("File changes detected", { files = #changed_files })
      for _, file in ipairs(changed_files) do
        logger.info("Changed file", { path = file })
      end
    end

    -- Run tests if needed and after debounce period
    if need_to_run and current_time - last_change_time >= debounce_time then
      logger.info("Running tests", { timestamp = os.date("%Y-%m-%d %H:%M:%S") })

      -- Clear terminal
      io.write("\027[2J\027[H")

      firmo.reset()

      -- Run tests based on the files we found earlier
      if #files > 0 then
        run_success = runner.run_all(files, firmo, runner_options)
      else
        logger.warn("No test files found to run")
        run_success = true
      end

      last_run_time = current_time
      need_to_run = false

      logger.info("Watching for changes")
    end

    -- Small sleep to prevent CPU hogging
    os.execute("sleep 0.1")
  end

  return run_success
end

-- Parse command-line arguments
function runner.parse_arguments(args)
  local options = {
    verbose = false, -- Verbose output
    memory = false, -- Track memory usage
    performance = false, -- Show performance stats
    coverage = false, -- Enable coverage tracking
    coverage_debug = false, -- Enable debug output for coverage
    discover_uncovered = true, -- Discover files that aren't executed by tests
    quality = false, -- Enable quality validation
    quality_level = 3, -- Quality validation level
    watch = false, -- Enable watch mode
    json_output = false, -- Output JSON results
    pattern = nil, -- Pattern for test files
    filter = nil, -- Filter pattern for tests
    report_dir = "./coverage-reports", -- Directory for reports
    formats = { "html", "json", "lcov", "cobertura" }, -- Report formats
    threshold = 80, -- Coverage/quality threshold
    exclude_patterns = { "fixtures/*" }, -- Patterns to exclude
  }

  local path = nil
  local i = 1

  while i <= #args do
    local arg = args[i]

    -- Boolean flags
    if arg == "--verbose" or arg == "-v" then
      options.verbose = true
    elseif arg == "--memory" or arg == "-m" then
      options.memory = true
    elseif arg == "--performance" or arg == "-p" then
      options.performance = true
    elseif arg == "--coverage" or arg == "-c" then
      options.coverage = true
    elseif arg == "--coverage-debug" or arg == "-cd" then
      options.coverage_debug = true
    elseif arg == "--quality" or arg == "-q" then
      options.quality = true
    elseif arg == "--watch" or arg == "-w" then
      options.watch = true
    elseif arg == "--json" or arg == "-j" then
      options.json_output = true

    -- Options with values (format: --option=value or --option value)
    elseif arg:match("^%-%-pattern=(.+)$") then
      options.pattern = arg:match("^%-%-pattern=(.+)$")
    elseif arg:match("^%-%-filter=(.+)$") then
      options.filter = arg:match("^%-%-filter=(.+)$")
    elseif arg:match("^%-%-report%-dir=(.+)$") then
      options.report_dir = arg:match("^%-%-report%-dir=(.+)$")
    elseif arg:match("^%-%-quality%-level=(%d+)$") then
      options.quality_level = tonumber(arg:match("^%-%-quality%-level=(%d+)$"))
    elseif arg:match("^%-%-threshold=(%d+)$") then
      options.threshold = tonumber(arg:match("^%-%-threshold=(%d+)$"))
    elseif arg:match("^%-%-format=(.+)$") then
      options.formats = { arg:match("^%-%-format=(.+)$") }

    -- Options with values (separate argument)
    elseif arg == "--pattern" and i < #args then
      i = i + 1
      options.pattern = args[i]
    elseif arg == "--filter" and i < #args then
      i = i + 1
      options.filter = args[i]
    elseif arg == "--report-dir" and i < #args then
      i = i + 1
      options.report_dir = args[i]
    elseif arg == "--quality-level" and i < #args then
      i = i + 1
      options.quality_level = tonumber(args[i])
    elseif arg == "--threshold" and i < #args then
      i = i + 1
      options.threshold = tonumber(args[i])
    elseif arg == "--format" and i < #args then
      i = i + 1
      options.formats = { args[i] }

    -- Help flag
    elseif arg == "--help" or arg == "-h" then
      runner.print_usage()
      os.exit(0)

    -- First non-flag argument is considered the path
    elseif not arg:match("^%-") and not path then
      path = arg
    end

    i = i + 1
  end

  return path, options
end

-- Print usage information
function runner.print_usage()
  print("Usage: lua scripts/runner.lua [options] [path]")
  print("")
  print("Where path can be a file or directory, and options include:")
  print("  --pattern=<pattern>   Only run test files matching pattern (e.g., '*_test.lua')")
  print("  --filter=<filter>     Only run tests matching filter (by tag or description)")
  print("  --format=<format>     Output format (summary, tap, junit, etc.)")
  print("  --report-dir=<path>   Save reports to specified directory")
  print("  --coverage, -c        Enable coverage tracking")
  print("  --coverage-debug, -cd Enable debug output for coverage")
  print("  --quality, -q         Enable quality validation")
  print("  --quality-level=<n>   Set quality validation level (1-5)")
  print("  --threshold=<n>       Set coverage/quality threshold (0-100)")
  print("  --verbose, -v         Enable verbose output")
  print("  --memory, -m          Track memory usage")
  print("  --performance, -p     Show performance metrics")
  print("  --watch, -w           Enable watch mode for continuous testing")
  print("  --json, -j            Output JSON results")
  print("  --help, -h            Show this help message")
  print("")
  print("Examples:")
  print("  lua scripts/runner.lua tests/coverage_test.lua     Run a single test file")
  print("  lua scripts/runner.lua tests/                      Run all tests in directory")
  print("  lua scripts/runner.lua --pattern=coverage tests/   Run coverage-related tests")
  print("  lua scripts/runner.lua --coverage tests/           Run tests with coverage")
end

-- Main function to run tests from command line
function runner.main(args)
  -- Parse command-line arguments
  local path, options = runner.parse_arguments(args)

  -- Make sure we have a path
  if not path then
    logger.error("No path specified", { usage = "lua scripts/runner.lua [options] [path]" })
    runner.print_usage()
    return false
  end

  -- Try to load firmo
  local firmo_loaded, firmo = pcall(require, "firmo")
  if not firmo_loaded then
    -- Try again with relative path
    firmo_loaded, firmo = pcall(require, "firmo")
    if not firmo_loaded then
      logger.error("Failed to load firmo", { error = error_handler.format_error(firmo) })
      return false
    end
  end

  -- Check if we're running in watch mode
  if options.watch then
    -- Setup watch mode for continuous testing
    return runner.watch_mode(path, firmo, options)
  end

  -- Check if path is a file or directory
  -- We can automatically detect directories without a flag
  if fs.directory_exists(path) then
    -- Run all tests in directory
    logger.info("Detected directory path", { path = path })
    return runner.run_all(path, firmo, options)
  elseif fs.file_exists(path) then
    -- Run a single test file
    local result = runner.run_file(path, firmo, options)
    return result.success and result.errors == 0
  else
    -- Path not found
    logger.error("Path not found", { path = path })
    return false
  end
end

-- If this script is being run directly, execute main function
if arg and arg[0]:match("runner%.lua$") then
  -- Create a clean args table (without script name)
  local args = {}
  for i = 1, #arg do
    args[i] = arg[i]
  end

  -- Run the main function and exit with appropriate code
  local success = runner.main(args)
  os.exit(success and 0 or 1)
end

return runner
