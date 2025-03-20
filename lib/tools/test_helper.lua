-- Test helper module for improved error handling and temporary file management
--
-- This module provides utilities to make it easier to test error conditions
-- and work with temporary files in tests.
--
-- Usage examples:
-- 
-- 1. Using with_error_capture to safely test functions that throw errors:
--    ```lua
--    -- This captures errors and returns them as structured objects
--    local result, err = test_helper.with_error_capture(function()
--      some_function_that_throws()
--    end)()
--    
--    -- Now you can make assertions about the error
--    expect(err).to.exist()
--    expect(err.message).to.match("expected error message")
--    ```
--
-- 2. Using expect_error to verify a function throws an error with a specific message:
--    ```lua
--    -- This will automatically check that the function fails with the right message
--    local err = test_helper.expect_error(fails_with_message, "expected error")
--    ```
--
-- 3. Adding the expect_error flag to tests that are expected to have errors:
--    ```lua
--    it("should handle error conditions", { expect_error = true }, function()
--      -- Any errors in this test will be properly handled
--      local result, err = function_that_errors()
--      expect(result).to_not.exist()
--      expect(err).to.exist()
--    end)
--    ```
--
-- 4. Working with temporary test directories:
--    ```lua
--    -- Create a test directory for use throughout the test
--    local test_dir = test_helper.create_temp_test_directory()
--    
--    -- Create files in the test directory
--    test_dir.create_file("config.json", '{"setting": "value"}')
--    test_dir.create_file("subdir/data.txt", "nested file content")
--    
--    -- Use the directory in tests
--    local config_path = test_dir.path .. "/config.json"
--    expect(fs.file_exists(config_path)).to.be_truthy()
--    ```
--
-- 5. Creating a test directory with predefined content:
--    ```lua
--    test_helper.with_temp_test_directory({
--      ["config.json"] = '{"setting": "value"}',
--      ["data.txt"] = "test data",
--      ["scripts/helper.lua"] = "return function() return true end"
--    }, function(dir_path, files, test_dir)
--      -- Test code here...
--      expect(fs.file_exists(dir_path .. "/config.json")).to.be_truthy()
--    end)
--    ```
--
local error_handler = require("lib.tools.error_handler")
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

local helper = {}

-- Function that safely wraps test functions expected to fail
-- This provides a standardized way to test error conditions
function helper.with_error_capture(fn)
  return function()
    -- Set up test to expect errors
    error_handler.set_current_test_metadata({
      name = debug.getinfo(2, "n").name or "unknown",
      expect_error = true
    })
    
    -- Use protected call
    local success, result = pcall(fn)
    
    -- Clear test metadata
    error_handler.set_current_test_metadata(nil)
    
    if not success then
      -- Captured an expected error - process it
      
      -- Return a structured error object for easy inspection
      if type(result) == "string" then
        return nil, error_handler.test_expected_error(result, {
          captured_error = result,
          source = debug.getinfo(2, "S").source
        })
      else
        return nil, result
      end
    end
    
    return result
  end
end

-- Function to verify that a function throws an error
-- Returns the error object/message for further inspection
function helper.expect_error(fn, message_pattern)
  local result, err = helper.with_error_capture(fn)()
  
  if result ~= nil then
    error(error_handler.test_expected_error(
      "Function was expected to throw an error but it returned a value",
      { returned_value = result }
    ))
  end
  
  if not err then
    error(error_handler.test_expected_error(
      "Function was expected to throw an error but no error was thrown"
    ))
  end
  
  if message_pattern and type(err) == "table" and err.message then
    if not err.message:match(message_pattern) then
      error(error_handler.test_expected_error(
        "Error message does not match expected pattern",
        {
          expected_pattern = message_pattern,
          actual_message = err.message
        }
      ))
    end
  end
  
  return err
end

