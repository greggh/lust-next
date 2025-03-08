-- Parallel test execution module for lust-next
-- Provides functionality to run test files in parallel for better resource utilization

local parallel = {}

-- Default configuration
parallel.options = {
  workers = 4,                 -- Default number of worker processes
  timeout = 60,                -- Default timeout in seconds per test file
  output_buffer_size = 10240,  -- Buffer size for capturing output
  verbose = false,             -- Verbose output flag
  show_worker_output = true,   -- Show output from worker processes
  fail_fast = false,           -- Stop on first failure
  aggregate_coverage = true,   -- Combine coverage data from all workers
}

-- Store reference to lust-next
parallel.lust_next = nil

-- Test result aggregation
local Results = {}
Results.__index = Results

function Results.new()
  local self = setmetatable({}, Results)
  self.passed = 0
  self.failed = 0
  self.skipped = 0
  self.pending = 0
  self.total = 0
  self.errors = {}
  self.elapsed = 0
  self.coverage = {}
  self.files_run = {}
  return self
end

function Results:add_file_result(file, result)
  self.total = self.total + result.total
  self.passed = self.passed + result.passed
  self.failed = self.failed + result.failed
  self.skipped = self.skipped + result.skipped
  self.pending = self.pending + result.pending
  
  if result.elapsed then
    self.elapsed = self.elapsed + result.elapsed
  end
  
  -- Add file to list of run files
  table.insert(self.files_run, file)
  
  -- Add any errors
  if result.errors and #result.errors > 0 then
    for _, err in ipairs(result.errors) do
      table.insert(self.errors, {
        file = file,
        message = err.message,
        traceback = err.traceback
      })
    end
  end
  
  -- Add coverage data if available
  if result.coverage and parallel.options.aggregate_coverage then
    for file_path, file_data in pairs(result.coverage) do
      -- Merge coverage data
      if not self.coverage[file_path] then
        self.coverage[file_path] = file_data
      else
        -- Merge line coverage
        if file_data.lines then
          for line, count in pairs(file_data.lines) do
            self.coverage[file_path].lines[line] = (self.coverage[file_path].lines[line] or 0) + count
          end
        end
        
        -- Merge function coverage
        if file_data.functions then
          for func, count in pairs(file_data.functions) do
            self.coverage[file_path].functions[func] = (self.coverage[file_path].functions[func] or 0) + count
          end
        end
      end
    end
  end
end

-- Helper function to run a test file in a separate process
local function run_test_file(file, options)
  -- Build command to run test file
  local cmd = "lua " .. file
  
  -- Add coverage option if enabled
  if options.coverage then
    cmd = cmd .. " --coverage"
  end
  
  -- Add tag filters if specified
  if options.tags and #options.tags > 0 then
    for _, tag in ipairs(options.tags) do
      cmd = cmd .. " --tag " .. tag
    end
  end
  
  -- Add filter pattern if specified
  if options.filter then
    cmd = cmd .. " --filter \"" .. options.filter .. "\""
  end
  
  -- Add option to output results as JSON for parsing
  cmd = cmd .. " --results-format json"
  
  -- Add timeout
  local timeout_cmd = ""
  if package.config:sub(1,1) == "\\" then
    -- Windows - timeout not directly available, but we can use timeout.exe from coreutils if available
    timeout_cmd = "timeout " .. options.timeout .. " "
  else
    -- Unix systems have timeout command
    timeout_cmd = "timeout " .. options.timeout .. " "
  end
  
  -- Combine commands
  cmd = timeout_cmd .. cmd
  
  -- Execute command and capture output
  local start_time = os.clock()
  local result_file = os.tmpname()
  
  -- Redirect output to temporary file to capture it
  cmd = cmd .. " > " .. result_file .. " 2>&1"
  
  if options.verbose then
    print("Running: " .. cmd)
  end
  
  -- Execute the command
  local exit_code = os.execute(cmd)
  local elapsed = os.clock() - start_time
  
  -- Read the command output
  local output = ""
  local f = io.open(result_file, "r")
  if f then
    output = f:read("*a")
    f:close()
    os.remove(result_file)
  end
  
  -- Parse the JSON results from the output
  local result = {
    total = 0,
    passed = 0,
    failed = 0,
    skipped = 0,
    pending = 0,
    errors = {},
    elapsed = elapsed,
    success = exit_code == 0 or exit_code == true
  }
  
  -- Extract JSON data from the output if present
  local json_data = output:match("RESULTS_JSON_BEGIN(.-)RESULTS_JSON_END")
  if json_data then
    local json_loaded, json_module = pcall(require, "lib.reporting.json")
    if json_loaded then
      local parse_ok, parsed_data = pcall(json_module.decode, json_data)
      if parse_ok and parsed_data then
        result = parsed_data
        result.elapsed = elapsed -- Add elapsed time
      end
    end
  end
  
  return {
    result = result,
    output = output,
    elapsed = elapsed,
    success = exit_code == 0 or exit_code == true
  }
