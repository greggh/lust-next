#!/usr/bin/env lua
-- Main test runner script for lust-next

-- Get the root directory
local lust_dir = arg[0]:match("(.-)[^/\\]+$") or "./"
if lust_dir == "" then lust_dir = "./" end
lust_dir = lust_dir .. "../"

-- Add scripts directory to package path
package.path = lust_dir .. "?.lua;" .. lust_dir .. "scripts/?.lua;" .. lust_dir .. "src/?.lua;" .. package.path

-- Load lust-next and utility modules
local lust_next = require("lust-next")
local discover = require("discover")
local runner = require("runner")

-- Parse command line arguments
local dir = "./tests"
local pattern = "*_test.lua"
local run_single_file = nil
local codefix_enabled = false
local codefix_command = nil
local codefix_target = nil
local watch_mode_enabled = false
local watch_dirs = {"."}
local watch_interval = 1.0
local exclude_patterns = {"node_modules", "%.git"}
local interactive_mode_enabled = false

-- Report configuration options
local report_config = {
  report_dir = "./coverage-reports",
  report_suffix = nil,
  coverage_path_template = nil,
  quality_path_template = nil,
  results_path_template = nil,
  timestamp_format = "%Y-%m-%d",
  verbose = false,
  results_format = nil  -- Format for test results (junit, tap, csv, json)
}

-- Print usage information
local function print_usage()
  print("Usage: run_tests.lua [options] [file.lua]")
  print("Options:")
  print("  --dir <directory>         Directory to search for test files (default: ./tests)")
  print("  --pattern <pattern>       Pattern to match test files (default: *_test.lua)")
  print("  --fix [directory]         Run code fixing on directory (default: .)")
  print("  --check <directory>       Check for code issues without fixing")
  print("  --watch                   Enable watch mode for continuous testing")
  print("  --watch-dir <directory>   Directory to watch for changes (can be multiple)")
  print("  --watch-interval <secs>   Interval between file checks (default: 1.0)")
  print("  --exclude <pattern>       Pattern to exclude from watching (can be multiple)")
  print("  --interactive, -i         Start interactive CLI mode")
  print("  --help                    Show this help message")
  
  print("\nReport Configuration Options:")
  print("  --output-dir DIR          Base directory for all reports (default: ./coverage-reports)")
  print("  --report-suffix STR       Add a suffix to all report filenames (e.g., \"-v1.0\")")
  print("  --coverage-path PATH      Path template for coverage reports")
  print("  --quality-path PATH       Path template for quality reports")
  print("  --results-path PATH       Path template for test results reports")
  print("  --timestamp-format FMT    Format string for timestamps (default: \"%Y-%m-%d\")")
  print("  --verbose-reports         Enable verbose output during report generation")
  print("  --results-format FORMAT   Format for test results (junit, tap, csv, json)")
  print("\n  Path templates support the following placeholders:")
  print("    {format}    - Output format (html, json, etc.)")
  print("    {type}      - Report type (coverage, quality, etc.)")
  print("    {date}      - Current date using timestamp format")
  print("    {datetime}  - Current date and time (%Y-%m-%d_%H-%M-%S)")
  print("    {suffix}    - The report suffix if specified")
  
  print("\nExamples:")
  print("  run_tests.lua                     Run all tests in ./tests")
  print("  run_tests.lua specific_test.lua   Run a specific test file")
  print("  run_tests.lua --watch             Run all tests and watch for changes")
  print("  run_tests.lua --interactive       Start interactive CLI mode")
  print("  run_tests.lua --output-dir ./reports --report-suffix \"-$(date +%Y%m%d)\"")
  print("  run_tests.lua --coverage-path \"coverage-{date}.{format}\"")
  os.exit(0)
end