-- Helper to create a temporary directory that tests can use throughout their execution
function helper.create_temp_test_directory()
  -- Create a temporary directory
  local dir_path, err = temp_file.create_temp_directory()
  if not dir_path then
    error(error_handler.io_error(
      "Failed to create temporary test directory: " .. tostring(err),
      { error = err }
    ))
  end
  
  -- Return a directory context with helper functions
  return {
    -- Full path to the temporary directory
    path = dir_path,
    
    -- Helper to create a file in this directory
    create_file = function(file_name, content)
      local file_path = dir_path .. "/" .. file_name
      
      -- Ensure parent directories exist
      local dir_name = file_path:match("(.+)/[^/]+$")
      if dir_name and dir_name ~= dir_path then
        local success, mkdir_err = fs.create_directory(dir_name)
        if not success then
          error(error_handler.io_error(
            "Failed to create parent directory: " .. dir_name,
            { error = mkdir_err }
          ))
        end
        -- Register the created directory
        temp_file.register_directory(dir_name)
      end
      
      -- Write the file
      local success, write_err = fs.write_file(file_path, content)
      if not success then
        error(error_handler.io_error(
          "Failed to create test file: " .. file_path,
          { error = write_err }
        ))
      end
      
      -- Register the file with temp_file tracking system
      temp_file.register_file(file_path)
      
      return file_path
    end,
    
    -- Helper to create a subdirectory
    create_subdirectory = function(subdir_name)
      local subdir_path = dir_path .. "/" .. subdir_name
      local success, err = fs.create_directory(subdir_path)
      if not success then
        error(error_handler.io_error(
          "Failed to create test subdirectory: " .. subdir_path,
          { error = err }
        ))
      end
      
      -- Register the directory with temp_file tracking system
      temp_file.register_directory(subdir_path)
      
      return subdir_path
    end,
    
    -- Helper to check if a file exists in this directory
    file_exists = function(file_name)
      return fs.file_exists(dir_path .. "/" .. file_name)
    end,
    
    -- Helper to read a file from this directory
    read_file = function(file_name)
      return fs.read_file(dir_path .. "/" .. file_name)
    end,
    
    -- Helper to generate a unique filename in the test directory
    unique_filename = function(prefix, extension)
      prefix = prefix or "temp"
      extension = extension or "tmp"
      
      local timestamp = os.time()
      local random = math.random(10000, 99999)
      return prefix .. "_" .. timestamp .. "_" .. random .. "." .. extension
    end,
    
    -- Helper to create a series of numbered files
    create_numbered_files = function(basename, content_pattern, count)
      local files = {}
      for i = 1, count do
        local filename = string.format("%s_%03d.txt", basename, i)
        local content = string.format(content_pattern, i)
        local path = self.create_file(filename, content)
        table.insert(files, path)
      end
      return files
    end,
    
    -- Helper to write a file that automatically registers it
    write_file = function(filename, content)
      local file_path = dir_path .. "/" .. filename
      local success, err = fs.write_file(file_path, content)
      if success then
        temp_file.register_file(file_path)
      end
      return success, err
    end
  }
end

-- Helper for creating a temporary test directory with predefined content
function helper.with_temp_test_directory(files_map, callback)
  -- Create a temporary directory
  local test_dir = helper.create_temp_test_directory()
  
  -- Create all the specified files
  local created_files = {}
  for file_name, content in pairs(files_map) do
    local file_path = test_dir.create_file(file_name, content)
    table.insert(created_files, file_path)
  end
  
  -- Call the callback with the directory path and context
  local results = {pcall(callback, test_dir.path, created_files, test_dir)}
  local success = table.remove(results, 1)
  
  -- Note: cleanup happens automatically via temp_file.cleanup_test_context
  -- which is called by the test runner
  
  if not success then
    error(results[1])  -- Re-throw the error
  end
  
  local unpack_table = table.unpack or unpack
  return unpack_table(results)
end

-- Helper to manually register existing files for cleanup
function helper.register_temp_file(file_path)
  return temp_file.register_file(file_path)
end

-- Helper to manually register existing directories for cleanup
function helper.register_temp_directory(dir_path)
  return temp_file.register_directory(dir_path)
end

return helper