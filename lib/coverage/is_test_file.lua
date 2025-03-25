---@class coverage.test_file_detector
---@field is_test_file fun(file_path: string, file_content?: string): boolean Check if a file is a test file based on path patterns and content
---@field is_framework_file fun(file_path: string): boolean Check if a file is part of the Firmo framework
---@field is_runnable_source fun(file_path: string): boolean Check if a file should be included in coverage (not a test or framework file)
---@field cache_test_file fun(file_path: string, is_test: boolean): boolean Add file to test files cache

--- Test file detector module for Firmo coverage system
--- Provides utilities to determine whether a file is:
--- 1. A test file (user or framework)
--- 2. A framework file (part of Firmo)
--- 3. A runnable source file (should be included in coverage)
---
--- @author Firmo Team
--- @version 1.0.0
local M = {}

local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("coverage.test_file_detector")

-- Try to load configuration without creating special cases or hardcoded paths
local config_module = pcall(require, "lib.coverage.config")
local config = config_module and require("lib.coverage.config") or {}

--- Helper function to check if a path matches any pattern in a list
---@param path string The path to check
---@param patterns table A list of patterns to match against
---@return boolean matches Whether the path matches any pattern
local function path_matches_any_pattern(path, patterns)
  if not patterns or type(patterns) ~= "table" then
    return false
  end

  for _, pattern in ipairs(patterns) do
    if path:match(pattern) then
      return true
    end
  end
  
  return false
end

-- Cache of known test files
local test_file_cache = {}
local framework_file_cache = {}
local source_file_cache = {}

--- Check if a file is a test file based on path patterns and content analysis
---@param file_path string The path to the file to check
---@param file_content? string Optional file content for more accurate detection
---@return boolean is_test Whether the file is a test file
function M.is_test_file(file_path, file_content)
  -- Check cache first for performance
  if test_file_cache[file_path] ~= nil then
    return test_file_cache[file_path]
  end
  
  -- 1. Check by file path patterns - common test file indicators
  local is_test_by_path = file_path:match("_test%.lua$") or 
                          file_path:match("_spec%.lua$") or
                          file_path:match("/tests/") or
                          file_path:match("/test/") or
                          file_path:match("test_.*%.lua$") or
                          file_path:match("spec_.*%.lua$") or
                          file_path:match("/spec/")
  
  if is_test_by_path then
    test_file_cache[file_path] = true
    return true
  end
  
  -- 2. Check by file content if provided
  if file_content then
    local is_test_by_content = file_content:match("local%s+[%w_]+%s*=%s*require%(['\"]firmo['\"]%)") or
                              file_content:match("describe%(['\"].-%['\"],%s*function") or
                              file_content:match("it%(['\"].-%['\"],%s*function") or
                              file_content:match("expect%(.-%):to%.") or
                              file_content:match("firmo%.describe") or
                              file_content:match("firmo%.it") or
                              file_content:match("firmo%.expect") or
                              file_content:match("assert%.") and file_content:match("test") or
                              file_content:match("function test[A-Z]") or
                              file_content:match("expect%(")
    
    if is_test_by_content then
      test_file_cache[file_path] = true
      return true
    end
  end
  
  -- Not a test file based on available information
  test_file_cache[file_path] = false
  return false
end

--- Check if a file is part of the Firmo framework
---@param file_path string The path to the file to check
---@return boolean is_framework Whether the file is part of the framework
function M.is_framework_file(file_path)
  -- Check cache first for performance
  if framework_file_cache[file_path] ~= nil then
    return framework_file_cache[file_path]
  end
  
  -- Only use central configuration system
  local central_config = require("lib.core.central_config")
  
  -- Check the exclude patterns - excluded files are NOT framework files
  local exclude_patterns = central_config.get("coverage.exclude", {})
  
  -- By default, a non-excluded Lua file is not considered a framework file
  local is_framework = false
  
  -- Files matching exclude patterns are not processed for coverage
  if path_matches_any_pattern(file_path, exclude_patterns) then
    is_framework = false
  end
  
  -- Update cache and return
  framework_file_cache[file_path] = is_framework
  return is_framework
end

--- Check if a file should be included in coverage (not a test or framework file)
---@param file_path string The path to the file to check
---@param file_content? string Optional file content for more accurate detection
---@return boolean is_source Whether the file is runnable source code
function M.is_runnable_source(file_path, file_content)
  -- Check cache first for performance
  if source_file_cache[file_path] ~= nil then
    return source_file_cache[file_path]
  end
  
  -- Must be a Lua file
  if not file_path:match("%.lua$") then
    source_file_cache[file_path] = false
    return false
  end
  
  -- Must not be a test file
  if M.is_test_file(file_path, file_content) then
    source_file_cache[file_path] = false
    return false
  end
  
  -- Must not be a framework file
  if M.is_framework_file(file_path) then
    source_file_cache[file_path] = false
    return false
  end
  
  -- Is a runnable source file that should be included in coverage
  source_file_cache[file_path] = true
  return true
end

--- Add a file to the test files cache
---@param file_path string The path to the file to cache
---@param is_test boolean Whether it's a test file
---@return boolean success Always returns true
function M.cache_test_file(file_path, is_test)
  test_file_cache[file_path] = is_test
  return true
end

--- Reset the cache (for testing purposes)
---@return boolean success Always returns true
function M.reset_cache()
  test_file_cache = {}
  framework_file_cache = {}
  source_file_cache = {}
  return true
end

return M