local i = 1
while i <= #arg do
  if arg[i] == "--help" or arg[i] == "-h" then
    print_usage()
  elseif arg[i] == "--dir" and arg[i+1] then
    dir = arg[i+1]
    i = i + 2
  elseif arg[i] == "--pattern" and arg[i+1] then
    pattern = arg[i+1]
    i = i + 2
  elseif arg[i] == "--fix" then
    codefix_enabled = true
    codefix_command = "fix"
    
    if arg[i+1] and not arg[i+1]:match("^%-%-") then
      codefix_target = arg[i+1]
      i = i + 2
    else
      codefix_target = "."
      i = i + 1
    end
  elseif arg[i] == "--check" and arg[i+1] then
    codefix_enabled = true
    codefix_command = "check"
    codefix_target = arg[i+1]
    i = i + 2
  elseif arg[i] == "--watch" then
    watch_mode_enabled = true
    i = i + 1
  elseif arg[i] == "--watch-dir" and arg[i+1] then
    -- Reset the default directory if this is the first watch dir
    if #watch_dirs == 1 and watch_dirs[1] == "." then
      watch_dirs = {}
    end
    table.insert(watch_dirs, arg[i+1])
    i = i + 2
  elseif arg[i] == "--watch-interval" and arg[i+1] then
    watch_interval = tonumber(arg[i+1]) or 1.0
    i = i + 2
  elseif arg[i] == "--exclude" and arg[i+1] then
    table.insert(exclude_patterns, arg[i+1])
    i = i + 2
  elseif arg[i] == "--interactive" or arg[i] == "-i" then
    interactive_mode_enabled = true
    i = i + 1
  -- Report configuration options
  elseif arg[i] == "--output-dir" and arg[i+1] then
    report_config.report_dir = arg[i+1]
    i = i + 2
  elseif arg[i] == "--report-suffix" and arg[i+1] then
    report_config.report_suffix = arg[i+1]
    i = i + 2
  elseif arg[i] == "--coverage-path" and arg[i+1] then
    report_config.coverage_path_template = arg[i+1]
    i = i + 2
  elseif arg[i] == "--quality-path" and arg[i+1] then
    report_config.quality_path_template = arg[i+1]
    i = i + 2
  elseif arg[i] == "--results-path" and arg[i+1] then
    report_config.results_path_template = arg[i+1]
    i = i + 2
  elseif arg[i] == "--timestamp-format" and arg[i+1] then
    report_config.timestamp_format = arg[i+1]
    i = i + 2
  elseif arg[i] == "--verbose-reports" then
    report_config.verbose = true
    i = i + 1
  elseif arg[i] == "--results-format" and arg[i+1] then
    report_config.results_format = arg[i+1]
    i = i + 2
  elseif arg[i]:match("%.lua$") then
    run_single_file = arg[i]
    i = i + 1
  else
    i = i + 1
  end
end

-- Check if codefix is requested
if codefix_enabled then
  -- Try to load codefix module
  local codefix, err
  local ok, loaded = pcall(function() codefix = require("src.codefix") end)
  
  if not ok or not codefix then
    print("Error: Codefix module not found: " .. (err or "unknown error"))
    os.exit(1)
  end
  
  -- Initialize codefix module
  codefix.init({
    enabled = true,
    verbose = true
  })
  
  -- Run the requested command
  print("\n" .. string.rep("-", 60))
  print("RUNNING CODEFIX: " .. codefix_command .. " " .. (codefix_target or ""))
  print(string.rep("-", 60))
  
  local codefix_args = {codefix_command, codefix_target}
  success = codefix.run_cli(codefix_args)
  
  -- Exit with appropriate status
  os.exit(success and 0 or 1)
end

-- Add reset method to lust if not present
if not lust_next.reset then
  lust_next.reset = function()
    lust_next.level = 0
    lust_next.passes = 0
    lust_next.errors = 0
    lust_next.befores = {}
    lust_next.afters = {}
    lust_next.focus_mode = false
    collectgarbage()
  end
end

-- Run tests
local success = false

-- Configure reporting options in lust_next
if reporting then
  -- Pass the report configuration to lust_next
  lust_next.report_config = report_config
  
  -- Update the coverage and quality options to use the report configuration
  if lust_next.coverage_options then
    lust_next.coverage_options.report_config = report_config
  end
  
  if lust_next.quality_options then
    lust_next.quality_options.report_config = report_config
  end
end

-- Check for interactive mode first
if interactive_mode_enabled then
  -- Try to load interactive module
  local interactive, err
  local ok, loaded = pcall(function() interactive = require("src.interactive") end)
  
  if not ok or not interactive then
    print("Error: Interactive module not found: " .. (err or "unknown error"))
    os.exit(1)
  end
  
  -- Start interactive mode
  local options = {
    test_dir = dir,
    pattern = pattern,
    watch_mode = watch_mode_enabled,
    watch_dirs = watch_dirs,
    watch_interval = watch_interval,
    exclude_patterns = exclude_patterns,
    report_config = report_config  -- Pass report config to interactive mode
  }
  
  success = interactive.start(lust_next, options)
  os.exit(success and 0 or 1)
-- Check for watch mode  
elseif watch_mode_enabled then
  -- Determine test directories
  local test_dirs = {dir}
  
  -- Run tests in watch mode
  success = runner.watch_mode(
    watch_dirs, 
    test_dirs, 
    lust_next, 
    {
      pattern = pattern,
      exclude_patterns = exclude_patterns,
      interval = watch_interval,
      report_config = report_config,  -- Pass report config to watch mode
      results_format = report_config.results_format, -- Pass results format
      json_output = report_config.results_format == "json" -- Enable JSON output if needed
    }
  )
else
  -- Normal run mode
  if run_single_file then
    -- Run a single test file
    local runner_options = {
      results_format = report_config.results_format,
      json_output = report_config.results_format == "json"
    }
    local results = runner.run_file(run_single_file, lust_next, runner_options)
    success = results.success and results.errors == 0
  else
    -- Find and run all tests
    local files = discover.find_tests(dir, pattern)
    local runner_options = {
      results_format = report_config.results_format,
      json_output = report_config.results_format == "json"
    }
    success = runner.run_all(files, lust_next, runner_options)
  end
  
  -- Exit with appropriate status
  os.exit(success and 0 or 1)
end