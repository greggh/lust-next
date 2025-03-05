-- Test runner for lust-next
local runner = {}

local red = string.char(27) .. '[31m'
local green = string.char(27) .. '[32m'
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
  
  if failed > 0 then
    print(red .. "✖ Some tests failed" .. normal)
    return false
  else
    print(green .. "✓ All tests passed" .. normal)
    return true
  end
end

return runner