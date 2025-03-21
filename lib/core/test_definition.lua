---@class TestDefinition
---@field describe fun(name: string, fn: function, options?: {focused?: boolean, excluded?: boolean, _parent_focused?: boolean}): nil Create a test group
---@field fdescribe fun(name: string, fn: function): nil Create a focused test group
---@field xdescribe fun(name: string, fn: function): nil Create a skipped test group
---@field it fun(name: string, options_or_fn: table|function, fn?: function): nil Create a test case
---@field fit fun(name: string, options_or_fn: table|function, fn?: function): nil Create a focused test case
---@field xit fun(name: string, options_or_fn: table|function, fn?: function): nil Create a skipped test case
---@field before fun(fn: function): nil Add a setup hook for the current block
---@field after fun(fn: function): nil Add a teardown hook for the current block
---@field pending fun(message?: string): string Mark a test as pending

-- Test definition module for firmo
-- Contains the core functions for defining test blocks and cases

local M = {}

-- Forward declaration of module-level variables
local level = 0
local befores = {}
local afters = {}
local current_tags = {}
local active_tags = {}
local filter_pattern = nil
local focus_mode = false
local current_describe_block = nil

-- Define test status constants
---@class TestStatus
---@field PASS string Test passed successfully
---@field FAIL string Test failed
---@field SKIP string Test was skipped
---@field PENDING string Test is pending implementation
local TEST_STATUS = {
  PASS = "pass",
  FAIL = "fail",
  SKIP = "skip",
  PENDING = "pending"
}

-- Track tests
local passes = 0
local errors = 0
local skipped = 0
local test_blocks = {}
local test_paths = {}
---@class TestResult
---@field status string The test status (pass, fail, skip, pending)
---@field name string The name of the test
---@field path string[] The path to the test (array of describe block names plus test name)
---@field path_string string The path to the test as a string (separated by " / ")
---@field timestamp number When the test was executed (os.time() value)
---@field execution_time? number Optional execution time in seconds
---@field options? table Optional test options that were provided
---@field error? any Optional error object if the test failed
---@field error_message? string Optional formatted error message
---@field expect_error? boolean Whether the test was expected to produce an error
---@field reason? string Optional reason for skipping or pending

-- Collection of structured test result objects
local test_results = {}

-- Error handling and logging
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("TestDefinition")

--- Safely require a module without raising an error if it doesn't exist
---@param name string The name of the module to require
---@return table|nil The loaded module or nil if it couldn't be loaded
local function try_require(name)
  local success, mod = pcall(require, name)
  if success then return mod end
  return nil
end

-- Try to load temp_file module for test isolation
local temp_file = try_require("lib.tools.temp_file")

-- Local utility functions
--- Merge provided options with defaults
---@param options table|nil The options provided by the user
---@param defaults table The default options to use when not provided
---@return table The merged options
local function merge_options(options, defaults)
  options = options or {}
  local result = {}
  for k, v in pairs(defaults) do
    result[k] = options[k] ~= nil and options[k] or v
  end
  return result
end

-- Tag validation and management
--- Check if a test has any of the required tags
---@param test_tags table Array of tags applied to the test
---@return boolean True if the test has any required tags or if no tags are required
local function has_required_tags(test_tags)
  if not active_tags or #active_tags == 0 then
    return true
  end
  
  for _, tag in ipairs(active_tags) do
    for _, test_tag in ipairs(test_tags) do
      if test_tag == tag then
        return true
      end
    end
  end
  
  return false
end

-- Public interface

--- Set active tags for test filtering
---@param ... string Tags to filter by
---@return table The module instance
function M.only_tags(...)
  active_tags = {...}
  return M
end

--- Set tags for the current test block
---@param ... string Tags to apply
---@return table The module instance
function M.tags(...)
  local new_tags = {...}
  current_tags = new_tags
  return M
end

--- Set a filter pattern for test names
---@param pattern string Pattern to filter test names
---@return table The module instance
function M.filter_pattern(pattern)
  filter_pattern = pattern
  return M
end

--- Mark a test as pending
---@param message? string Optional message explaining why the test is pending
---@return string The pending message
function M.pending(message)
  message = message or "Test not yet implemented"
  return message
end

