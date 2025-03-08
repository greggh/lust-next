-- Test runner for lust-next
local runner = {}

-- Try to load watcher module if available
local watcher
local has_watcher = pcall(function() watcher = require("src.watcher") end)

local red = string.char(27) .. '[31m'
local green = string.char(27) .. '[32m'
local yellow = string.char(27) .. '[33m'
local cyan = string.char(27) .. '[36m'
local normal = string.char(27) .. '[0m'

-- Run a specific test file
function runner.run_file(file_path, lust, options)
  options = options or {}
  
  -- Initialize counter properties if they don't exist
  if lust.passes == nil then lust.passes = 0 end
  if lust.errors == nil then lust.errors = 0 end
  if lust.skipped == nil then lust.skipped = 0 end
  
  local prev_passes = lust.passes
  local prev_errors = lust.errors
  local prev_skipped = lust.skipped
  
  print("\nRunning file: " .. file_path)
  
  -- Count PASS/FAIL from test output
  local pass_count = 0
  local fail_count = 0
  local skip_count = 0
  
  -- Keep track of the original print function
  local original_print = print
  local output_buffer = {}
  
  -- Override print to count test results
  _G.print = function(...)
    local output = table.concat({...}, " ")
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
    -- Ensure proper package path for test file
    local save_path = package.path
    local dir = file_path:match("(.*[/\\])")
    if dir then
      package.path = dir .. "?.lua;" .. dir .. "../?.lua;" .. package.path
    end
    
    dofile(file_path)
    
    package.path = save_path
  end)
  local elapsed_time = os.clock() - start_time
  
  -- Restore original print function
  _G.print = original_print
  
  -- Use counted results if available, otherwise use lust counters
  local results = {
    success = success,
    error = err,
    passes = pass_count > 0 and pass_count or (lust.passes - prev_passes),
    errors = fail_count > 0 and fail_count or (lust.errors - prev_errors),
    skipped = skip_count > 0 and skip_count or (lust.skipped - prev_skipped),
    total = 0,
    elapsed = elapsed_time,
    output = table.concat(output_buffer, "\n")
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
          file = file_path
        })
      end
    end
  end
  
  if not success then
    print(red .. "ERROR: " .. err .. normal)
    table.insert(results.test_errors, {
      message = tostring(err),
      file = file_path,
      traceback = debug.traceback()
    })
  else
    -- Always show the completion status with test counts
    print(green .. "Completed with " .. results.passes .. " passes, " 
         .. results.errors .. " failures, "
         .. results.skipped .. " skipped" .. normal)
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
        success = success and results.errors == 0
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
              status = status
            }
            
            -- Add failure details if available
            if status == "fail" then
              test_case.failure = {
                message = "Test failed: " .. name,
                type = "Assertion",
                details = ""
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
          status = (success and results.errors == 0) and "pass" or "fail"
        })
      end
      
      -- Format as JSON with markers for parallel execution
      local json_results = json_module.encode(test_results)
      print("\nRESULTS_JSON_BEGIN" .. json_results .. "RESULTS_JSON_END")
    end
  end
  
  return results
end

-- Run tests in a directory
function runner.run_all(files, lust, options)
  options = options or {}
  
  print(green .. "Running " .. #files .. " test files" .. normal)
  
  local passed_files = 0
  local failed_files = 0
  local total_passes = 0
  local total_failures = 0
  local total_skipped = 0
  local start_time = os.clock()
  
  for _, file in ipairs(files) do
    local results = runner.run_file(file, lust, options)
    
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
  
  print("\n" .. string.rep("-", 60))
  print("File Summary: " .. green .. passed_files .. " passed" .. normal .. ", " .. 
        (failed_files > 0 and red or green) .. failed_files .. " failed" .. normal)
  print("Test Summary: " .. green .. total_passes .. " passed" .. normal .. ", " .. 
        (total_failures > 0 and red or green) .. total_failures .. " failed" .. normal .. 
        ", " .. yellow .. total_skipped .. " skipped" .. normal)
  print("Total time: " .. string.format("%.2f", elapsed_time) .. " seconds")
  print(string.rep("-", 60))
  
  local all_passed = failed_files == 0
  if not all_passed then
    print(red .. "✖ Some tests failed" .. normal)
  else
    print(green .. "✓ All tests passed" .. normal)
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
        name = "lust-next-tests",
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
        tests = total_passes + total_failures + total_skipped,
        failures = total_failures,
        errors = 0,
        skipped = total_skipped,
        time = elapsed_time,
        files_tested = #files,
        files_passed = passed_files,
        files_failed = failed_files,
        success = all_passed
      }
      
      -- Format as JSON with markers for parallel execution
      local json_results = json_module.encode(test_results)
      print("\nRESULTS_JSON_BEGIN" .. json_results .. "RESULTS_JSON_END")
    end
  end
  
  return all_passed
end

-- Watch mode for continuous testing
function runner.watch_mode(directories, test_dirs, lust, options)
  if not has_watcher then
    print(red .. "Error: Watch mode requires the watcher module" .. normal)
    return false
  end
  
  options = options or {}
  local exclude_patterns = options.exclude_patterns or {"node_modules", "%.git"}
  local watch_interval = options.interval or 1.0
  
  -- Initialize the file watcher
  print(cyan .. "\n--- WATCH MODE ACTIVE ---" .. normal)
  print("Press Ctrl+C to exit")
  
  watcher.set_check_interval(watch_interval)
  watcher.init(directories, exclude_patterns)
  
  -- Initial test run
  local discover = require("discover")
  local files = {}
  
  for _, dir in ipairs(test_dirs) do
    local found = discover.find_tests(dir, options.pattern or "*_test.lua") 
    for _, file in ipairs(found) do
      table.insert(files, file)
    end
  end
  
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
      
      print(yellow .. "\nFile changes detected:" .. normal)
      for _, file in ipairs(changed_files) do
        print("  - " .. file)
      end
    end
    
    -- Run tests if needed and after debounce period
    if need_to_run and current_time - last_change_time >= debounce_time then
      print(cyan .. "\n--- RUNNING TESTS ---" .. normal)
      print(os.date("%Y-%m-%d %H:%M:%S"))
      
      -- Clear terminal
      io.write("\027[2J\027[H")
      
      lust.reset()
      run_success = runner.run_all(files, lust, runner_options)
      last_run_time = current_time
      need_to_run = false
      
      print(cyan .. "\n--- WATCHING FOR CHANGES ---" .. normal)
    end
    
    -- Small sleep to prevent CPU hogging
    os.execute("sleep 0.1")
  end
  
  return run_success
end

return runner