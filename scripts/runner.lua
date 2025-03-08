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
function runner.run_file(file_path, lust)
  local prev_passes = lust.passes
  local prev_errors = lust.errors
  
  print("\nRunning file: " .. file_path)
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
  
  local results = {
    success = success,
    error = err,
    passes = lust.passes - prev_passes,
    errors = lust.errors - prev_errors
  }
  
  if not success then
    print(red .. "ERROR: " .. err .. normal)
  else
    print(green .. "Completed with " .. results.passes .. " passes, " 
         .. results.errors .. " failures" .. normal)
  end
  
  return results
end

-- Run tests in a directory
function runner.run_all(files, lust)
  print(green .. "Running " .. #files .. " test files" .. normal)
  
  local passed = 0
  local failed = 0
  
  for _, file in ipairs(files) do
    local results = runner.run_file(file, lust)
    if results.success and results.errors == 0 then
      passed = passed + 1
    else
      failed = failed + 1
    end
  end
  
  print("\n" .. string.rep("-", 60))
  print("Test Summary: " .. green .. passed .. " passed" .. normal .. ", " .. 
        (failed > 0 and red or green) .. failed .. " failed" .. normal)
  print(string.rep("-", 60))
  
  local all_passed = failed == 0
  if not all_passed then
    print(red .. "✖ Some tests failed" .. normal)
  else
    print(green .. "✓ All tests passed" .. normal)
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
      run_success = runner.run_all(files, lust)
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