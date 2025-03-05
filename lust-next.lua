-- lust-next v0.3.0 - Enhanced Lua test framework
-- https://github.com/greggh/lust-next
-- MIT LICENSE
-- Based on lust by Bjorn Swenson (https://github.com/bjornbytes/lust)

local lust_next = {}
lust_next.level = 0
lust_next.passes = 0
lust_next.errors = 0
lust_next.befores = {}
lust_next.afters = {}
lust_next.version = "0.3.0"

local red = string.char(27) .. '[31m'
local green = string.char(27) .. '[32m'
local normal = string.char(27) .. '[0m'
local function indent(level) return string.rep('\t', level or lust_next.level) end

function lust_next.nocolor()
  red, green, normal = '', '', ''
  return lust_next
end

function lust_next.describe(name, fn)
  print(indent() .. name)
  lust_next.level = lust_next.level + 1
  fn()
  lust_next.befores[lust_next.level] = {}
  lust_next.afters[lust_next.level] = {}
  lust_next.level = lust_next.level - 1
end

function lust_next.it(name, fn)
  for level = 1, lust_next.level do
    if lust_next.befores[level] then
      for i = 1, #lust_next.befores[level] do
        lust_next.befores[level][i](name)
      end
    end
  end

  local success, err = pcall(fn)
  if success then lust_next.passes = lust_next.passes + 1
  else lust_next.errors = lust_next.errors + 1 end
  local color = success and green or red
  local label = success and 'PASS' or 'FAIL'
  print(indent() .. color .. label .. normal .. ' ' .. name)
  if err then
    print(indent(lust_next.level + 1) .. red .. tostring(err) .. normal)
  end

  for level = 1, lust_next.level do
    if lust_next.afters[level] then
      for i = 1, #lust_next.afters[level] do
        lust_next.afters[level][i](name)
      end
    end
  end
end

function lust_next.before(fn)
  lust_next.befores[lust_next.level] = lust_next.befores[lust_next.level] or {}
  table.insert(lust_next.befores[lust_next.level], fn)
end

function lust_next.after(fn)
  lust_next.afters[lust_next.level] = lust_next.afters[lust_next.level] or {}
  table.insert(lust_next.afters[lust_next.level], fn)
end

-- Assertions
local function isa(v, x)
  if type(x) == 'string' then
    return type(v) == x,
      'expected ' .. tostring(v) .. ' to be a ' .. x,
      'expected ' .. tostring(v) .. ' to not be a ' .. x
  elseif type(x) == 'table' then
    if type(v) ~= 'table' then
      return false,
        'expected ' .. tostring(v) .. ' to be a ' .. tostring(x),
        'expected ' .. tostring(v) .. ' to not be a ' .. tostring(x)
    end

    local seen = {}
    local meta = v
    while meta and not seen[meta] do
      if meta == x then return true end
      seen[meta] = true
      meta = getmetatable(meta) and getmetatable(meta).__index
    end

    return false,
      'expected ' .. tostring(v) .. ' to be a ' .. tostring(x),
      'expected ' .. tostring(v) .. ' to not be a ' .. tostring(x)
  end

  error('invalid type ' .. tostring(x))
end

local function has(t, x)
  for k, v in pairs(t) do
    if v == x then return true end
  end
  return false
end

local function eq(t1, t2, eps)
  if type(t1) ~= type(t2) then return false end
  if type(t1) == 'number' then return math.abs(t1 - t2) <= (eps or 0) end
  if type(t1) ~= 'table' then return t1 == t2 end
  for k, _ in pairs(t1) do
    if not eq(t1[k], t2[k], eps) then return false end
  end
  for k, _ in pairs(t2) do
    if not eq(t2[k], t1[k], eps) then return false end
  end
  return true
end

local function stringify(t)
  if type(t) == 'string' then return "'" .. tostring(t) .. "'" end
  if type(t) ~= 'table' or getmetatable(t) and getmetatable(t).__tostring then return tostring(t) end
  local strings = {}
  for i, v in ipairs(t) do
    strings[#strings + 1] = stringify(v)
  end
  for k, v in pairs(t) do
    if type(k) ~= 'number' or k > #t or k < 1 then
      strings[#strings + 1] = ('[%s] = %s'):format(stringify(k), stringify(v))
    end
  end
  return '{ ' .. table.concat(strings, ', ') .. ' }'
end

local paths = {
  [''] = { 'to', 'to_not' },
  to = { 'have', 'equal', 'be', 'exist', 'fail', 'match' },
  to_not = { 'have', 'equal', 'be', 'exist', 'fail', 'match', chain = function(a) a.negate = not a.negate end },
  a = { test = isa },
  an = { test = isa },
  be = { 'a', 'an', 'truthy',
    test = function(v, x)
      return v == x,
        'expected ' .. tostring(v) .. ' and ' .. tostring(x) .. ' to be the same',
        'expected ' .. tostring(v) .. ' and ' .. tostring(x) .. ' to not be the same'
    end
  },
  exist = {
    test = function(v)
      return v ~= nil,
        'expected ' .. tostring(v) .. ' to exist',
        'expected ' .. tostring(v) .. ' to not exist'
    end
  },
  truthy = {
    test = function(v)
      return v,
        'expected ' .. tostring(v) .. ' to be truthy',
        'expected ' .. tostring(v) .. ' to not be truthy'
    end
  },
  equal = {
    test = function(v, x, eps)
      local comparison = ''
      local equal = eq(v, x, eps)

      if not equal and (type(v) == 'table' or type(x) == 'table') then
        comparison = comparison .. '\n' .. indent(lust_next.level + 1) .. 'LHS: ' .. stringify(v)
        comparison = comparison .. '\n' .. indent(lust_next.level + 1) .. 'RHS: ' .. stringify(x)
      end

      return equal,
        'expected ' .. tostring(v) .. ' and ' .. tostring(x) .. ' to be equal' .. comparison,
        'expected ' .. tostring(v) .. ' and ' .. tostring(x) .. ' to not be equal'
    end
  },
  have = {
    test = function(v, x)
      if type(v) ~= 'table' then
        error('expected ' .. tostring(v) .. ' to be a table')
      end

      return has(v, x),
        'expected ' .. tostring(v) .. ' to contain ' .. tostring(x),
        'expected ' .. tostring(v) .. ' to not contain ' .. tostring(x)
    end
  },
  fail = { 'with',
    test = function(v)
      return not pcall(v),
        'expected ' .. tostring(v) .. ' to fail',
        'expected ' .. tostring(v) .. ' to not fail'
    end
  },
  with = {
    test = function(v, pattern)
      local ok, message = pcall(v)
      return not ok and message:match(pattern),
        'expected ' .. tostring(v) .. ' to fail with error matching "' .. pattern .. '"',
        'expected ' .. tostring(v) .. ' to not fail with error matching "' .. pattern .. '"'
    end
  },
  match = {
    test = function(v, p)
      if type(v) ~= 'string' then v = tostring(v) end
      local result = string.find(v, p)
      return result ~= nil,
        'expected ' .. v .. ' to match pattern [[' .. p .. ']]',
        'expected ' .. v .. ' to not match pattern [[' .. p .. ']]'
    end
  }
}

function lust_next.expect(v)
  local assertion = {}
  assertion.val = v
  assertion.action = ''
  assertion.negate = false

  setmetatable(assertion, {
    __index = function(t, k)
      if has(paths[rawget(t, 'action')], k) then
        rawset(t, 'action', k)
        local chain = paths[rawget(t, 'action')].chain
        if chain then chain(t) end
        return t
      end
      return rawget(t, k)
    end,
    __call = function(t, ...)
      if paths[t.action].test then
        local res, err, nerr = paths[t.action].test(t.val, ...)
        if assertion.negate then
          res = not res
          err = nerr or err
        end
        if not res then
          error(err or 'unknown failure', 2)
        end
      end
    end
  })

  return assertion
end

function lust_next.spy(target, name, run)
  local spy = {}
  local subject

  local function capture(...)
    table.insert(spy, {...})
    return subject(...)
  end

  if type(target) == 'table' then
    subject = target[name]
    target[name] = capture
  else
    run = name
    subject = target or function() end
  end

  setmetatable(spy, {__call = function(_, ...) return capture(...) end})

  if run then run() end

  return spy
end

-- Test Discovery System
-- Simplified test discovery for self-running
function lust_next.discover(root_dir, pattern)
  root_dir = root_dir or "."
  pattern = pattern or "**/*_test.lua"
  
  -- For better test discovery, use scripts/run_tests.lua
  if pattern ~= "**/*_test.lua" and pattern ~= "*_test.lua" then
    print("Warning: Complex pattern matching not fully supported in built-in discover")
    print("For better test discovery, use scripts/run_tests.lua")
  end
  
  local test_files = {}
  
  -- Platform-specific directory listing implementation
  local function list_directory(dir)
    local files = {}
    local handle, err
    
    if package.config:sub(1,1) == '\\' then
      -- Windows implementation
      local result = io.popen('dir /b "' .. dir .. '"')
      if result then
        for name in result:lines() do
          table.insert(files, name)
        end
        result:close()
      end
    else
      -- Unix implementation
      local result = io.popen('ls -a "' .. dir .. '" 2>/dev/null')
      if result then
        for name in result:lines() do
          if name ~= "." and name ~= ".." then
            table.insert(files, name)
          end
        end
        result:close()
      end
    end
    
    return files
  end
  
  -- Get file type (directory or file)
  local function get_file_type(path)
    local success, result
    
    if package.config:sub(1,1) == '\\' then
      -- Windows implementation
      local cmd = 'if exist "' .. path .. '\\*" (echo directory) else (echo file)'
      success, result = pcall(function()
        local p = io.popen(cmd)
        local output = p:read('*l')
        p:close()
        return output
      end)
    else
      -- Unix implementation
      success, result = pcall(function()
        local p = io.popen('test -d "' .. path .. '" && echo directory || echo file')
        local output = p:read('*l')
        p:close()
        return output
      end)
    end
    
    if success and result then
      return result:match("directory") and "directory" or "file"
    else
      -- Default to file if we can't determine
      return "file"
    end
  end
  
  -- Simple pattern matching (supports basic glob patterns)
  local function match_pattern(name, pattern)
    -- For simplicity, we'll do a more direct pattern match for now
    if pattern == "**/*_test.lua" then
      return name:match("_test%.lua$") ~= nil
    elseif pattern == "*_test.lua" then
      return name:match("_test%.lua$") ~= nil
    else
      -- Fallback to basic ending match
      local ending = pattern:gsub("*", "")
      return name:match(ending:gsub("%.", "%%.") .. "$") ~= nil
    end
  end
  
  -- Get test files directly using os.execute and capturing output
  local files = {}
  
  -- Determine the command to run based on the platform
  local command
  if package.config:sub(1,1) == '\\' then
    -- Windows
    command = 'dir /s /b "' .. root_dir .. '\\*_test.lua" > lust_temp_files.txt'
  else
    -- Unix
    command = 'find "' .. root_dir .. '" -name "*_test.lua" -type f > lust_temp_files.txt'
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

-- Process a single test file
local function process_test_file(file, results)
  -- Reset state before each file
  local prev_passes = lust_next.passes
  local prev_errors = lust_next.errors
  
  print("\nFile: " .. file)
  local success, err = pcall(function()
    dofile(file)
  end)
  
  if not success then
    results.failed_files = results.failed_files + 1
    table.insert(results.failures, {
      file = file,
      error = "Error loading file: " .. err
    })
    print(red .. "ERROR: " .. err .. normal)
  else
    local file_passes = lust_next.passes - prev_passes
    local file_errors = lust_next.errors - prev_errors
    
    results.total_tests = results.total_tests + file_passes + file_errors
    results.passed_tests = results.passed_tests + file_passes
    results.failed_tests = results.failed_tests + file_errors
    
    if file_errors > 0 then
      results.failed_files = results.failed_files + 1
    else
      results.passed_files = results.passed_files + 1
    end
  end
end

-- Run discovered tests
function lust_next.run_discovered(root_dir, pattern)
  local files = lust_next.discover(root_dir, pattern)
  local results = {
    total_files = #files,
    passed_files = 0,
    failed_files = 0,
    total_tests = 0,
    passed_tests = 0,
    failed_tests = 0,
    failures = {}
  }
  
  -- Initial pass/error counters
  local initial_passes = lust_next.passes
  local initial_errors = lust_next.errors
  
  print("\n" .. green .. "Running " .. #files .. " test files" .. normal)
  print(string.rep("-", 70))
  
  -- Process each file
  for _, file in ipairs(files) do
    process_test_file(file, results)
  end
  
  -- Print summary
  print("\n" .. string.rep("-", 70))
  print("Test Summary:")
  print(string.rep("-", 70))
  
  -- File statistics
  local total_color = results.failed_files > 0 and red or green
  print("Files:  " .. total_color .. results.passed_files .. "/" 
       .. results.total_files .. normal 
       .. " (" .. (results.total_files > 0 and math.floor(results.passed_files/results.total_files*100) or 0) .. "% passed)")
  
  -- Test statistics
  total_color = results.failed_tests > 0 and red or green
  print("Tests:  " .. total_color .. results.passed_tests .. "/" 
       .. results.total_tests .. normal 
       .. " (" .. (results.total_tests > 0 and math.floor(results.passed_tests/results.total_tests*100) or 0) .. "% passed)")
  
  -- List failures
  if #results.failures > 0 then
    print("\n" .. red .. "Failures:" .. normal)
    for i, failure in ipairs(results.failures) do
      print(i .. ") " .. failure.file)
      if failure.error then
        print("   " .. failure.error)
      end
    end
  end
  
  print(string.rep("-", 70))
  
  if results.failed_tests > 0 then
    print(red .. "✖ Tests Failed" .. normal)
  else
    print(green .. "✓ All Tests Passed" .. normal)
  end
  
  print(string.rep("-", 70) .. "\n")
  
  return results
end

-- Run a single test file
function lust_next.run_file(file_path)
  local prev_passes = lust_next.passes
  local prev_errors = lust_next.errors
  
  print("\nRunning file: " .. file_path)
  local success, err = pcall(function()
    local function run_test()
      -- Set the package path to include the directory of the test file
      local dir = file_path:match("(.*[/\\])")
      package.path = dir .. "?.lua;" .. dir .. "../?.lua;" .. package.path
      dofile(file_path)
    end
    
    run_test()
  end)
  
  local results = {
    success = success,
    error = err,
    passes = lust_next.passes - prev_passes,
    errors = lust_next.errors - prev_errors
  }
  
  if not success then
    print(red .. "ERROR: " .. err .. normal)
  else
    print(green .. "Completed with " .. results.passes .. " passes, " 
         .. results.errors .. " failures" .. normal)
  end
  
  return results
end

-- CLI runner that finds and runs tests
function lust_next.cli_run(dir)
  dir = dir or "./tests"
  local files = lust_next.discover(dir)
  
  print(green .. "Running " .. #files .. " test files" .. normal)
  
  local passed = 0
  local failed = 0
  
  for _, file in ipairs(files) do
    local results = lust_next.run_file(file)
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

-- Aliases and exports
lust_next.test = lust_next.it
lust_next.paths = paths

-- Command-line runner
if arg and (arg[0]:match("lust_next.lua$") or arg[0]:match("lust%-next.lua$")) then
  if #arg >= 1 then
    if arg[1]:match("%.lua$") then
      -- Run a specific test file
      local results = lust_next.run_file(arg[1])
      if not results.success or results.errors > 0 then
        os.exit(1)
      else
        os.exit(0)
      end
    elseif arg[1] == "--dir" and arg[2] then
      -- Run tests in specified directory
      local success = lust_next.cli_run(arg[2])
      os.exit(success and 0 or 1)
    end
  else
    -- Run all tests
    local success = lust_next.cli_run()
    os.exit(success and 0 or 1)
  end
end

-- Backward compatibility for users upgrading from lust
local lust = setmetatable({}, {
  __index = function(_, key)
    print("Warning: Using 'lust' directly is deprecated, please use 'lust_next' instead")
    return lust_next[key]
  end
})

return lust_next