--- Create a test group
---@param name string Name of the test group
---@param fn function Function containing the test group
---@param options? {focused?: boolean, excluded?: boolean, _parent_focused?: boolean} Options for the test group
function M.describe(name, fn, options)
  options = options or {}
  local parent_focused = options._parent_focused or false
  local focused = options.focused or false
  local excluded = options.excluded or false
  
  -- Update focus mode if this is a focused describe
  if focused and not excluded then
    focus_mode = true
  end
  
  -- Save previous tags and level
  local previous_level = level
  local previous_tags = {}
  for i, v in ipairs(current_tags) do
    previous_tags[i] = v
  end
  
  -- Create a new describe block
  local block = {
    name = name,
    parent = current_describe_block,
    focused = focused,
    excluded = excluded,
    parent_focused = parent_focused,
    tags = {},
  }
  
  -- Copy current tags to the block
  for i, v in ipairs(current_tags) do
    block.tags[i] = v
  end
  
  -- Check if block should be skipped based on tags
  local should_skip_block = not has_required_tags(block.tags)
  
  -- Save previous describe block and set current
  local previous_describe_block = current_describe_block
  current_describe_block = block
  
  -- Insert block into test_blocks
  table.insert(test_blocks, block)
  
  -- Increase level and ensure hooks tables exist
  level = level + 1
  befores[level] = befores[level] or {}
  afters[level] = afters[level] or {}
  
  if not should_skip_block then
    -- Execute the test group function to register its tests
    local success, err = error_handler.try(fn)
    if not success then
      -- Handle errors in describe blocks
      logger.error("Error in describe block: " .. error_handler.format_error(err), {
        block_name = name,
        level = level,
      })
      errors = errors + 1
    end
  end
  
  -- Restore previous state
  level = previous_level
  current_tags = previous_tags
  current_describe_block = previous_describe_block
end

--- Create a focused test group
---@param name string Name of the test group
---@param fn function Function containing the test group
function M.fdescribe(name, fn)
  return M.describe(name, fn, {focused = true})
end

--- Create a skipped test group
---@param name string Name of the test group
---@param fn function Function containing the test group
function M.xdescribe(name, fn)
  return M.describe(name, fn, {excluded = true})
end

--- Create a test case
---@param name string Name of the test case
---@param options_or_fn table|function Options table or test function
---@param fn? function Test function if options were provided
function M.it(name, options_or_fn, fn)
  -- Determine if first argument is options or function
  local options = {}
  if type(options_or_fn) == "table" then
    options = options_or_fn
  else
    fn = options_or_fn
  end
  
  -- Apply defaults to options
  options = merge_options(options, {
    focused = false,
    excluded = false,
    expect_error = false,
    tags = {},
    timeout = nil,
  })
  
  -- Determine if test should be skipped based on focus mode
  local should_skip = false
  
  -- Skip if exclude flag is set
  if options.excluded then
    should_skip = true
  end
  
  -- Skip if there are focused tests and this one isn't focused
  if focus_mode and not options.focused and not (current_describe_block and current_describe_block.focused) then
    should_skip = true
  end
  
  -- Skip if tags don't match
  local test_tags = {}
  -- Add tags from current describe block
  if current_describe_block and current_describe_block.tags then
    for _, tag in ipairs(current_describe_block.tags) do
      table.insert(test_tags, tag)
    end
  end
  
  -- Add tags from options
  for _, tag in ipairs(options.tags) do
    table.insert(test_tags, tag)
  end
  
  -- Add tags from current context
  for _, tag in ipairs(current_tags) do
    table.insert(test_tags, tag)
  end
  
  -- Skip if test doesn't have required tags
  if not has_required_tags(test_tags) then
    should_skip = true
  end
  
  -- Skip if name doesn't match pattern
  if filter_pattern and name:match(filter_pattern) == nil then
    should_skip = true
  end
  
  -- Record test path
  local path = {}
  local current = current_describe_block
  while current do
    table.insert(path, 1, current.name)
    current = current.parent
  end
  table.insert(path, name)
  
  -- Store full test path
  table.insert(test_paths, path)
  
  if should_skip then
    -- Record this test as skipped with structured data
    local result = M.add_test_result({
      status = TEST_STATUS.SKIP,
      name = name,
      path = path,
      path_string = table.concat(path, " / "),
      timestamp = os.time(),
      options = options,
      reason = "Test skipped due to filtering or tagging"
    })
    
    -- Log as skipped with proper structure
    logger.info("Test skipped: " .. name, {
      test_name = name,
      test_path = table.concat(path, " / "),
      test_result = result
    })
    
    return
  end
  
  -- Run test with proper error handling
  local test_start_time = os.clock()
  local success, err = error_handler.try(function()
    -- Set temporary file context if available
    if temp_file and temp_file.set_current_test_context then
      temp_file.set_current_test_context({
        type = "test",
        name = name,
        path = table.concat(path, " / "),
      })
    end
    
    -- Run before hooks for each level
    for i = 1, level do
      for _, hook in ipairs(befores[i] or {}) do
        hook()
      end
    end
    
    -- Run the test
    fn()
    
    -- Run after hooks in reverse order
    for i = level, 1, -1 do
      for _, hook in ipairs(afters[i] or {}) do
        hook()
      end
    end
    
    -- Clean up test context
    if temp_file and temp_file.set_current_test_context then
      temp_file.set_current_test_context(nil)
    end
    
    -- Create a test pass result
    local result = M.add_test_result({
      status = TEST_STATUS.PASS,
      name = name,
      path = path,
      path_string = table.concat(path, " / "),
      execution_time = os.clock() - test_start_time,
      timestamp = os.time(),
      options = options
    })
    
    -- Log pass with proper structure
    logger.info("Test passed: " .. name, {
      test_name = name,
      test_path = table.concat(path, " / "),
      test_result = result
    })
  end)
  
  -- Handle test errors
  if not success then
    local execution_time = os.clock() - test_start_time
    
    if options.expect_error then
      -- Test expects an error, so this is a pass
      local result = M.add_test_result({
        status = TEST_STATUS.PASS,
        name = name,
        path = path,
        path_string = table.concat(path, " / "),
        execution_time = execution_time,
        timestamp = os.time(),
        options = options,
        expect_error = true,
        error = err, -- Store the error for inspection
      })
      
      -- Log pass with proper structure for expected errors
      logger.info("Test passed with expected error: " .. name, {
        test_name = name,
        test_path = table.concat(path, " / "),
        test_result = result,
        expect_error = true
      })
    else
      -- Unexpected error, test fails
      local result = M.add_test_result({
        status = TEST_STATUS.FAIL,
        name = name,
        path = path,
        path_string = table.concat(path, " / "),
        execution_time = execution_time,
        timestamp = os.time(),
        options = options,
        error = err,
        error_message = error_handler.format_error(err)
      })
      
      -- Log error details with the structured result
      logger.error("Test failed: " .. error_handler.format_error(err), {
        test_name = name,
        test_path = table.concat(path, " / "),
        test_result = result,
        error_message = error_handler.format_error(err)
      })
    end
  end
