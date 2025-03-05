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
lust_next.active_tags = {}
lust_next.current_tags = {}
lust_next.filter_pattern = nil
lust_next.running_async = false
lust_next.async_timeout = 5000 -- Default timeout in ms

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
  
  -- Save current tags to restore them after the describe block
  local prev_tags = {}
  for i, tag in ipairs(lust_next.current_tags) do
    prev_tags[i] = tag
  end
  
  fn()
  
  -- Reset current tags to what they were before the describe block
  lust_next.current_tags = prev_tags
  
  lust_next.befores[lust_next.level] = {}
  lust_next.afters[lust_next.level] = {}
  lust_next.level = lust_next.level - 1
end

-- Set tags for the current describe block or test
function lust_next.tags(...)
  local tags = {...}
  lust_next.current_tags = tags
  return lust_next
end

-- Filter tests to only run those matching specific tags
function lust_next.only_tags(...)
  local tags = {...}
  lust_next.active_tags = tags
  return lust_next
end

-- Filter tests by name pattern
function lust_next.filter(pattern)
  lust_next.filter_pattern = pattern
  return lust_next
end

-- Reset all filters
function lust_next.reset_filters()
  lust_next.active_tags = {}
  lust_next.filter_pattern = nil
  return lust_next
end

-- Check if a test should run based on tags and pattern filtering
local function should_run_test(name, tags)
  -- If no filters are set, run everything
  if #lust_next.active_tags == 0 and not lust_next.filter_pattern then
    return true
  end

  -- Check pattern filter
  if lust_next.filter_pattern and not name:match(lust_next.filter_pattern) then
    return false
  end
  
  -- If we have tags filter but no tags on this test, skip it
  if #lust_next.active_tags > 0 and #tags == 0 then
    return false
  end
  
  -- Check tag filters
  if #lust_next.active_tags > 0 then
    for _, activeTag in ipairs(lust_next.active_tags) do
      for _, testTag in ipairs(tags) do
        if activeTag == testTag then
          return true
        end
      end
    end
    return false
  end
  
  return true
end

function lust_next.it(name, fn)
  -- Save current tags for this test
  local test_tags = {}
  for _, tag in ipairs(lust_next.current_tags) do
    table.insert(test_tags, tag)
  end
  
  -- Check if this test should be run
  if not should_run_test(name, test_tags) then
    -- Skip test but still print it as skipped
    print(indent() .. 'SKIP ' .. name)
    lust_next.skipped = lust_next.skipped + 1
    return
  end
  
  for level = 1, lust_next.level do
    if lust_next.befores[level] then
      for i = 1, #lust_next.befores[level] do
        lust_next.befores[level][i](name)
      end
    end
  end

  -- Handle both regular and async tests (returned from lust_next.async())
  local success, err
  if type(fn) == "function" then
    success, err = pcall(fn)
  else
    -- If it's not a function, it might be the result of an async test that already completed
    success, err = true, fn
  end
  
  if success then lust_next.passes = lust_next.passes + 1
  else lust_next.errors = lust_next.errors + 1 end
  local color = success and green or red
  local label = success and 'PASS' or 'FAIL'
  print(indent() .. color .. label .. normal .. ' ' .. name)
  if err and not success then
    print(indent(lust_next.level + 1) .. red .. tostring(err) .. normal)
  end

  for level = 1, lust_next.level do
    if lust_next.afters[level] then
      for i = 1, #lust_next.afters[level] do
        lust_next.afters[level][i](name)
      end
    end
  end
  
  -- Clear current tags after test
  lust_next.current_tags = {}
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

-- Mocking and Spy system
-- Global registry to track mocks for cleanup
local _mocks = {}

-- Helper function to check if a table is a mock
local function is_mock(obj)
  return type(obj) == "table" and obj._is_lust_mock == true
end

-- Helper function to register a mock for cleanup
local function register_mock(mock)
  table.insert(_mocks, mock)
  return mock
end

-- Helper function to restore all mocks
local function restore_all_mocks()
  for _, mock in ipairs(_mocks) do
    mock:restore()
  end
  _mocks = {}
end