end

-- Run tests in parallel across multiple processes
function parallel.run_tests(files, options)
  options = options or {}
  
  -- Merge with default options
  for k, v in pairs(parallel.options) do
    if options[k] == nil then
      options[k] = v
    end
  end
  
  if options.verbose then
    print("Running " .. #files .. " test files with " .. options.workers .. " workers")
  end
  
  -- Create results object
  local results = Results.new()
  local start_time = os.clock()
  
  -- Set up worker tracking
  local next_file = 1
  local active_workers = 0
  local failures = 0
  
  -- Process test files in batches
  while next_file <= #files or active_workers > 0 do
    -- Start new workers until we reach the maximum or run out of files
    while active_workers < options.workers and next_file <= #files do
      local file = files[next_file]
      next_file = next_file + 1
      active_workers = active_workers + 1
      
      if options.verbose then
        print("Starting worker for: " .. file)
      end
      
      -- Run the test file and process results
      local worker_result = run_test_file(file, options)
      
      -- Show worker output if requested
      if options.show_worker_output then
        print("\n--- Output from " .. file .. " ---")
        print(worker_result.output)
        print("--- End output from " .. file .. " ---\n")
      end
      
      -- Add results to aggregated results
      results:add_file_result(file, worker_result.result)
      
      -- Check for failure
      if not worker_result.success then
        failures = failures + 1
        if options.fail_fast and failures > 0 then
          if options.verbose then
            print("Stopping due to failure (fail_fast is enabled)")
          end
          break
        end
      end
      
      -- Decrement active workers counter
      active_workers = active_workers - 1
      
      -- Add a small sleep to allow other processes to run
      local function sleep(ms)
        local start = os.clock()
        while os.clock() - start < ms/1000 do end
      end
      sleep(10) -- 10ms
    end
    
    -- If we're stopping due to failure, break the loop
    if options.fail_fast and failures > 0 then
      break
    end
    
    -- Small sleep to prevent CPU hogging
    if active_workers > 0 then
      local function sleep(ms)
        local start = os.clock()
        while os.clock() - start < ms/1000 do end
      end
      sleep(50) -- 50ms
    end
  end
  
  -- Calculate total elapsed time
  results.elapsed = os.clock() - start_time
  
  return results
end

-- Register with lust-next
function parallel.register_with_lust(lust_next)
  -- Store reference to lust-next
  parallel.lust_next = lust_next
  
  -- Add parallel functionality to lust-next
  lust_next.parallel = parallel
  
  -- Add CLI options for parallel execution
  local original_cli_run = lust_next.cli_run
  if original_cli_run then
    lust_next.cli_run = function(args)
      -- Parse for parallel-specific options
      local parallel_options = {
        enabled = false,
        workers = parallel.options.workers,
        timeout = parallel.options.timeout,
        verbose = parallel.options.verbose,
        show_worker_output = parallel.options.show_worker_output,
        fail_fast = parallel.options.fail_fast,
        aggregate_coverage = parallel.options.aggregate_coverage
      }
      
      local i = 1
      while i <= #args do
        local arg = args[i]
        
        if arg == "--parallel" or arg == "-p" then
          parallel_options.enabled = true
          i = i + 1
        elseif arg == "--workers" or arg == "-w" and args[i+1] then
          parallel_options.workers = tonumber(args[i+1]) or parallel.options.workers
          i = i + 2
        elseif arg == "--timeout" and args[i+1] then
          parallel_options.timeout = tonumber(args[i+1]) or parallel.options.timeout
          i = i + 2
        elseif arg == "--verbose-parallel" then
          parallel_options.verbose = true
          i = i + 1
        elseif arg == "--no-worker-output" then
          parallel_options.show_worker_output = false
          i = i + 1
        elseif arg == "--fail-fast" then
          parallel_options.fail_fast = true
          i = i + 1
        elseif arg == "--no-aggregate-coverage" then
          parallel_options.aggregate_coverage = false
          i = i + 1
        else
          i = i + 1
        end
      end
      
      -- If parallel mode is not enabled, use the original cli_run
      if not parallel_options.enabled then
        return original_cli_run(args)
      end
      
      -- If we get here, we're running in parallel mode
      local options = lust_next.parse_cli_options(args)
      
      -- Discover test files
      local files
      if #options.files > 0 then
        files = options.files
      else
        files = lust_next.discover(options.dir, options.pattern)
      end
      
      if #files == 0 then
        print("No test files found")
        return false
      end
      
      print("Running " .. #files .. " test files in parallel with " .. parallel_options.workers .. " workers")
      
      -- Run tests in parallel
      local results = parallel.run_tests(files, {
        workers = parallel_options.workers,
        timeout = parallel_options.timeout,
        verbose = parallel_options.verbose,
        show_worker_output = parallel_options.show_worker_output,
        fail_fast = parallel_options.fail_fast,
        aggregate_coverage = parallel_options.aggregate_coverage,
        coverage = options.coverage,
        tags = options.tags,
        filter = options.filter
      })
      
      -- Display summary
      print("\nParallel Test Summary:")
      print("  Files tested: " .. #results.files_run)
      print("  Total tests: " .. results.total)
      print("  Passed: " .. results.passed)
      print("  Failed: " .. results.failed)
      print("  Skipped: " .. results.skipped)
      print("  Pending: " .. results.pending)
      print("  Total time: " .. string.format("%.2f", results.elapsed) .. " seconds")
      
      -- Display errors
      if #results.errors > 0 then
        print("\nErrors:")
        for i, err in ipairs(results.errors) do
          print("  " .. i .. ". In file: " .. err.file)
          print("     " .. err.message)
          if parallel_options.verbose and err.traceback then
            print("     " .. err.traceback)
          end
        end
      end
      
      -- Generate reports if coverage was enabled
      if options.coverage and parallel_options.aggregate_coverage and lust_next.coverage then
        -- Convert coverage data to the format expected by the reporting module
        local coverage_data = {
          files = results.coverage,
          summary = {
            total_files = 0,
            covered_files = 0,
            total_lines = 0,
            covered_lines = 0,
            total_functions = 0,
            covered_functions = 0
          }
        }
        
        -- Generate reports
        if lust_next.reporting then
          local report_config = lust_next.report_config or {}
          lust_next.reporting.auto_save_reports(coverage_data, nil, nil, report_config)
          print("\nCoverage reports generated from parallel execution")
        end
      end
      
      -- Return success status
      return results.failed == 0
    end
  end
  
  -- Parse CLI options - helper function used by parallel mode
  function lust_next.parse_cli_options(args)
    local options = {
      dir = "./tests",
      pattern = "*_test.lua",
      files = {},
      tags = {},
      filter = nil,
      coverage = false,
      quality = false,
      quality_level = 1,
      watch = false,
      interactive = false,
      format = "html",
      report_dir = "./coverage-reports",
      report_suffix = "",
      coverage_path_template = nil,
      quality_path_template = nil,
      results_path_template = nil,
      timestamp_format = "%Y-%m-%d",
      verbose = false,
      formatter_module = nil,
      coverage_format = nil,
      quality_format = nil,
      results_format = nil
    }
    
    local i = 1
    while i <= #args do
      local arg = args[i]
      
      if arg == "--coverage" or arg == "-c" then
        options.coverage = true
        i = i + 1
      elseif arg == "--quality" or arg == "-q" then
        options.quality = true
        i = i + 1
      elseif arg == "--quality-level" or arg == "-ql" then
        if args[i+1] then
          options.quality_level = tonumber(args[i+1]) or 1
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--watch" or arg == "-w" then
        options.watch = true
        i = i + 1
      elseif arg == "--interactive" or arg == "-i" then
        options.interactive = true
        i = i + 1
      elseif arg == "--format" or arg == "-f" then
        if args[i+1] then
          options.format = args[i+1]
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--dir" or arg == "-d" then
        if args[i+1] then
          options.dir = args[i+1]
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--pattern" or arg == "-p" then
        if args[i+1] then
          options.pattern = args[i+1]
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--tag" or arg == "-t" then
        if args[i+1] then
          table.insert(options.tags, args[i+1])
          i = i + 2
        else
          i = i + 1
        end
      elseif arg == "--filter" and args[i+1] then
        options.filter = args[i+1]
        i = i + 2
      -- Report configuration options
      elseif arg == "--output-dir" and args[i+1] then
        options.report_dir = args[i+1]
        i = i + 2
      elseif arg == "--report-suffix" and args[i+1] then
        options.report_suffix = args[i+1]
        i = i + 2
      elseif arg == "--coverage-path" and args[i+1] then
        options.coverage_path_template = args[i+1]
        i = i + 2
      elseif arg == "--quality-path" and args[i+1] then
        options.quality_path_template = args[i+1]
        i = i + 2
      elseif arg == "--results-path" and args[i+1] then
        options.results_path_template = args[i+1]
        i = i + 2
      elseif arg == "--timestamp-format" and args[i+1] then
        options.timestamp_format = args[i+1]
        i = i + 2
      elseif arg == "--verbose-reports" then
        options.verbose = true
        i = i + 1
      -- Custom formatter options
      elseif arg == "--coverage-format" and args[i+1] then
        options.coverage_format = args[i+1]
        i = i + 2
      elseif arg == "--quality-format" and args[i+1] then
        options.quality_format = args[i+1]
        i = i + 2
      elseif arg == "--results-format" and args[i+1] then
        options.results_format = args[i+1]
        i = i + 2
      elseif arg == "--formatter-module" and args[i+1] then
        options.formatter_module = args[i+1]
        i = i + 2
      elseif arg == "--help" or arg == "-h" then
        i = i + 1
      elseif not arg:match("^%-") then
        -- Not a flag, assume it's a file
        table.insert(options.files, arg)
        i = i + 1
      else
        -- Skip unknown options
        i = i + 1
      end
    end
    
    return options
  end
  
  -- Extend help text to include parallel options
  local original_show_help = lust_next.show_help
  if original_show_help then
    lust_next.show_help = function()
      original_show_help()
      
      print("\nParallel Execution Options:")
      print("  --parallel, -p            Run tests in parallel")
      print("  --workers, -w <num>       Number of worker processes (default: 4)")
      print("  --timeout <seconds>       Timeout for each test file (default: 60)")
      print("  --verbose-parallel        Show verbose output from parallel execution")
      print("  --no-worker-output        Hide output from worker processes")
      print("  --fail-fast               Stop on first test failure")
      print("  --no-aggregate-coverage   Don't combine coverage data from workers")
    end
  end
  
  return lust_next
end

-- Return the module
return parallel