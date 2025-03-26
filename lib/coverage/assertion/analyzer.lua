---@class CoverageAssertionAnalyzer
---@field analyze_assertion fun(assertion_type: string, subject: any, expected: any, success: boolean, call_stack: string): table Analyze assertion to determine verified lines
---@field analyze_call_stack fun(call_stack: string): table Analyze call stack to determine source locations
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local transformer = require("lib.coverage.instrumentation.transformer")

-- Version
M._VERSION = "0.1.0"

-- Analyze call stack to determine source locations
---@param call_stack string The call stack trace
---@return table locations List of source locations
function M.analyze_call_stack(call_stack)
  -- Parameter validation
  error_handler.assert(type(call_stack) == "string", "call_stack must be a string", error_handler.CATEGORY.VALIDATION)
  
  local locations = {}
  
  -- Parse the call stack
  for line in call_stack:gmatch("[^\r\n]+") do
    -- Look for file paths and line numbers
    local file_path, line_number = line:match("([^:]+):(%d+): in")
    
    if file_path and line_number then
      -- Clean up the file path
      if file_path:sub(1, 1) == "@" then
        file_path = file_path:sub(2)
      end
      
      -- Create a file ID
      local file_id = transformer.create_file_id(file_path)
      
      -- Add to locations
      table.insert(locations, {
        file_path = file_path,
        file_id = file_id,
        line_number = tonumber(line_number)
      })
    end
  end
  
  return locations
end

-- Determine the main test file from call stack
---@param locations table List of source locations
---@return table|nil test_file The main test file location
local function find_test_file(locations)
  -- Look for files with "_test.lua" in the name
  for _, location in ipairs(locations) do
    if location.file_path:match("_test%.lua$") then
      return location
    end
  end
  
  -- If no test file found, look for files with "test" in the path
  for _, location in ipairs(locations) do
    if location.file_path:match("[/\\]tests?[/\\]") then
      return location
    end
  end
  
  -- If no test file found, return the first location
  return locations[1]
end

-- Find the subject file from call stack (the file being tested)
---@param locations table List of source locations
---@param test_file table The main test file location
---@return table|nil subject_file The subject file location
local function find_subject_file(locations, test_file)
  -- Exclude the test file and any library/framework files
  local candidates = {}
  
  for _, location in ipairs(locations) do
    -- Skip the test file
    if location.file_path == test_file.file_path then
      goto continue
    end
    
    -- Skip library/framework files
    if location.file_path:match("[/\\]lib[/\\]coverage[/\\]") or
       location.file_path:match("[/\\]lib[/\\]assertion%.lua$") or
       location.file_path:match("[/\\]firmo%.lua$") then
      goto continue
    end
    
    -- Add to candidates
    table.insert(candidates, location)
    
    ::continue::
  end
  
  -- Return the first candidate
  return candidates[1]
end

-- Analyze an assertion to determine verified lines
---@param assertion_type string The type of assertion (e.g., "equal", "be_truthy")
---@param subject any The subject of the assertion
---@param expected any The expected value (if applicable)
---@param success boolean Whether the assertion succeeded
---@param call_stack string The call stack trace
---@return table verified_lines List of lines verified by this assertion
function M.analyze_assertion(assertion_type, subject, expected, success, call_stack)
  -- Parameter validation
  error_handler.assert(type(assertion_type) == "string", "assertion_type must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(success) == "boolean", "success must be a boolean", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(call_stack) == "string", "call_stack must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Analyze the call stack
  local locations = M.analyze_call_stack(call_stack)
  
  -- Find the main test file
  local test_file = find_test_file(locations)
  if not test_file then
    logger.debug("Could not find test file in call stack")
    return {}
  end
  
  -- Find the subject file
  local subject_file = find_subject_file(locations, test_file)
  if not subject_file then
    logger.debug("Could not find subject file in call stack")
    
    -- Default to just marking the test file lines
    return {
      {
        file_path = test_file.file_path,
        file_id = test_file.file_id,
        line_number = test_file.line_number
      }
    }
  end
  
  -- Determine verified lines
  local verified_lines = {}
  
  -- Mark the line in the subject file
  table.insert(verified_lines, {
    file_path = subject_file.file_path,
    file_id = subject_file.file_id,
    line_number = subject_file.line_number
  })
  
  -- Also mark the assertion line in the test file
  table.insert(verified_lines, {
    file_path = test_file.file_path,
    file_id = test_file.file_id,
    line_number = test_file.line_number
  })
  
  return verified_lines
end

return M