-- Spy function with enhanced features
function lust_next.spy(target, name, run)
  local spy = {
    calls = {},
    called = false,
    call_count = 0,
    original = nil,
    target = nil,
    name = nil
  }
  
  local subject

  local function capture(...)
    spy.called = true
    spy.call_count = spy.call_count + 1
    local args = {...}
    table.insert(spy.calls, args)
    return subject(...)
  end

  if type(target) == 'table' then
    spy.target = target
    spy.name = name
    spy.original = target[name]
    subject = spy.original
    target[name] = capture
  else
    run = name
    subject = target or function() end
  end

  -- Add spy methods
  function spy:restore()
    if self.target and self.name then
      self.target[self.name] = self.original
    end
  end
  
  function spy:called_with(...)
    local expected_args = {...}
    for _, call_args in ipairs(self.calls) do
      local match = true
      for i, arg in ipairs(expected_args) do
        if call_args[i] ~= arg then
          match = false
          break
        end
      end
      if match then return true end
    end
    return false
  end
  
  function spy:called_times(n)
    return self.call_count == n
  end
  
  function spy:not_called()
    return self.call_count == 0
  end
  
  function spy:called_once()
    return self.call_count == 1
  end
  
  function spy:last_call()
    if #self.calls > 0 then
      return self.calls[#self.calls]
    end
    return nil
  end

  -- Set up call method
  setmetatable(spy, {
    __call = function(_, ...)
      return capture(...)
    end
  })

  if run then run() end

  return spy
end

-- Create a mock object with verifiable behavior
function lust_next.mock(target, options)
  options = options or {}
  
  local mock = {
    _is_lust_mock = true,
    _target = target,
    _stubs = {},
    _originals = {},
    _verify_all_expectations_called = options.verify_all_expectations_called ~= false
  }
  
  -- Method to stub a function with a return value or implementation
  function mock:stub(name, implementation_or_value)
    self._originals[name] = self._target[name]
    
    local implementation
    if type(implementation_or_value) == "function" then
      implementation = implementation_or_value
    else
      implementation = function() return implementation_or_value end
    end
    
    local spy = lust_next.spy(implementation)
    self._stubs[name] = spy
    self._target[name] = spy
    
    return spy
  end
  
  -- Restore a specific stub
  function mock:restore_stub(name)
    if self._originals[name] then
      self._target[name] = self._originals[name]
      self._originals[name] = nil
      self._stubs[name] = nil
    end
  end
  
  -- Restore all stubs for this mock
  function mock:restore()
    for name, _ in pairs(self._originals) do
      self._target[name] = self._originals[name]
    end
    self._stubs = {}
    self._originals = {}
  end
  
  -- Verify all expected stubs were called
  function mock:verify()
    local failures = {}
    
    if self._verify_all_expectations_called then
      for name, stub in pairs(self._stubs) do
        if not stub.called then
          table.insert(failures, "Expected " .. name .. " to be called, but it was not")
        end
      end
    end
    
    if #failures > 0 then
      error("Mock verification failed:\n  " .. table.concat(failures, "\n  "), 2)
    end
    
    return true
  end
  
  -- Register for auto-cleanup
  register_mock(mock)
  
  return mock
end

-- Create a standalone stub function
function lust_next.stub(return_value_or_implementation)
  if type(return_value_or_implementation) == "function" then
    return lust_next.spy(return_value_or_implementation)
  else
    return lust_next.spy(function() return return_value_or_implementation end)
  end
end

-- Context manager for mocks that auto-restores
function lust_next.with_mocks(fn)
  local prev_mocks = _mocks
  _mocks = {}
  
  local ok, result = pcall(fn, lust_next.mock)
  
  -- Always restore mocks, even on failure
  for _, mock in ipairs(_mocks) do
    mock:restore()
  end
  
  _mocks = prev_mocks
  
  if not ok then
    error(result, 2)
  end
  
  return result
end

-- Register hook to clean up mocks after tests
local original_it = lust_next.it
function lust_next.it(name, fn)
  local wrapped_fn = function()
    local prev_mocks = _mocks
    _mocks = {}
    
    local result = fn()
    
    -- Restore any mocks created during the test
    for _, mock in ipairs(_mocks) do
      mock:restore()
    end
    
    _mocks = prev_mocks
    
    return result
  end
  
  return original_it(name, wrapped_fn)
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
function lust_next.run_discovered(root_dir, pattern, options)
  options = options or {}
  
  -- Apply filters if specified in options
  if options.tags then
    if type(options.tags) == "string" then
      lust_next.only_tags(options.tags)
    elseif type(options.tags) == "table" then
      -- Use table.unpack for Lua 5.2+ or unpack for Lua 5.1
      local unpack_func = table.unpack or unpack
      lust_next.only_tags(unpack_func(options.tags))
    end
  end
  
  if options.filter then
    lust_next.filter(options.filter)
  end
  
  local files = lust_next.discover(root_dir, pattern)
  local results = {
    total_files = #files,
    passed_files = 0,
    failed_files = 0,
    total_tests = 0,
    passed_tests = 0,
    failed_tests = 0,
    skipped_tests = 0,
    failures = {}
  }
  
  -- Initial pass/error counters
  local initial_passes = lust_next.passes
  local initial_errors = lust_next.errors
  
  -- Build filter information for summary
  local filter_info = ""
  if #lust_next.active_tags > 0 then
    filter_info = filter_info .. " (filtered by tags: " .. table.concat(lust_next.active_tags, ", ") .. ")"
  end
  if lust_next.filter_pattern then
    filter_info = filter_info .. " (filtered by pattern: " .. lust_next.filter_pattern .. ")"
  end
  
  print("\n" .. green .. "Running " .. #files .. " test files" .. normal .. filter_info)
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
  
  -- Print skipped tests if we have any
  if results.skipped_tests and results.skipped_tests > 0 then
    print("Skipped: " .. results.skipped_tests .. " tests due to filtering")
  end
  
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
  
  -- Reset filters after run
  lust_next.reset_filters()
  
  return results
end

-- Track skipped tests directly in the lust_next object
lust_next.skipped = 0

-- Run a single test file
function lust_next.run_file(file_path)
  local prev_passes = lust_next.passes
  local prev_errors = lust_next.errors
  
  -- Reset skip counter
  lust_next.skipped = 0
  
  print("\nRunning file: " .. file_path)
  local success, err = pcall(function()
    -- Set the package path to include the directory of the test file
    local dir = file_path:match("(.*[/\\])")
    package.path = dir .. "?.lua;" .. dir .. "../?.lua;" .. package.path
    dofile(file_path)
  end)
  
  local results = {
    success = success,
    error = err,
    passes = lust_next.passes - prev_passes,
    errors = lust_next.errors - prev_errors,
    skipped = lust_next.skipped
  }
  
  if not success then
    print(red .. "ERROR: " .. err .. normal)
  else
    local summary = green .. "Completed with " .. results.passes .. " passes, " 
                  .. results.errors .. " failures" .. normal
    
    if lust_next.skipped > 0 then
      summary = summary .. " (" .. lust_next.skipped .. " skipped)"
    end
    
    print(summary)
  end
  
  return results
end

-- CLI runner that finds and runs tests
function lust_next.cli_run(dir, options)
  dir = dir or "./tests"
  options = options or {}
  
  -- Apply filters if specified in options
  if options.tags then
    if type(options.tags) == "string" then
      lust_next.only_tags(options.tags)
    elseif type(options.tags) == "table" then
      -- Use table.unpack for Lua 5.2+ or unpack for Lua 5.1
      local unpack_func = table.unpack or unpack
      lust_next.only_tags(unpack_func(options.tags))
    end
  end
  
  if options.filter then
    lust_next.filter(options.filter)
  end
  
  local files = lust_next.discover(dir)
  
  -- Build filter information for summary
  local filter_info = ""
  if #lust_next.active_tags > 0 then
    filter_info = filter_info .. " (filtered by tags: " .. table.concat(lust_next.active_tags, ", ") .. ")"
  end
  if lust_next.filter_pattern then
    filter_info = filter_info .. " (filtered by pattern: " .. lust_next.filter_pattern .. ")"
  end
  
  print(green .. "Running " .. #files .. " test files" .. normal .. filter_info)
  
  local passed = 0
  local failed = 0
  local skipped = 0
  
  for _, file in ipairs(files) do
    local results = lust_next.run_file(file)
    if results.success and results.errors == 0 then
      passed = passed + 1
    else
      failed = failed + 1
    end
    if results.skipped then
      skipped = skipped + (results.skipped or 0)
    end
  end
  
  print("\n" .. string.rep("-", 60))
  print("Test Summary: " .. green .. passed .. " passed" .. normal .. ", " .. 
        (failed > 0 and red or green) .. failed .. " failed" .. normal)
  
  if skipped > 0 then
    print("Skipped: " .. skipped .. " tests due to filtering")
  end
  
  print(string.rep("-", 60))
  
  if failed > 0 then
    print(red .. "✖ Some tests failed" .. normal)
    lust_next.reset_filters()
    return false
  else
    print(green .. "✓ All tests passed" .. normal)
    lust_next.reset_filters()
    return true
  end
end

-- Async testing implementation
local clock
if os.clock then
  clock = os.clock
else
  -- Fallback for environments without os.clock
  clock = function()
    return os.time()
  end
end

-- Wrapper to create an async test function
function lust_next.async(fn, timeout)
  return function(...)
    local args = {...}
    return function()
      lust_next.running_async = true
      
      -- Create the coroutine for this test
      local co = coroutine.create(function()
        -- Use table.unpack for Lua 5.2+ or unpack for Lua 5.1
        local unpack_func = table.unpack or unpack
        return fn(unpack_func(args))
      end)
      
      -- Set timeout (use provided timeout or default)
      local test_timeout = timeout or lust_next.async_timeout
      local start_time = clock() * 1000
      local is_complete = false
      
      -- First resume to start the coroutine
      local success, result = coroutine.resume(co)
      
      -- Handle immediate completion or error
      if coroutine.status(co) == "dead" then
        is_complete = true
        lust_next.running_async = false
        
        if not success then
          error(result, 2) -- Propagate the error
        end
        return result
      end
      
      -- Loop until coroutine completes or times out
      while coroutine.status(co) ~= "dead" do
        -- Check for timeout
        local current_time = clock() * 1000
        if current_time - start_time > test_timeout then
          lust_next.running_async = false
          error("Async test timed out after " .. test_timeout .. "ms", 2)
        end
        
        -- Sleep a little to avoid hogging CPU
        lust_next.sleep(10)
        
        -- Resume the coroutine
        success, result = coroutine.resume(co)
        
        if not success then
          lust_next.running_async = false
          error(result, 2) -- Propagate the error
        end
      end
      
      lust_next.running_async = false
      return result
    end
  end
end

-- Wait for a specified time in milliseconds
function lust_next.await(ms)
  if not lust_next.running_async then
    error("lust_next.await() can only be called within an async test", 2)
  end
  
  local start = clock() * 1000
  while (clock() * 1000) - start < ms do
    coroutine.yield()
  end
end

-- Wait until a condition function returns true or timeout
function lust_next.wait_until(condition_fn, timeout, check_interval)
  if not lust_next.running_async then
    error("lust_next.wait_until() can only be called within an async test", 2)
  end
  
  timeout = timeout or lust_next.async_timeout
  check_interval = check_interval or 10
  
  local start_time = clock() * 1000
  
  while not condition_fn() do
    if (clock() * 1000) - start_time > timeout then
      error("Timeout waiting for condition after " .. timeout .. "ms", 2)
    end
    lust_next.await(check_interval)
  end
end

-- Simple sleep function that works in any environment
function lust_next.sleep(ms)
  local start = clock()
  local duration = ms / 1000 -- convert to seconds
  while clock() - start < duration do
    -- Busy wait
  end
end

-- Set global default timeout for async tests
function lust_next.set_timeout(ms)
  lust_next.async_timeout = ms
  return lust_next
end

-- Async version of 'it' for easier test writing
function lust_next.it_async(name, fn, timeout)
  return lust_next.it(name, lust_next.async(fn, timeout)())
end

-- Aliases and exports
lust_next.test = lust_next.it
lust_next.test_async = lust_next.it_async
lust_next.paths = paths

-- Command-line runner with enhanced options
-- Only run this if we're invoked directly (not through require)
local debug_info = debug.getinfo(3, "S")
local is_main = debug_info and debug_info.source == arg[0]

if is_main and arg and (arg[0]:match("lust_next.lua$") or arg[0]:match("lust%-next.lua$")) then
  local options = {}
  local dir = "./tests"
  local specific_file = nil
  
  -- Parse command line arguments
  local i = 1
  while i <= #arg do
    if arg[i] == "--dir" and arg[i+1] then
      dir = arg[i+1]
      i = i + 2
    elseif arg[i] == "--tags" and arg[i+1] then
      options.tags = {}
      -- Split tags by comma
      for tag in arg[i+1]:gmatch("[^,]+") do
        table.insert(options.tags, tag:match("^%s*(.-)%s*$")) -- Trim whitespace
      end
      i = i + 2
    elseif arg[i] == "--filter" and arg[i+1] then
      options.filter = arg[i+1]
      i = i + 2
    elseif arg[i]:match("%.lua$") then
      specific_file = arg[i]
      i = i + 1
    elseif arg[i] == "--help" or arg[i] == "-h" then
      print("lust-next test runner")
      print("Usage:")
      print("  lua lust-next.lua [options] [file.lua]")
      print("Options:")
      print("  --dir DIR        Directory to search for tests (default: ./tests)")
      print("  --tags TAG1,TAG2 Only run tests with matching tags")
      print("  --filter PATTERN Only run tests with names matching pattern")
      print("  --help, -h       Show this help message")
      os.exit(0)
    else
      i = i + 1
    end
  end
  
  if specific_file then
    -- Run a specific test file
    local results = lust_next.run_file(specific_file)
    if not results.success or results.errors > 0 then
      os.exit(1)
    else
      os.exit(0)
    end
  else
    -- Run tests with options
    local success = lust_next.cli_run(dir, options)
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
