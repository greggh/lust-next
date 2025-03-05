-- Test discovery module for lust-next
local discover = {}

-- Find test files in a directory
function discover.find_tests(dir)
  dir = dir or "./tests"
  local files = {}
  
  -- Platform-specific command to find test files
  local command
  if package.config:sub(1,1) == '\\' then
    -- Windows
    command = 'dir /s /b "' .. dir .. '\\*_test.lua" > lust_temp_files.txt'
  else
    -- Unix
    command = 'find "' .. dir .. '" -name "*_test.lua" -type f > lust_temp_files.txt'
  end
  
  -- Execute the command
  os.execute(command)
  
  -- Read the results from the temporary file
  local file = io.open("lust_temp_files.txt", "r")
  if file then
    for line in file:lines() do
      if line:match("_test%.lua$") then
        table.insert(files, line)
      end
    end
    file:close()
    os.remove("lust_temp_files.txt")
  end
  
  return files
end

return discover