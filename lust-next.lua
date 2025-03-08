-- lust-next v0.7.5 - Enhanced Lua test framework
-- https://github.com/greggh/lust-next
-- MIT LICENSE
-- Based on lust by Bjorn Swenson (https://github.com/bjornbytes/lust)
--
-- Features:
-- * BDD-style nested test blocks (describe/it)
-- * Assertions with detailed error messages
-- * Setup and teardown with before/after hooks
-- * Advanced mocking and spying system
-- * Tag-based filtering for selective test execution
-- * Focus mode for running only specific tests (fdescribe/fit)
-- * Skip mode for excluding tests (xdescribe/xit)
-- * Asynchronous testing support
-- * Code coverage analysis and reporting
-- * Watch mode for continuous testing

-- Try to require optional modules
local function try_require(name)
  local ok, mod = pcall(require, name)
  if ok then
    return mod
  else
    return nil
  end
end

-- Optional modules for advanced features
local coverage = try_require("lib.coverage")
local quality = try_require("lib.quality")
local codefix = try_require("lib.tools.codefix")
local reporting = try_require("lib.reporting")
local watcher = try_require("lib.tools.watcher")
local json = try_require("lib.reporting.json")
local type_checking = try_require("lib.core.type_checking")
local async_module = try_require("lib.async")
local interactive = try_require("lib.tools.interactive")
local discover_module = try_require("scripts.discover")
local parallel_module = try_require("lib.tools.parallel")

local lust_next = {}
lust_next.level = 0
lust_next.passes = 0
lust_next.errors = 0
lust_next.befores = {}
lust_next.afters = {}
lust_next.version = "0.7.5"
lust_next.active_tags = {}
lust_next.current_tags = {}
lust_next.filter_pattern = nil
-- Default configuration for modules
lust_next.async_options = {
  timeout = 5000 -- Default timeout in ms
}
lust_next.focus_mode = false -- Tracks if any focused tests are present
lust_next.skipped = 0 -- Track skipped tests

-- Export async functions if the module is available
if async_module then
  -- Import core async functions
  lust_next.async = async_module.async
  lust_next.await = async_module.await
  lust_next.wait_until = async_module.wait_until
  lust_next.parallel_async = async_module.parallel_async
  
  -- Configure the async module with our options
  if lust_next.async_options and lust_next.async_options.timeout then
    async_module.set_timeout(lust_next.async_options.timeout)
  end
else
  -- Define stub functions for when the module isn't available
  local function async_error()
    error("Async module not available. Make sure src/async.lua exists.", 2)
  end
  
  lust_next.async = async_error
  lust_next.await = async_error
  lust_next.wait_until = async_error
  lust_next.parallel_async = async_error
end

-- Register codefix module if available
if codefix then
  codefix.register_with_lust(lust_next)
end

-- Register parallel execution module if available
if parallel_module then
  parallel_module.register_with_lust(lust_next)
end

-- Add test discovery functionality
if discover_module then
  -- Simple test file discovery function
  function lust_next.discover(dir, pattern)
    dir = dir or "./tests"
    pattern = pattern or "*_test.lua"
    
    -- Platform-specific command to find test files
    local command
    if package.config:sub(1,1) == '\\' then
      -- Windows
      command = 'dir /s /b "' .. dir .. '\\' .. pattern .. '" > lust_temp_files.txt'
    else
      -- Unix
      command = 'find "' .. dir .. '" -name "' .. pattern .. '" -type f > lust_temp_files.txt'
    end
    
    -- Execute the command
    os.execute(command)
    
    -- Read the results from the temporary file
    local files = {}
    local file = io.open("lust_temp_files.txt", "r")
    if file then
      for line in file:lines() do
        if line:match(pattern:gsub("*", ".*"):gsub("?", ".")) then
          table.insert(files, line)
        end
      end
      file:close()
      os.remove("lust_temp_files.txt")
    end
    
    return files
  end
  
  -- Run all discovered test files
  function lust_next.run_discovered(dir, pattern)
    local files = lust_next.discover(dir, pattern)
    local success = true
    
    if #files == 0 then
      print("No test files found in " .. (dir or "./tests"))
      return false
    end
    
    for _, file in ipairs(files) do
      local file_results = lust_next.run_file(file)
      if not file_results.success or file_results.errors > 0 then
        success = false
      end
    end
    
    return success
  end
  
  -- CLI runner function for command-line usage
  function lust_next.cli_run(args)
    args = args or {}
    local options = {
      dir = "./tests",
      pattern = "*_test.lua",
      files = {},
      tags = {},
      watch = false,
      interactive = false,
      coverage = false,
      quality = false,
      quality_level = 1,
      format = "summary",
      
      -- Report configuration options
      report_dir = "./coverage-reports",
      report_suffix = nil,
      coverage_path_template = nil,
      quality_path_template = nil,
      results_path_template = nil,
      timestamp_format = "%Y-%m-%d",
      verbose = false,
      
      -- Custom formatter options
      coverage_format = nil,      -- Custom format for coverage reports
      quality_format = nil,       -- Custom format for quality reports
      results_format = nil,       -- Custom format for test results
      formatter_module = nil      -- Custom formatter module to load
    }
    
    -- Parse command line arguments
    local i = 1
    while i <= #args do
      local arg = args[i]
      if arg == "--watch" or arg == "-w" then
        options.watch = true
        i = i + 1
      elseif arg == "--interactive" or arg == "-i" then
        options.interactive = true
        i = i + 1
      elseif arg == "--coverage" or arg == "-c" then
        options.coverage = true
        i = i + 1
      elseif arg == "--quality" or arg == "-q" then
        options.quality = true
        i = i + 1
      elseif arg == "--quality-level" or arg == "-ql" then
        if args[i+1] and tonumber(args[i+1]) then
          options.quality_level = tonumber(args[i+1])
          i = i + 2
        else
          i = i + 1
        end
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
        lust_next.show_help()
        return true
      elseif not arg:match("^%-") then
        -- Not a flag, assume it's a file
        table.insert(options.files, arg)
        i = i + 1
      else
        -- Skip unknown options
        i = i + 1
      end
    end
    
    -- Set tags if specified
    if #options.tags > 0 then
      lust_next.active_tags = options.tags
    end
    
    -- Load custom formatter module if specified
    if options.formatter_module and reporting then
      local ok, custom_formatters = pcall(require, options.formatter_module)
      if ok and custom_formatters then
        print("Loading custom formatters from module: " .. options.formatter_module)
        
        local count = reporting.load_formatters(custom_formatters)
        print("Registered " .. count .. " custom formatters")
        
        -- Get list of available formatters for display
        local formatters = reporting.get_available_formatters()
        print("Available formatters:")
        print("  Coverage: " .. table.concat(formatters.coverage, ", "))
        print("  Quality: " .. table.concat(formatters.quality, ", "))
        print("  Results: " .. table.concat(formatters.results, ", "))
      else
        print("WARNING: Failed to load custom formatter module '" .. options.formatter_module .. "'")
      end
    end
    
    -- Set coverage format from CLI if specified
    if options.coverage_format then
      options.format = options.coverage_format
    end
    
    -- Configure report options
    local report_config = {
      report_dir = options.report_dir,
      report_suffix = options.report_suffix,
      coverage_path_template = options.coverage_path_template,
      quality_path_template = options.quality_path_template,
      results_path_template = options.results_path_template,
      timestamp_format = options.timestamp_format,
      verbose = options.verbose
    }
    
    -- Set quality options
    if options.quality and quality then
      quality.init(lust_next, { 
        enabled = true, 
        level = options.quality_level,
        format = options.quality_format or options.format,
        report_config = report_config
      })
    end
    
    -- Set coverage options
    if options.coverage and coverage then
      coverage.init(lust_next, { 
        enabled = true,
        format = options.format,
        report_config = report_config
      })
    end
    
    -- Store report config for other modules to use
    lust_next.report_config = report_config
    
    -- Store custom format settings
    if options.results_format then
      lust_next.results_format = options.results_format
    end
    
    -- If interactive mode is enabled and the module is available
    if options.interactive and interactive then
      interactive.run(lust_next, options)
      return true
    end
    
    -- If watch mode is enabled and the module is available
    if options.watch and watcher then
      watcher.init({"."}, {"node_modules", "%.git"})
      
      -- Run tests
      local run_tests = function()
        lust_next.reset()
        if #options.files > 0 then
          -- Run specific files
          for _, file in ipairs(options.files) do
            lust_next.run_file(file)
          end
        else
          -- Run all discovered tests
          lust_next.run_discovered(options.dir)
        end
      end
      
      -- Initial test run
      run_tests()
      
      -- Watch loop
      print("Watching for changes. Press Ctrl+C to exit.")
      while true do
        local changes = watcher.check_for_changes()
        if changes then
          print("\nFile changes detected. Re-running tests...")
          run_tests()
        end
        os.execute("sleep 0.5")
      end
      
      return true
    end
    
    -- Run tests normally (no watch mode or interactive mode)
    if #options.files > 0 then
      -- Run specific files
      local success = true
      for _, file in ipairs(options.files) do
        local file_results = lust_next.run_file(file)
        if not file_results.success or file_results.errors > 0 then
          success = false
        end
      end
      
      -- Exit with appropriate code
      return success
    else
      -- Run all discovered tests
      local success = lust_next.run_discovered(options.dir, options.pattern)
      return success
    end
  end
else
  -- Stub functions when the discovery module isn't available
  function lust_next.discover()
    return {}
  end
  
  function lust_next.run_discovered()
    return false
  end
  
  function lust_next.cli_run()
    print("Test discovery not available.")
    return false
  end
end

-- Reset function to clear state between test runs
function lust_next.reset()
  -- Reset test state variables
  lust_next.level = 0
  lust_next.passes = 0
  lust_next.errors = 0
  lust_next.befores = {}
  lust_next.afters = {}
  lust_next.active_tags = {}
  lust_next.current_tags = {}
  lust_next.focus_mode = false
  lust_next.skipped = 0
  
  -- Reset assertion count if tracking is enabled
  lust_next.assertion_count = 0
  
  -- Reset the async module if available
  if async_module and async_module.reset then
    async_module.reset()
  end
  
  -- Preserve the paths table because it's essential for expect assertions
  -- DO NOT reset or clear the paths table
  
  -- Free memory
  collectgarbage()
  
  -- Return lust_next to allow for chaining
  return lust_next
end

-- Coverage options
lust_next.coverage_options = {
  enabled = false,            -- Whether coverage is enabled
  include = {".*%.lua$"},     -- Files to include in coverage
  exclude = {"test_", "_spec%.lua$", "_test%.lua$"}, -- Files to exclude
  threshold = 80,             -- Coverage threshold percentage
  format = "summary",         -- Report format (summary, json, html, lcov)
  output = nil,               -- Custom output file path (if nil, html/lcov auto-saved to ./coverage-reports/)
}

-- Code quality options
lust_next.codefix_options = {
  enabled = false,           -- Enable code fixing functionality
  verbose = false,           -- Enable verbose output
  debug = false,             -- Enable debug output
  
  -- StyLua options
  use_stylua = true,         -- Use StyLua for formatting
  stylua_path = "stylua",    -- Path to StyLua executable
  
  -- Luacheck options
  use_luacheck = true,       -- Use Luacheck for linting
  luacheck_path = "luacheck", -- Path to Luacheck executable
  
  -- Custom fixers
  custom_fixers = {
    trailing_whitespace = true,    -- Fix trailing whitespace in strings
    unused_variables = true,       -- Fix unused variables by prefixing with underscore
    string_concat = true,          -- Optimize string concatenation
    type_annotations = false,      -- Add type annotations (disabled by default)
    lua_version_compat = false,    -- Fix Lua version compatibility issues (disabled by default)
  },
}

-- Quality options
lust_next.quality_options = {
  enabled = false,            -- Whether test quality validation is enabled
  level = 1,                  -- Quality level to enforce (1-5)
  strict = false,             -- Whether to fail on first quality issue
  format = "summary",         -- Report format (summary, json, html)
  output = nil,               -- Output file path (nil for console)
}

-- Output formatting options
lust_next.format_options = {
  use_color = true,          -- Whether to use color codes in output
  indent_char = '\t',        -- Character to use for indentation (tab or spaces)
  indent_size = 1,           -- How many indent_chars to use per level
  show_trace = false,        -- Show stack traces for errors
  show_success_detail = true, -- Show details for successful tests
  compact = false,           -- Use compact output format (less verbose)
  dot_mode = false,          -- Use dot mode (. for pass, F for fail)
  summary_only = false       -- Show only summary, not individual tests
}

-- Set up colors based on format options
local red = string.char(27) .. '[31m'
local green = string.char(27) .. '[32m'
local yellow = string.char(27) .. '[33m'
local blue = string.char(27) .. '[34m'
local magenta = string.char(27) .. '[35m'
local cyan = string.char(27) .. '[36m'
local normal = string.char(27) .. '[0m'

-- Helper function for indentation with configurable char and size
local function indent(level) 
  level = level or lust_next.level
  local indent_char = lust_next.format_options.indent_char
  local indent_size = lust_next.format_options.indent_size
  return string.rep(indent_char, level * indent_size) 
end

-- Disable colors (for non-terminal output or color-blind users)
function lust_next.nocolor()
  lust_next.format_options.use_color = false
  red, green, yellow, blue, magenta, cyan, normal = '', '', '', '', '', '', ''
  return lust_next
end

-- Configure output formatting options
function lust_next.format(options)
  for k, v in pairs(options) do
    if lust_next.format_options[k] ~= nil then
      lust_next.format_options[k] = v
    else
      error("Unknown format option: " .. k)
    end
  end
  
  -- Update colors if needed
  if not lust_next.format_options.use_color then
    lust_next.nocolor()
  else
    red = string.char(27) .. '[31m'
    green = string.char(27) .. '[32m'
    yellow = string.char(27) .. '[33m'
    blue = string.char(27) .. '[34m'
    magenta = string.char(27) .. '[35m'
    cyan = string.char(27) .. '[36m'
    normal = string.char(27) .. '[0m'
  end
  
  return lust_next
end

-- The main describe function with support for focus and exclusion
function lust_next.describe(name, fn, options)
  if type(options) == 'function' then
    -- Handle case where options is actually a function (support for tags("tag")(fn) syntax)
    fn = options
    options = {}
  end
  
  options = options or {}
  local focused = options.focused or false
  local excluded = options.excluded or false
  
  -- If this is a focused describe block, mark that we're in focus mode
  if focused then
    lust_next.focus_mode = true
  end
  
  -- Only print in non-summary mode and non-dot mode
  if not lust_next.format_options.summary_only and not lust_next.format_options.dot_mode then
    -- Print description with appropriate formatting
    if excluded then
      print(indent() .. yellow .. "SKIP" .. normal .. " " .. name)
    else
      local prefix = focused and cyan .. "FOCUS " .. normal or ""
      print(indent() .. prefix .. name)
    end
  end
  
  -- If excluded, don't execute the function
  if excluded then
    return
  end
  
  lust_next.level = lust_next.level + 1
  
  -- Save current tags and focus state to restore them after the describe block
  local prev_tags = {}
  for i, tag in ipairs(lust_next.current_tags) do
    prev_tags[i] = tag
  end
  
  -- Store the current focus state at this level
  local prev_focused = options._parent_focused or focused
  
  -- Run the function with updated context
  local success, err = pcall(function()
    fn()
  end)
  
  -- Reset current tags to what they were before the describe block
  lust_next.current_tags = prev_tags
  
  lust_next.befores[lust_next.level] = {}
  lust_next.afters[lust_next.level] = {}
  lust_next.level = lust_next.level - 1
  
  -- If there was an error in the describe block, report it
  if not success then
    lust_next.errors = lust_next.errors + 1
    
    if not lust_next.format_options.summary_only then
      print(indent() .. red .. "ERROR" .. normal .. " in describe '" .. name .. "'")
      
      if lust_next.format_options.show_trace then
        -- Show the full stack trace
        print(indent(lust_next.level + 1) .. red .. debug.traceback(err, 2) .. normal)
      else
        -- Show just the error message
        print(indent(lust_next.level + 1) .. red .. tostring(err) .. normal)
      end
    elseif lust_next.format_options.dot_mode then
      -- In dot mode, print an 'E' for error
      io.write(red .. "E" .. normal)
    end
  end
end

-- Focused version of describe
function lust_next.fdescribe(name, fn)
  return lust_next.describe(name, fn, {focused = true})
end

-- Excluded version of describe
function lust_next.xdescribe(name, fn)
  -- Use an empty function to ensure none of the tests within it ever run
  -- This is more robust than just marking it excluded
  return lust_next.describe(name, function() end, {excluded = true})
end

-- Set tags for the current describe block or test
function lust_next.tags(...)
  local tags_list = {...}
  
  -- Allow both tags("one", "two") and tags("one")("two") syntax
  if #tags_list == 1 and type(tags_list[1]) == "string" then
    -- Handle tags("tag1", "tag2", ...) syntax
    lust_next.current_tags = tags_list
    
    -- Return a function that can be called again to allow tags("tag1")("tag2")(fn) syntax
    return function(fn_or_tag)
      if type(fn_or_tag) == "function" then
        -- If it's a function, it's the test/describe function
        return fn_or_tag
      else
        -- If it's another tag, add it
        table.insert(lust_next.current_tags, fn_or_tag)
        -- Return itself again to allow chaining
        return lust_next.tags()
      end
    end
  else
    -- Store the tags
    lust_next.current_tags = tags_list
    return lust_next
  end
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

function lust_next.it(name, fn, options)
  options = options or {}
  local focused = options.focused or false
  local excluded = options.excluded or false
  
  -- If this is a focused test, mark that we're in focus mode
  if focused then
    lust_next.focus_mode = true
  end
  
  -- Save current tags for this test
  local test_tags = {}
  for _, tag in ipairs(lust_next.current_tags) do
    table.insert(test_tags, tag)
  end
  
  -- Determine if this test should be run
  -- Skip if:
  -- 1. It's explicitly excluded, or
  -- 2. Focus mode is active but this test is not focused, or
  -- 3. It doesn't match the filter pattern or tags
  local should_skip = excluded or
                     (lust_next.focus_mode and not focused) or
                     (not should_run_test(name, test_tags))
  
  if should_skip then
    -- Skip test but still print it as skipped
    lust_next.skipped = lust_next.skipped + 1
    
    if not lust_next.format_options.summary_only and not lust_next.format_options.dot_mode then
      local skip_reason = ""
      if excluded then
        skip_reason = " (excluded)"
      elseif lust_next.focus_mode and not focused then
        skip_reason = " (not focused)"
      end
      print(indent() .. yellow .. 'SKIP' .. normal .. ' ' .. name .. skip_reason)
    elseif lust_next.format_options.dot_mode then
      -- In dot mode, print an 'S' for skipped
      io.write(yellow .. "S" .. normal)
    end
    return
  end
  
  -- Run before hooks
  for level = 1, lust_next.level do
    if lust_next.befores[level] then
      for i = 1, #lust_next.befores[level] do
        lust_next.befores[level][i](name)
      end
    end
  end
  
  -- Handle both regular and async tests
  local success, err
  if type(fn) == "function" then
    success, err = pcall(fn)
  else
    -- If it's not a function, it might be the result of an async test that already completed
    success, err = true, fn
  end
  
  if success then
    lust_next.passes = lust_next.passes + 1
  else
    lust_next.errors = lust_next.errors + 1
  end
  
  -- Output based on format options
  if lust_next.format_options.dot_mode then
    -- In dot mode, just print a dot for pass, F for fail
    if success then
      io.write(green .. "." .. normal)
    else
      io.write(red .. "F" .. normal)
    end
  elseif not lust_next.format_options.summary_only then
    -- Full output mode
    local color = success and green or red
    local label = success and 'PASS' or 'FAIL'
    local prefix = focused and cyan .. "FOCUS " .. normal or ""
    
    -- Only show successful tests details if configured to do so
    if success and not lust_next.format_options.show_success_detail then
      if not lust_next.format_options.compact then
        print(indent() .. color .. "." .. normal)
      end
    else
      print(indent() .. color .. label .. normal .. ' ' .. prefix .. name)
    end
    
    -- Show error details
    if err and not success then
      if lust_next.format_options.show_trace then
        -- Show the full stack trace
        print(indent(lust_next.level + 1) .. red .. debug.traceback(err, 2) .. normal)
      else
        -- Show just the error message
        print(indent(lust_next.level + 1) .. red .. tostring(err) .. normal)
      end
    end
  end
  
  -- Run after hooks
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

-- Focused version of it
function lust_next.fit(name, fn)
  return lust_next.it(name, fn, {focused = true})
end

-- Excluded version of it
function lust_next.xit(name, fn)
  -- Important: Replace the function with a dummy that never runs
  -- This ensures the test is completely skipped, not just filtered
  return lust_next.it(name, function() end, {excluded = true})
end

-- Asynchronous version of it
function lust_next.it_async(name, fn, timeout)
  if not async_module then
    error("it_async requires the async module to be available", 2)
  end
  
  -- Delegate to the async module for the implementation
  local async_fn = lust_next.async(fn)
  return lust_next.it(name, function()
    return async_fn()()
  end)
end

-- Pending test helper
function lust_next.pending(message)
  message = message or "Test not yet implemented"
  if not lust_next.format_options.summary_only and not lust_next.format_options.dot_mode then
    print(indent() .. yellow .. "PENDING: " .. normal .. message)
  elseif lust_next.format_options.dot_mode then
    io.write(yellow .. "P" .. normal)
  end
  return message -- Return the message to allow it to be used as a return value
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

-- Enhanced stringify function with better formatting for different types
local function stringify(t, depth)
  depth = depth or 0
  local indent_str = string.rep("  ", depth)
  
  -- Handle basic types directly
  if type(t) == 'string' then
    return "'" .. tostring(t) .. "'"
  elseif type(t) == 'number' or type(t) == 'boolean' or type(t) == 'nil' then
    return tostring(t)
  elseif type(t) ~= 'table' or (getmetatable(t) and getmetatable(t).__tostring) then
    return tostring(t)
  end
  
  -- Handle empty tables
  if next(t) == nil then
    return "{}"
  end
  
  -- Handle tables with careful formatting
  local strings = {}
  local multiline = false
  
  -- Format array part first
  for i, v in ipairs(t) do
    if type(v) == 'table' and next(v) ~= nil and depth < 2 then
      multiline = true
      strings[#strings + 1] = indent_str .. "  " .. stringify(v, depth + 1)
    else
      strings[#strings + 1] = stringify(v, depth + 1)
    end
  end
  
  -- Format hash part next
  local hash_entries = {}
  for k, v in pairs(t) do
    if type(k) ~= 'number' or k > #t or k < 1 then
      local key_str = type(k) == 'string' and k or '[' .. stringify(k, depth + 1) .. ']'
      
      if type(v) == 'table' and next(v) ~= nil and depth < 2 then
        multiline = true
        hash_entries[#hash_entries + 1] = indent_str .. "  " .. key_str .. " = " .. stringify(v, depth + 1)
      else
        hash_entries[#hash_entries + 1] = key_str .. " = " .. stringify(v, depth + 1)
      end
    end
  end
  
  -- Combine array and hash parts
  for _, entry in ipairs(hash_entries) do
    strings[#strings + 1] = entry
  end
  
  -- Format based on content complexity
  if multiline and depth == 0 then
    return "{\n  " .. table.concat(strings, ",\n  ") .. "\n" .. indent_str .. "}"
  elseif #strings > 5 or multiline then
    return "{ " .. table.concat(strings, ", ") .. " }"
  else
    return "{ " .. table.concat(strings, ", ") .. " }"
  end
end

-- Generate a simple diff between two values
local function diff_values(v1, v2)
  if type(v1) ~= 'table' or type(v2) ~= 'table' then
    return "Expected: " .. stringify(v2) .. "\nGot:      " .. stringify(v1)
  end
  
  local differences = {}
  
  -- Check for missing keys in v1
  for k, v in pairs(v2) do
    if v1[k] == nil then
      table.insert(differences, "Missing key: " .. stringify(k) .. " (expected " .. stringify(v) .. ")")
    elseif not eq(v1[k], v, 0) then
      table.insert(differences, "Different value for key " .. stringify(k) .. ":\n  Expected: " .. stringify(v) .. "\n  Got:      " .. stringify(v1[k]))
    end
  end
  
  -- Check for extra keys in v1
  for k, v in pairs(v1) do
    if v2[k] == nil then
      table.insert(differences, "Extra key: " .. stringify(k) .. " = " .. stringify(v))
    end
  end
  
  if #differences == 0 then
    return "Values appear equal but are not identical (may be due to metatable differences)"
  end
  
  return "Differences:\n  " .. table.concat(differences, "\n  ")
end

local paths = {
  [''] = { 'to', 'to_not' },
  to = { 'have', 'equal', 'be', 'exist', 'fail', 'match', 'contain', 'start_with', 'end_with', 'be_type', 'be_greater_than', 'be_less_than', 'be_between', 'be_approximately', 'throw', 'satisfy', 'implement_interface', 'be_truthy', 'be_falsy', 'be_falsey', 'is_exact_type', 'is_instance_of', 'implements' },
  to_not = { 'have', 'equal', 'be', 'exist', 'fail', 'match', 'contain', 'start_with', 'end_with', 'be_type', 'be_greater_than', 'be_less_than', 'be_between', 'be_approximately', 'throw', 'satisfy', 'implement_interface', 'be_truthy', 'be_falsy', 'be_falsey', 'is_exact_type', 'is_instance_of', 'implements', chain = function(a) a.negate = not a.negate end },
  a = { test = isa },
  an = { test = isa },
  truthy = { test = function(v) return v and true or false, 'expected ' .. tostring(v) .. ' to be truthy', 'expected ' .. tostring(v) .. ' to not be truthy' end },
  falsy = { test = function(v) return not v, 'expected ' .. tostring(v) .. ' to be falsy', 'expected ' .. tostring(v) .. ' to not be falsy' end },
  falsey = { test = function(v) return not v, 'expected ' .. tostring(v) .. ' to be falsey', 'expected ' .. tostring(v) .. ' to not be falsey' end },
  be = { 'a', 'an', 'truthy', 'falsy', 'falsey', 'nil', 'type',
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
      return v and true or false,
        'expected ' .. tostring(v) .. ' to be truthy',
        'expected ' .. tostring(v) .. ' to not be truthy'
    end
  },
  falsy = {
    test = function(v)
      return not v and true or false,
        'expected ' .. tostring(v) .. ' to be falsy',
        'expected ' .. tostring(v) .. ' to not be falsy'
    end
  },
  ['nil'] = {
    test = function(v)
      return v == nil,
        'expected ' .. tostring(v) .. ' to be nil',
        'expected ' .. tostring(v) .. ' to not be nil'
    end
  },
  type = {
    test = function(v, expected_type)
      return type(v) == expected_type,
        'expected ' .. tostring(v) .. ' to be of type ' .. expected_type .. ', got ' .. type(v),
        'expected ' .. tostring(v) .. ' to not be of type ' .. expected_type
    end
  },
  equal = {
    test = function(v, x, eps)
      local equal = eq(v, x, eps)
      local comparison = ''
      
      if not equal then
        if type(v) == 'table' or type(x) == 'table' then
          -- For tables, generate a detailed diff
          comparison = '\n' .. indent(lust_next.level + 1) .. diff_values(v, x)
        else
          -- For primitive types, show a simple comparison
          comparison = '\n' .. indent(lust_next.level + 1) .. 'Expected: ' .. stringify(x)
                     .. '\n' .. indent(lust_next.level + 1) .. 'Got:      ' .. stringify(v)
        end
      end
      
      return equal,
        'Values are not equal: ' .. comparison,
        'expected ' .. stringify(v) .. ' and ' .. stringify(x) .. ' to not be equal'
    end
  },
  have = {
    test = function(v, x)
      if type(v) ~= 'table' then
        error('expected ' .. stringify(v) .. ' to be a table')
      end
      
      -- Create a formatted table representation for better error messages
      local table_str = stringify(v)
      local content_preview = #table_str > 70
          and table_str:sub(1, 67) .. "..."
          or table_str
      
      return has(v, x),
        'expected table to contain ' .. stringify(x) .. '\nTable contents: ' .. content_preview,
        'expected table not to contain ' .. stringify(x) .. ' but it was found\nTable contents: ' .. content_preview
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
      local result = string.find(v, p) ~= nil
      return result,
        'expected "' .. v .. '" to match pattern "' .. p .. '"',
        'expected "' .. v .. '" to not match pattern "' .. p .. '"'
    end
  },
  
  -- Interface implementation checking
  implement_interface = {
    test = function(v, interface)
      if type(v) ~= 'table' then
        return false, 'expected ' .. tostring(v) .. ' to be a table', nil
      end
      
      if type(interface) ~= 'table' then
        return false, 'expected interface to be a table', nil
      end
      
      local missing_keys = {}
      local wrong_types = {}
      
      for key, expected in pairs(interface) do
        local actual = v[key]
        
        if actual == nil then
          table.insert(missing_keys, key)
        elseif type(expected) == 'function' and type(actual) ~= 'function' then
          table.insert(wrong_types, key .. ' (expected function, got ' .. type(actual) .. ')')
        end
      end
      
      if #missing_keys > 0 or #wrong_types > 0 then
        local msg = 'expected object to implement interface, but: '
        if #missing_keys > 0 then
          msg = msg .. 'missing: ' .. table.concat(missing_keys, ', ')
        end
        if #wrong_types > 0 then
          if #missing_keys > 0 then msg = msg .. '; ' end
          msg = msg .. 'wrong types: ' .. table.concat(wrong_types, ', ')
        end
        
        return false, msg, 'expected object not to implement interface'
      end
      
      return true,
        'expected object to implement interface',
        'expected object not to implement interface'
    end
  },
  
  -- Enhanced type checking assertions (delegated to type_checking module)
  is_exact_type = {
    test = function(v, expected_type, message)
      if type_checking then
        -- Delegate to the type checking module
        local ok, err = pcall(type_checking.is_exact_type, v, expected_type, message)
        if ok then
          return true, nil, nil
        else
          return false, err, nil
        end
      else
        -- Minimal fallback if module is not available
        local actual_type = type(v)
        return actual_type == expected_type,
          message or string.format("Expected value to be exactly of type '%s', but got '%s'", expected_type, actual_type),
          "Expected value not to be of type " .. expected_type
      end
    end
  },
  
  is_instance_of = {
    test = function(v, class, message)
      if type_checking then
        -- Delegate to the type checking module
        local ok, err = pcall(type_checking.is_instance_of, v, class, message)
        if ok then
          return true, nil, nil
        else
          return false, err, nil
        end
      else
        -- Fallback to basic implementation using isa function
        return isa(v, class)
      end
    end
  },
  
  implements = {
    test = function(v, interface, message)
      if type_checking then
        -- Delegate to the type checking module
        local ok, err = pcall(type_checking.implements, v, interface, message)
        if ok then
          return true, nil, nil
        else
          return false, err, nil
        end
      else
        -- Fallback to existing implement_interface
        return paths.implement_interface.test(v, interface, message)
      end
    end
  },
  
  -- Table inspection assertions
  contain = { 'keys', 'values', 'key', 'value', 'subset', 'exactly',
    test = function(v, x)
      -- Delegate to the type_checking module if available
      if type_checking and type_checking.contains then
        local ok, err = pcall(type_checking.contains, v, x)
        if ok then
          return true, nil, nil
        else
          return false, err, nil
        end
      else
        -- Minimal fallback implementation
        if type(v) == 'string' then
          -- Handle string containment
          local x_str = tostring(x)
          return string.find(v, x_str, 1, true) ~= nil,
            'expected string "' .. v .. '" to contain "' .. x_str .. '"',
            'expected string "' .. v .. '" to not contain "' .. x_str .. '"'
        elseif type(v) == 'table' then
          -- Handle table containment
          return has(v, x),
            'expected ' .. tostring(v) .. ' to contain ' .. tostring(x),
            'expected ' .. tostring(v) .. ' to not contain ' .. tostring(x)
        else
          -- Error for unsupported types
          error('cannot check containment in a ' .. type(v))
        end
      end
    end
  },
  
  -- Check if a table contains all specified keys
  keys = {
    test = function(v, x)
      if type(v) ~= 'table' then
        error('expected ' .. tostring(v) .. ' to be a table')
      end
      
      if type(x) ~= 'table' then
        error('expected ' .. tostring(x) .. ' to be a table containing keys to check for')
      end
      
      for _, key in ipairs(x) do
        if v[key] == nil then
          return false,
            'expected ' .. stringify(v) .. ' to contain key ' .. tostring(key),
            'expected ' .. stringify(v) .. ' to not contain key ' .. tostring(key)
        end
      end
      
      return true,
        'expected ' .. stringify(v) .. ' to contain keys ' .. stringify(x),
        'expected ' .. stringify(v) .. ' to not contain keys ' .. stringify(x)
    end
  },
  
  -- Check if a table contains a specific key
  key = {
    test = function(v, x)
      if type(v) ~= 'table' then
        error('expected ' .. tostring(v) .. ' to be a table')
      end
      
      return v[x] ~= nil,
        'expected ' .. stringify(v) .. ' to contain key ' .. tostring(x),
        'expected ' .. stringify(v) .. ' to not contain key ' .. tostring(x)
    end
  },
  
  -- Numeric comparison assertions
  be_greater_than = {
    test = function(v, x)
      if type(v) ~= 'number' then
        error('expected ' .. tostring(v) .. ' to be a number')
      end
      
      if type(x) ~= 'number' then
        error('expected ' .. tostring(x) .. ' to be a number')
      end
      
      return v > x,
        'expected ' .. tostring(v) .. ' to be greater than ' .. tostring(x),
        'expected ' .. tostring(v) .. ' to not be greater than ' .. tostring(x)
    end
  },
  
  be_less_than = {
    test = function(v, x)
      if type(v) ~= 'number' then
        error('expected ' .. tostring(v) .. ' to be a number')
      end
      
      if type(x) ~= 'number' then
        error('expected ' .. tostring(x) .. ' to be a number')
      end
      
      return v < x,
        'expected ' .. tostring(v) .. ' to be less than ' .. tostring(x),
        'expected ' .. tostring(v) .. ' to not be less than ' .. tostring(x)
    end
  },
  
  be_between = {
    test = function(v, min, max)
      if type(v) ~= 'number' then
        error('expected ' .. tostring(v) .. ' to be a number')
      end
      
      if type(min) ~= 'number' or type(max) ~= 'number' then
        error('expected min and max to be numbers')
      end
      
      return v >= min and v <= max,
        'expected ' .. tostring(v) .. ' to be between ' .. tostring(min) .. ' and ' .. tostring(max),
        'expected ' .. tostring(v) .. ' to not be between ' .. tostring(min) .. ' and ' .. tostring(max)
    end
  },
  
  be_truthy = {
    test = function(v)
      return v and true or false,
        'expected ' .. tostring(v) .. ' to be truthy',
        'expected ' .. tostring(v) .. ' to not be truthy'
    end
  },
  
  be_falsy = {
    test = function(v)
      return not v,
        'expected ' .. tostring(v) .. ' to be falsy',
        'expected ' .. tostring(v) .. ' to not be falsy'
    end
  },
  
  be_falsey = {
    test = function(v)
      return not v,
        'expected ' .. tostring(v) .. ' to be falsey',
        'expected ' .. tostring(v) .. ' to not be falsey'
    end
  },
  
  be_approximately = {
    test = function(v, x, delta)
      if type(v) ~= 'number' then
        error('expected ' .. tostring(v) .. ' to be a number')
      end
      
      if type(x) ~= 'number' then
        error('expected ' .. tostring(x) .. ' to be a number')
      end
      
      delta = delta or 0.0001
      
      return math.abs(v - x) <= delta,
        'expected ' .. tostring(v) .. ' to be approximately ' .. tostring(x) .. ' (±' .. tostring(delta) .. ')',
        'expected ' .. tostring(v) .. ' to not be approximately ' .. tostring(x) .. ' (±' .. tostring(delta) .. ')'
    end
  },
  
  -- Satisfy assertion for custom predicates
  satisfy = {
    test = function(v, predicate)
      if type(predicate) ~= 'function' then
        error('expected predicate to be a function, got ' .. type(predicate))
      end
      
      local success, result = pcall(predicate, v)
      if not success then
        error('predicate function failed with error: ' .. tostring(result))
      end
      
      return result,
        'expected value to satisfy the given predicate function',
        'expected value to not satisfy the given predicate function'
    end
  },
  
  -- String assertions
  start_with = {
    test = function(v, x)
      if type(v) ~= 'string' then
        error('expected ' .. tostring(v) .. ' to be a string')
      end
      
      if type(x) ~= 'string' then
        error('expected ' .. tostring(x) .. ' to be a string')
      end
      
      return v:sub(1, #x) == x,
        'expected "' .. v .. '" to start with "' .. x .. '"',
        'expected "' .. v .. '" to not start with "' .. x .. '"'
    end
  },
  
  end_with = {
    test = function(v, x)
      if type(v) ~= 'string' then
        error('expected ' .. tostring(v) .. ' to be a string')
      end
      
      if type(x) ~= 'string' then
        error('expected ' .. tostring(x) .. ' to be a string')
      end
      
      return v:sub(-#x) == x,
        'expected "' .. v .. '" to end with "' .. x .. '"',
        'expected "' .. v .. '" to not end with "' .. x .. '"'
    end
  },
  
  -- Type checking assertions
  be_type = { 'callable', 'comparable', 'iterable',
    test = function(v, expected_type)
      if expected_type == 'callable' then
        local is_callable = type(v) == 'function' or
                         (type(v) == 'table' and getmetatable(v) and getmetatable(v).__call)
        return is_callable,
          'expected ' .. tostring(v) .. ' to be callable',
          'expected ' .. tostring(v) .. ' to not be callable'
      elseif expected_type == 'comparable' then
        local success = pcall(function() return v < v end)
        return success,
          'expected ' .. tostring(v) .. ' to be comparable',
          'expected ' .. tostring(v) .. ' to not be comparable'
      elseif expected_type == 'iterable' then
        local success = pcall(function()
          for _ in pairs(v) do break end
        end)
        return success,
          'expected ' .. tostring(v) .. ' to be iterable',
          'expected ' .. tostring(v) .. ' to not be iterable'
      else
        error('unknown type check: ' .. tostring(expected_type))
      end
    end
  },
  
  -- Enhanced error assertions
  throw = { 'error', 'error_matching', 'error_type',
    test = function(v)
      if type(v) ~= 'function' then
        error('expected ' .. tostring(v) .. ' to be a function')
      end
      
      local ok, err = pcall(v)
      return not ok, 
        'expected function to throw an error',
        'expected function to not throw an error'
    end
  },
  
  error = {
    test = function(v)
      if type(v) ~= 'function' then
        error('expected ' .. tostring(v) .. ' to be a function')
      end
      
      local ok, err = pcall(v)
      return not ok, 
        'expected function to throw an error',
        'expected function to not throw an error'
    end
  },
  
  error_matching = {
    test = function(v, pattern)
      if type(v) ~= 'function' then
        error('expected ' .. tostring(v) .. ' to be a function')
      end
      
      if type(pattern) ~= 'string' then
        error('expected pattern to be a string')
      end
      
      local ok, err = pcall(v)
      if ok then
        return false, 
          'expected function to throw an error matching pattern "' .. pattern .. '"',
          'expected function to not throw an error matching pattern "' .. pattern .. '"'
      end
      
      err = tostring(err)
      return err:match(pattern) ~= nil,
        'expected error "' .. err .. '" to match pattern "' .. pattern .. '"',
        'expected error "' .. err .. '" to not match pattern "' .. pattern .. '"'
    end
  },
  
  error_type = {
    test = function(v, expected_type)
      if type(v) ~= 'function' then
        error('expected ' .. tostring(v) .. ' to be a function')
      end
      
      local ok, err = pcall(v)
      if ok then
        return false,
          'expected function to throw an error of type ' .. tostring(expected_type),
          'expected function to not throw an error of type ' .. tostring(expected_type)
      end
      
      -- Try to determine the error type
      local error_type
      if type(err) == 'string' then
        error_type = 'string'
      elseif type(err) == 'table' then
        error_type = err.__name or 'table'
      else
        error_type = type(err)
      end
      
      return error_type == expected_type,
        'expected error of type ' .. error_type .. ' to be of type ' .. expected_type,
        'expected error of type ' .. error_type .. ' to not be of type ' .. expected_type
    end
  }
}

function lust_next.expect(v)
  -- Count assertion
  lust_next.assertion_count = (lust_next.assertion_count or 0) + 1
  
  -- Track assertion in quality module if enabled
  if lust_next.quality_options.enabled and quality then
    quality.track_assertion("expect", debug.getinfo(2, "n").name)
  end
  
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

-- Load the mocking system directly from lib/mocking
package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path
local mocking_ok, mocking = pcall(require, "lib.mocking")

-- If the mocking module is available, use it
if mocking_ok and mocking then
  -- Export the mocking functionality to lust_next
  lust_next.spy = mocking.spy
  lust_next.stub = mocking.stub
  lust_next.mock = mocking.mock
  lust_next.with_mocks = mocking.with_mocks
  lust_next.arg_matcher = mocking.arg_matcher or {}
  
  -- Override the test runner to use our mocking system
  local original_it = lust_next.it
  lust_next.it = function(name, fn, options)
    local wrapped_fn
    
    if options and (options.focused or options.excluded) then
      -- If this is a focused or excluded test, don't wrap it with mocking
      wrapped_fn = fn
    else
      -- Otherwise, wrap the function with mocking context
      wrapped_fn = function()
        return mocking.with_mocks(function()
          return fn()
        end)
      end
    end
    
    return original_it(name, wrapped_fn, options)
  end
end

-- CLI Helper functions
function lust_next.parse_args(args)
  local options = {
    dir = "./tests",
    format = "default",
    tags = {},
    filter = nil,
    files = {},
    interactive = false, -- Interactive CLI mode option
    watch = false,       -- Watch mode option
    
    -- Report configuration options
    report_dir = "./coverage-reports",
    report_suffix = nil,
    coverage_path_template = nil,
    quality_path_template = nil,
    results_path_template = nil,
    timestamp_format = "%Y-%m-%d",
    verbose = false,
    
    -- Custom formatter options
    coverage_format = nil,      -- Custom format for coverage reports
    quality_format = nil,       -- Custom format for quality reports
    results_format = nil,       -- Custom format for test results
    formatter_module = nil      -- Custom formatter module to load
  }
  
  local i = 1
  while i <= #args do
    if args[i] == "--dir" and args[i+1] then
      options.dir = args[i+1]
      i = i + 2
    elseif args[i] == "--format" and args[i+1] then
      options.format = args[i+1]
      i = i + 2
    elseif args[i] == "--tags" and args[i+1] then
      for tag in args[i+1]:gmatch("[^,]+") do
        table.insert(options.tags, tag:match("^%s*(.-)%s*$")) -- Trim whitespace
      end
      i = i + 2
    elseif args[i] == "--filter" and args[i+1] then
      options.filter = args[i+1]
      i = i + 2
    elseif args[i] == "--help" or args[i] == "-h" then
      lust_next.show_help()
      os.exit(0)
    elseif args[i] == "--file" and args[i+1] then
      table.insert(options.files, args[i+1])
      i = i + 2
    elseif args[i] == "--watch" or args[i] == "-w" then
      options.watch = true
      i = i + 1
    elseif args[i] == "--interactive" or args[i] == "-i" then
      options.interactive = true
      i = i + 1
    -- Report configuration options
    elseif args[i] == "--output-dir" and args[i+1] then
      options.report_dir = args[i+1]
      i = i + 2
    elseif args[i] == "--report-suffix" and args[i+1] then
      options.report_suffix = args[i+1]
      i = i + 2
    elseif args[i] == "--coverage-path" and args[i+1] then
      options.coverage_path_template = args[i+1]
      i = i + 2
    elseif args[i] == "--quality-path" and args[i+1] then
      options.quality_path_template = args[i+1]
      i = i + 2
    elseif args[i] == "--results-path" and args[i+1] then
      options.results_path_template = args[i+1]
      i = i + 2
    elseif args[i] == "--timestamp-format" and args[i+1] then
      options.timestamp_format = args[i+1]
      i = i + 2
    elseif args[i] == "--verbose-reports" then
      options.verbose = true
      i = i + 1
    -- Custom formatter options
    elseif args[i] == "--coverage-format" and args[i+1] then
      options.coverage_format = args[i+1]
      i = i + 2
    elseif args[i] == "--quality-format" and args[i+1] then
      options.quality_format = args[i+1]
      i = i + 2
    elseif args[i] == "--results-format" and args[i+1] then
      options.results_format = args[i+1]
      i = i + 2
    elseif args[i] == "--formatter-module" and args[i+1] then
      options.formatter_module = args[i+1]
      i = i + 2
    elseif args[i]:match("%.lua$") then
      table.insert(options.files, args[i])
      i = i + 1
    else
      i = i + 1
    end
  end
  
  return options
end

function lust_next.show_help()
  print("lust-next test runner v" .. lust_next.version)
  print("Usage:")
  print("  lua lust-next.lua [options] [file.lua]")
  
  print("\nTest Selection Options:")
  print("  --dir DIR        Directory to search for tests (default: ./tests)")
  print("  --file FILE      Run a specific test file")
  print("  --tags TAG1,TAG2 Only run tests with matching tags")
  print("  --filter PATTERN Only run tests with names matching pattern")
  
  print("\nOutput Format Options:")
  print("  --format FORMAT  Output format (dot, compact, summary, detailed, plain)")
  
  print("\nRuntime Mode Options:")
  print("  --interactive, -i Start interactive CLI mode")
  print("  --watch, -w      Watch for file changes and automatically re-run tests")
  
  print("\nReport Configuration Options:")
  print("  --output-dir DIR       Base directory for all reports (default: ./coverage-reports)")
  print("  --report-suffix STR    Add a suffix to all report filenames (e.g., \"-v1.0\")")
  print("  --coverage-path PATH   Path template for coverage reports")
  print("  --quality-path PATH    Path template for quality reports")
  print("  --results-path PATH    Path template for test results reports")
  print("  --timestamp-format FMT Format string for timestamps (default: \"%Y-%m-%d\")")
  print("  --verbose-reports      Enable verbose output during report generation")
  print("\n  Path templates support the following placeholders:")
  print("    {format}    - Output format (html, json, etc.)")
  print("    {type}      - Report type (coverage, quality, etc.)")
  print("    {date}      - Current date using timestamp format")
  print("    {datetime}  - Current date and time (%Y-%m-%d_%H-%M-%S)")
  print("    {suffix}    - The report suffix if specified")
  
  print("\nCustom Formatter Options:")
  print("  --coverage-format FMT  Set format for coverage reports (html, json, lcov, or custom)")
  print("  --quality-format FMT   Set format for quality reports (html, json, summary, or custom)")
  print("  --results-format FMT   Set format for test results (junit, tap, csv, or custom)")
  print("  --formatter-module MOD Load custom formatter module (Lua module path)")
  
  print("\nExamples:")
  print("  lua lust-next.lua --dir tests --format dot")
  print("  lua lust-next.lua --tags unit,api --format compact")
  print("  lua lust-next.lua tests/specific_test.lua")
  print("  lua lust-next.lua --interactive")
  print("  lua lust-next.lua --watch tests/specific_test.lua")
  print("  lua lust-next.lua --coverage --output-dir ./reports --report-suffix \"-$(date +%Y%m%d)\"")
  print("  lua lust-next.lua --coverage-path \"coverage-{date}.{format}\"")
  print("  lua lust-next.lua --formatter-module \"my_formatters\" --results-format \"markdown\"")
end

-- Create a module that can be required
local module = setmetatable({
  lust_next = lust_next,
  
  -- Export paths to allow extensions to register assertions
  paths = paths,
  
  -- Export the main functions directly
  describe = lust_next.describe,
  fdescribe = lust_next.fdescribe,
  xdescribe = lust_next.xdescribe,
  it = lust_next.it,
  fit = lust_next.fit,
  xit = lust_next.xit,
  it_async = lust_next.it_async,
  before = lust_next.before,
  after = lust_next.after,
  pending = lust_next.pending,
  expect = lust_next.expect,
  tags = lust_next.tags,
  only_tags = lust_next.only_tags,
  filter = lust_next.filter,
  reset = lust_next.reset,
  reset_filters = lust_next.reset_filters,
  
  -- Export CLI functions
  parse_args = lust_next.parse_args,
  show_help = lust_next.show_help,
  
  -- Export mocking functions if available
  spy = lust_next.spy,
  stub = lust_next.stub,
  mock = lust_next.mock,
  with_mocks = lust_next.with_mocks,
  arg_matcher = lust_next.arg_matcher,
  
  -- Export async functions
  async = lust_next.async,
  await = lust_next.await,
  wait_until = lust_next.wait_until,
  
  -- Export interactive mode
  interactive = interactive,
  
  -- Global exposure utility for easier test writing
  expose_globals = function()
    -- Test building blocks
    _G.describe = lust_next.describe
    _G.fdescribe = lust_next.fdescribe
    _G.xdescribe = lust_next.xdescribe
    _G.it = lust_next.it
    _G.fit = lust_next.fit
    _G.xit = lust_next.xit
    _G.before = lust_next.before
    _G.before_each = lust_next.before  -- Alias for compatibility
    _G.after = lust_next.after
    _G.after_each = lust_next.after    -- Alias for compatibility
    
    -- Assertions
    _G.expect = lust_next.expect
    _G.pending = lust_next.pending
    
    -- Add lust.assert namespace for direct assertions
    if not lust_next.assert then
      lust_next.assert = {}
      
      -- Define basic assertions
      lust_next.assert.equal = function(actual, expected, message)
        if actual ~= expected then
          error(message or ("Expected " .. tostring(actual) .. " to equal " .. tostring(expected)), 2)
        end
        return true
      end
      
      lust_next.assert.not_equal = function(actual, expected, message)
        if actual == expected then
          error(message or ("Expected " .. tostring(actual) .. " to not equal " .. tostring(expected)), 2)
        end
        return true
      end
      
      lust_next.assert.is_true = function(value, message)
        if value ~= true then
          error(message or ("Expected value to be true, got " .. tostring(value)), 2)
        end
        return true
      end
      
      lust_next.assert.is_false = function(value, message)
        if value ~= false then
          error(message or ("Expected value to be false, got " .. tostring(value)), 2)
        end
        return true
      end
      
      lust_next.assert.is_nil = function(value, message)
        if value ~= nil then
          error(message or ("Expected value to be nil, got " .. tostring(value)), 2)
        end
        return true
      end
      
      lust_next.assert.is_not_nil = function(value, message)
        if value == nil then
          error(message or "Expected value to not be nil", 2)
        end
        return true
      end
      
      lust_next.assert.is_truthy = function(value, message)
        if not value then
          error(message or ("Expected value to be truthy, got " .. tostring(value)), 2)
        end
        return true
      end
      
      lust_next.assert.is_falsey = function(value, message)
        if value then
          error(message or ("Expected value to be falsey, got " .. tostring(value)), 2)
        end
        return true
      end
      
      -- Additional assertion methods for enhanced reporting tests
      lust_next.assert.not_nil = lust_next.assert.is_not_nil
      
      lust_next.assert.contains = function(container, item, message)
        if type_checking then
          -- Delegate to the type checking module
          return type_checking.contains(container, item, message)
        else
          -- Simple fallback implementation
          if type(container) == "string" then
            -- Handle string containment
            local item_str = tostring(item)
            if not string.find(container, item_str, 1, true) then
              error(message or ("Expected string to contain '" .. item_str .. "'"), 2)
            end
            return true
          elseif type(container) == "table" then
            -- Handle table containment
            for _, value in pairs(container) do
              if value == item then
                return true
              end
            end
            error(message or ("Expected table to contain " .. tostring(item)), 2)
          else
            -- Error for unsupported types
            error("Cannot check containment in a " .. type(container), 2)
          end
        end
      end
      
      -- Add enhanced type checking assertions (delegate to type_checking module)
      lust_next.assert.is_exact_type = function(value, expected_type, message)
        if type_checking then
          -- Delegate to the type checking module
          return type_checking.is_exact_type(value, expected_type, message)
        else
          -- Minimal fallback
          if type(value) ~= expected_type then
            error(message or ("Expected value to be exactly of type '" .. expected_type .. "', got '" .. type(value) .. "'"), 2)
          end
          return true
        end
      end
      
      lust_next.assert.is_instance_of = function(object, class, message)
        if type_checking then
          -- Delegate to the type checking module
          return type_checking.is_instance_of(object, class, message)
        else
          -- Basic fallback
          if type(object) ~= 'table' or type(class) ~= 'table' then
            error(message or "Expected an object and a class (both tables)", 2)
          end
          
          local mt = getmetatable(object)
          if not mt or mt ~= class then
            error(message or "Object is not an instance of the specified class", 2)
          end
          
          return true
        end
      end
      
      lust_next.assert.implements = function(object, interface, message)
        if type_checking then
          -- Delegate to the type checking module
          return type_checking.implements(object, interface, message)
        else
          -- Simple fallback
          if type(object) ~= 'table' or type(interface) ~= 'table' then
            error(message or "Expected an object and an interface (both tables)", 2)
          end
          
          -- Check all interface keys
          for key, expected in pairs(interface) do
            if object[key] == nil then
              error(message or ("Object missing required property: " .. key), 2)
            end
          end
          
          return true
        end
      end
      
      lust_next.assert.has_error = function(fn, message)
        if type_checking then
          -- Delegate to the type checking module
          return type_checking.has_error(fn, message)
        else
          -- Simple fallback
          if type(fn) ~= 'function' then
            error("Expected a function to test for errors", 2)
          end
          
          local ok, err = pcall(fn)
          if ok then
            error(message or "Expected function to throw an error, but it did not", 2)
          end
          
          return err
        end
      end
      
      -- Add satisfies assertion for predicate testing
      lust_next.assert.satisfies = function(value, predicate, message)
        if type(predicate) ~= 'function' then
          error("Expected second argument to be a predicate function", 2)
        end
        
        local success, result = pcall(predicate, value)
        if not success then
          error("Predicate function failed: " .. result, 2)
        end
        
        if not result then
          error(message or "Expected value to satisfy the predicate function", 2)
        end
        
        return true
      end
      
      lust_next.assert.type_of = function(value, expected_type, message)
        if type(value) ~= expected_type then
          error(message or ("Expected value to be of type '" .. expected_type .. "', got '" .. type(value) .. "'"), 2)
        end
        return true
      end
    end
    
    -- Expose lust.assert namespace and global assert for convenience
    _G.lust = { assert = lust_next.assert }
    _G.assert = lust_next.assert
    
    -- Mocking utilities
    if lust_next.spy then
      _G.spy = lust_next.spy
      _G.stub = lust_next.stub
      _G.mock = lust_next.mock
      _G.with_mocks = lust_next.with_mocks
    end
    
    -- Async testing utilities
    if async_module then
      _G.async = lust_next.async
      _G.await = lust_next.await
      _G.wait_until = lust_next.wait_until
      _G.it_async = lust_next.it_async
    end
    
    return lust_next
  end,

  -- Main entry point when called
  __call = function(_, ...)
    -- Check if we are running tests directly or just being required
    local info = debug.getinfo(2, "S")
    local is_main_module = info and (info.source == "=(command line)" or info.source:match("lust%-next%.lua$"))
    
    if is_main_module and arg then
      -- Parse command line arguments
      local options = lust_next.parse_args(arg)
      
      -- Start interactive mode if requested
      if options.interactive then
        if interactive then
          interactive.start(lust_next, {
            test_dir = options.dir,
            pattern = options.files[1] or "*_test.lua",
            watch_mode = options.watch
          })
          return lust_next
        else
          print("Error: Interactive mode not available. Make sure src/interactive.lua exists.")
          os.exit(1)
        end
      end
      
      -- Apply format options
      if options.format == "dot" then
        lust_next.format({ dot_mode = true })
      elseif options.format == "compact" then
        lust_next.format({ compact = true, show_success_detail = false })
      elseif options.format == "summary" then
        lust_next.format({ summary_only = true })
      elseif options.format == "detailed" then
        lust_next.format({ show_success_detail = true, show_trace = true })
      elseif options.format == "plain" then
        lust_next.format({ use_color = false })
      end
      
      -- Apply tag filtering
      if #options.tags > 0 then
        lust_next.only_tags(table.unpack(options.tags))
      end
      
      -- Apply pattern filtering
      if options.filter then
        lust_next.filter(options.filter)
      end
      
      -- Handle watch mode
      if options.watch then
        if watcher then
          print("Starting watch mode...")
          
          -- Set up watcher
          watcher.set_check_interval(2) -- 2 seconds
          watcher.init({"."}, {"node_modules", "%.git"})
          
          -- Run tests
          local run_tests = function()
            lust_next.reset()
            if #options.files > 0 then
              -- Run specific files
              for _, file in ipairs(options.files) do
                lust_next.run_file(file)
              end
            else
              -- Run all discovered tests
              lust_next.run_discovered(options.dir)
            end
          end
          
          -- Initial test run
          run_tests()
          
          -- Watch loop
          print("Watching for changes. Press Ctrl+C to exit.")
          while true do
            local changes = watcher.check_for_changes()
            if changes then
              print("\nFile changes detected. Re-running tests...")
              run_tests()
            end
            os.execute("sleep 0.5")
          end
          
          return lust_next
        else
          print("Error: Watch mode not available. Make sure src/watcher.lua exists.")
          os.exit(1)
        end
      end
      
      -- Run tests normally (no watch mode or interactive mode)
      if #options.files > 0 then
        -- Run specific files
        local success = true
        for _, file in ipairs(options.files) do
          local file_results = lust_next.run_file(file)
          if not file_results.success or file_results.errors > 0 then
            success = false
          end
        end
        
        -- Exit with appropriate code
        os.exit(success and 0 or 1)
      else
        -- Run all discovered tests
        local success = lust_next.run_discovered(options.dir)
        os.exit(success and 0 or 1)
      end
    end
    
    -- When required as module, just return the module
    return lust_next
  end,
}, {
  __index = lust_next
})

return module