end

--- Create a focused test case
---@param name string Name of the test case
---@param options_or_fn table|function Options table or test function
---@param fn? function Test function if options were provided
function M.fit(name, options_or_fn, fn)
  -- Set focus mode
  focus_mode = true
  
  -- Determine if first argument is options or function
  local options = {}
  if type(options_or_fn) == "table" then
    options = options_or_fn
    options.focused = true
  else
    fn = options_or_fn
    options = {focused = true}
  end
  
  return M.it(name, options, fn)
end

--- Create a skipped test case
---@param name string Name of the test case
---@param options_or_fn table|function Options table or test function
---@param fn? function Test function if options were provided
function M.xit(name, options_or_fn, fn)
  -- Determine if first argument is options or function
  local options = {}
  if type(options_or_fn) == "table" then
    options = options_or_fn
    options.excluded = true
  else
    fn = options_or_fn
    options = {excluded = true}
  end
  
  return M.it(name, options, fn)
end

--- Add a setup hook for the current block
---@param fn function Hook function to execute before each test
function M.before(fn)
  befores[level] = befores[level] or {}
  table.insert(befores[level], fn)
end

--- Add a teardown hook for the current block
---@param fn function Hook function to execute after each test
function M.after(fn)
  afters[level] = afters[level] or {}
  table.insert(afters[level], fn)
end

--- Reset the test state
function M.reset()
  level = 0
  befores = {}
  afters = {}
  current_tags = {}
  active_tags = {}
  filter_pattern = nil
  focus_mode = false
  current_describe_block = nil
  passes = 0
  errors = 0
  skipped = 0
  test_blocks = {}
  test_paths = {}
  test_results = {} -- Clear all test results
end

--- Get the current state of the test system
---@return {level: number, passes: number, errors: number, skipped: number, focus_mode: boolean, test_results: TestResult[]} Current test system state
function M.get_state()
  return {
    level = level,
    passes = passes,
    errors = errors,
    skipped = skipped,
    focus_mode = focus_mode,
    test_results = test_results,
  }
end

--- Export test status constants
M.STATUS = TEST_STATUS

-- Add debug flag to test_definition module
local debug_mode = false

--- Set debug mode for test_definition module
---@param value boolean Whether to enable debug output
---@return table The module instance for chaining
function M.set_debug_mode(value)
  debug_mode = value == true
  return M
end

--- Add a test result to the collection
---@param result TestResult The test result object to add
---@return TestResult|nil The added test result or nil if invalid
function M.add_test_result(result)
  if not result or type(result) ~= "table" then
    return nil
  end
  
  -- Ensure required fields
  result.status = result.status or TEST_STATUS.FAIL
  result.name = result.name or "unknown test"
  result.timestamp = result.timestamp or os.time()
  
  -- Add result to collection
  table.insert(test_results, result)
  
  -- Print debug output if enabled
  if debug_mode then
    local status_color = ""
    if result.status == TEST_STATUS.PASS then
      status_color = "\27[32m" -- green
    elseif result.status == TEST_STATUS.FAIL then
      status_color = "\27[31m" -- red
    else
      status_color = "\27[33m" -- yellow
    end
    
    print(string.format("ADD RESULT: %s[%s]\27[0m %s (%s) %s", 
      status_color,
      result.status:upper(),
      result.name,
      result.path_string or "",
      result.expect_error and "[expects error]" or ""))
  end
  
  -- Update counters based on status
  if result.status == TEST_STATUS.PASS then
    passes = passes + 1
  elseif result.status == TEST_STATUS.FAIL then
    errors = errors + 1
  elseif result.status == TEST_STATUS.SKIP or result.status == TEST_STATUS.PENDING then
    skipped = skipped + 1
  end
  
  return result
end

-- Initialize and return the module
return M