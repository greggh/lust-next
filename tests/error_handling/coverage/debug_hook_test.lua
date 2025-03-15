-- Tests for debug_hook.lua error handling
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Core dependencies
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local debug_hook = require("lib.coverage.debug_hook")

-- Configure logging for tests
logging.configure({
  level = logging.LEVELS.FATAL,  -- Only show the most severe errors
  use_colors = false,
  timestamp_format = "none"
})

-- Configure error handler for testing
error_handler.configure({
  use_assertions = false,
  verbose = false,
  trace_errors = false,
  log_all_errors = false,
  exit_on_fatal = false,
  capture_backtraces = true
})

describe("Debug Hook Error Handling", function()
  -- Set up a clean test environment before each test
  before(function()
    debug_hook.reset()
  end)

  -- Clean up after each test
  after(function()
    debug_hook.reset()
  end)

  describe("set_config", function()
    it("should validate config parameter", function()
      -- Test with nil config
      local success, err = debug_hook.set_config(nil)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("Config must be a table")
      
      -- Test with non-table config
      success, err = debug_hook.set_config("not a table")
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("Config must be a table")
      
      -- Test with valid config
      success = debug_hook.set_config({})
      expect(success).to.be_truthy()
    end)
  end)

  describe("initialize_file", function()
    it("should validate file_path parameter", function()
      -- Test with nil file_path
      local success, err = debug_hook.initialize_file(nil)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("file_path must be a string")
      
      -- Test with non-string file_path
      success, err = debug_hook.initialize_file(123)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("file_path must be a string")
      
      -- Test with empty string
      success, err = debug_hook.initialize_file("")
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("file_path cannot be empty")
      
      -- Test with valid file_path
      success = debug_hook.initialize_file("test_file.lua")
      expect(success).to.be_truthy()
    end)
    
    it("should handle duplicate initialization gracefully", function()
      -- Initialize a file
      local first_result = debug_hook.initialize_file("test_file.lua")
      expect(first_result).to.be_truthy()
      
      -- Initialize the same file again
      local second_result = debug_hook.initialize_file("test_file.lua")
      expect(second_result).to.be_truthy()
      
      -- File should exist in coverage data
      local coverage_data = debug_hook.get_coverage_data()
      expect(coverage_data.files["test_file.lua"]).to.exist()
    end)
  end)

  describe("track_line", function()
    it("should validate parameters", function()
      -- Test with nil file_path
      local success, err = debug_hook.track_line(nil, 1)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("file_path must be a string")
      
      -- Test with nil line_num
      success, err = debug_hook.track_line("test_file.lua", nil)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("line_num must be a number")
      
      -- Test with invalid line_num type
      success, err = debug_hook.track_line("test_file.lua", "not a number")
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("line_num must be a number")
      
      -- Test with negative line_num
      success, err = debug_hook.track_line("test_file.lua", -5)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("line_num must be a positive number")
      
      -- Test with valid parameters
      debug_hook.initialize_file("test_file.lua")
      success = debug_hook.track_line("test_file.lua", 1)
      expect(success).to.be_truthy()
    end)
    
    it("should handle uninitialized files", function()
      -- Track line for uninitialized file
      local success, err = debug_hook.track_line("uninitialized_file.lua", 1)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("File not initialized")
      
      -- Initialize the file and try again
      debug_hook.initialize_file("uninitialized_file.lua")
      success = debug_hook.track_line("uninitialized_file.lua", 1)
      expect(success).to.be_truthy()
    end)
    
    it("should handle invalid coverage data", function()
      -- Setup with valid file
      debug_hook.initialize_file("test_file.lua")
      
      -- Create a corrupted state by directly modifying coverage data
      local coverage_data = debug_hook.get_coverage_data()
      coverage_data.files["test_file.lua"] = "invalid data, not a table"
      
      -- Track line should handle the error
      local success, err = debug_hook.track_line("test_file.lua", 1)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.RUNTIME)
      expect(err.message).to.match("Invalid file data structure")
    end)
  end)

  describe("set_line_executable", function()
    it("should validate parameters", function()
      -- Test with nil file_path
      local success, err = debug_hook.set_line_executable(nil, 1, true)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("file_path must be a string")
      
      -- Test with nil line_num
      success, err = debug_hook.set_line_executable("test_file.lua", nil, true)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("line_num must be a number")
      
      -- Test with invalid executable type
      success, err = debug_hook.set_line_executable("test_file.lua", 1, "not a boolean")
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("executable must be a boolean")
      
      -- Test with valid parameters
      debug_hook.initialize_file("test_file.lua")
      success = debug_hook.set_line_executable("test_file.lua", 1, true)
      expect(success).to.be_truthy()
    end)
  end)

  describe("set_line_covered", function()
    it("should validate parameters", function()
      -- Test with nil file_path
      local success, err = debug_hook.set_line_covered(nil, 1, true)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("file_path must be a string")
      
      -- Test with nil line_num
      success, err = debug_hook.set_line_covered("test_file.lua", nil, true)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("line_num must be a number")
      
      -- Test with invalid covered type
      success, err = debug_hook.set_line_covered("test_file.lua", 1, "not a boolean")
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("covered must be a boolean")
      
      -- Test with valid parameters
      debug_hook.initialize_file("test_file.lua")
      success = debug_hook.set_line_covered("test_file.lua", 1, true)
      expect(success).to.be_truthy()
    end)
  end)

  describe("track_function", function()
    it("should validate parameters", function()
      -- Test with nil file_path
      local success, err = debug_hook.track_function(nil, 1, "test_function")
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("file_path must be a string")
      
      -- Test with nil line_num
      success, err = debug_hook.track_function("test_file.lua", nil, "test_function")
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("line_num must be a number")
      
      -- Test with invalid func_name type
      success, err = debug_hook.track_function("test_file.lua", 1, 123)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("func_name must be a string")
      
      -- Test with valid parameters
      debug_hook.initialize_file("test_file.lua")
      success = debug_hook.track_function("test_file.lua", 1, "test_function")
      expect(success).to.be_truthy()
    end)
  end)

  describe("track_block", function()
    it("should validate parameters", function()
      -- Test with nil file_path
      local success, err = debug_hook.track_block(nil, 1, "block1", "if")
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("file_path must be a string")
      
      -- Test with nil line_num
      success, err = debug_hook.track_block("test_file.lua", nil, "block1", "if")
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("line_num must be a number")
      
      -- Test with invalid block_id type
      success, err = debug_hook.track_block("test_file.lua", 1, 123, "if")
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("block_id must be a string")
      
      -- Test with invalid block_type
      success, err = debug_hook.track_block("test_file.lua", 1, "block1", 123)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("block_type must be a string")
      
      -- Test with valid parameters
      debug_hook.initialize_file("test_file.lua")
      success = debug_hook.track_block("test_file.lua", 1, "block1", "if")
      expect(success).to.be_truthy()
    end)
  end)

  describe("activate_file", function()
    it("should validate file_path parameter", function()
      -- Test with nil file_path
      local success, err = debug_hook.activate_file(nil)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("file_path must be a string")
      
      -- Test with valid file_path
      debug_hook.initialize_file("test_file.lua")
      success = debug_hook.activate_file("test_file.lua")
      expect(success).to.be_truthy()
      
      -- Verify file is active
      local active_files = debug_hook.get_active_files()
      expect(active_files["test_file.lua"]).to.be_truthy()
    end)
  end)

  describe("should_track_file", function()
    it("should handle nil or invalid file path", function()
      -- Test with nil file_path
      local result = debug_hook.should_track_file(nil)
      expect(result).to.equal(false)
      
      -- Test with number file_path
      result = debug_hook.should_track_file(123)
      expect(result).to.equal(false)
      
      -- Test with empty string
      result = debug_hook.should_track_file("")
      expect(result).to.equal(false)
    end)
    
    it("should apply include and exclude patterns", function()
      -- Set config with patterns
      debug_hook.set_config({
        include_patterns = {"test/.*%.lua$"},
        exclude_patterns = {"test/excluded/.*%.lua$"}
      })
      
      -- Test included file
      local result = debug_hook.should_track_file("test/file.lua")
      expect(result).to.equal(true)
      
      -- Test excluded file
      result = debug_hook.should_track_file("test/excluded/file.lua")
      expect(result).to.equal(false)
      
      -- Test non-matching file
      result = debug_hook.should_track_file("other/file.lua")
      expect(result).to.equal(false)
    end)
    
    it("should handle pattern errors gracefully", function()
      -- Set config with invalid pattern
      debug_hook.set_config({
        include_patterns = {"[invalid pattern"}
      })
      
      -- Should not crash but return false for safety
      local result = debug_hook.should_track_file("test/file.lua")
      expect(result).to.equal(false)
    end)
  end)
end)
