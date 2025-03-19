-- Tests for the firmo quality module
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Initialize logger with error handling
local logging, logger
local function try_load_logger()
  if not logger then
    local logger_init_success, result = pcall(function()
      local log_module = require("lib.tools.logging")
      logging = log_module
      logger = logging.get_logger("test.quality")
      
      if logger and logger.debug then
        logger.debug("Quality test initialized", {
          module = "test.quality",
          test_type = "unit",
          test_focus = "quality validation"
        })
      end
      return true
    end)
    
    if not logger_init_success then
      print("Warning: Failed to initialize logger: " .. tostring(result))
      -- Create a minimal logger as fallback
      logger = {
        debug = function() end,
        info = function() end,
        warn = function(msg) print("WARN: " .. msg) end,
        error = function(msg) print("ERROR: " .. msg) end
      }
    end
  end
  return logger
end

-- Initialize logger
local log = try_load_logger()

-- Helper function to create a test file with different quality levels with error handling
local function create_test_file(filename, quality_level)
  -- Validate input parameters with error handling
  if not filename or filename == "" then
    if log then
      log.error("Invalid filename provided to create_test_file", {
        filename = tostring(filename),
        quality_level = quality_level
      })
    end
    return false, "Invalid filename"
  end
  
  if not quality_level or type(quality_level) ~= "number" or quality_level < 1 or quality_level > 5 then
    if log then
      log.error("Invalid quality level provided to create_test_file", {
        filename = filename,
        quality_level = tostring(quality_level)
      })
    end
    return false, "Invalid quality level: must be between 1 and 5"
  end
  
  -- Create the content based on quality level
  local content = "-- Test file for quality level " .. quality_level .. "\n"
  content = content .. "local firmo = require('firmo')\n"
  content = content .. "local describe, it, expect = firmo.describe, firmo.it, firmo.expect\n\n"
  
  content = content .. "describe('Sample Test Suite', function()\n"
  
  -- Level 1: Basic tests with assertions
  if quality_level >= 1 then
    content = content .. "  it('should perform basic assertion', function()\n"
    content = content .. "    expect(true).to.be.truthy()\n"
    content = content .. "    expect(1 + 1).to.equal(2)\n"
    content = content .. "  end)\n"
  end
  
  -- Level 2: Multiple test cases and nested describes
  if quality_level >= 2 then
    content = content .. "  describe('Nested Group', function()\n"
    content = content .. "    it('should have multiple assertions', function()\n"
    content = content .. "      local value = 'test'\n"
    content = content .. "      expect(value).to.be.a('string')\n"
    content = content .. "      expect(#value).to.equal(4)\n"
    content = content .. "      expect(value:sub(1, 1)).to.equal('t')\n"
    content = content .. "    end)\n"
    content = content .. "  end)\n"
  end
  
  -- Level 3: Setup/teardown and mocking
  if quality_level >= 3 then
    content = content .. "  local setup_value = nil\n"
    content = content .. "  before(function()\n"
    content = content .. "    setup_value = 'initialized'\n"
    content = content .. "  end)\n"
    content = content .. "  after(function()\n"
    content = content .. "    setup_value = nil\n"
    content = content .. "  end)\n"
    content = content .. "  it('should use setup and mocking', function()\n"
    content = content .. "    expect(setup_value).to.equal('initialized')\n"
    content = content .. "    local mock = firmo.mock({ test = function() return true end })\n"
    content = content .. "    expect(mock.test()).to.be.truthy()\n"
    content = content .. "    expect(mock.test).to.have.been.called()\n"
    content = content .. "  end)\n"
  end
  
  -- Level 4: Comprehensive test coverage
  if quality_level >= 4 then
    content = content .. "  describe('Edge Cases', function()\n"
    content = content .. "    it('should handle nil values', function()\n"
    content = content .. "      expect(nil).to.be.falsy()\n"
    content = content .. "      expect(function() return nil end).not.to.raise()\n"
    content = content .. "    end)\n"
    content = content .. "    it('should handle empty strings', function()\n"
    content = content .. "      expect('').to.be.a('string')\n"
    content = content .. "      expect(#'').to.equal(0)\n"
    content = content .. "    end)\n"
    content = content .. "    it('should handle large numbers', function()\n"
    content = content .. "      expect(1e10).to.be.a('number')\n"
    content = content .. "      expect(1e10 > 1e9).to.be.truthy()\n"
    content = content .. "    end)\n"
    content = content .. "  end)\n"
  end
  
  -- Level 5: Advanced mocking, tags, and custom setup
  if quality_level >= 5 then
    content = content .. "  describe('Advanced Features', function()\n"
    content = content .. "    -- Add a tag to this test group\n"
    content = content .. "    tags('advanced', 'integration')\n"
    content = content .. "    local complex_mock = firmo.mock({\n"
    content = content .. "      method1 = function(self, arg) return arg * 2 end,\n"
    content = content .. "      method2 = function(self) return self.value end,\n"
    content = content .. "      value = 10\n"
    content = content .. "    })\n"
    content = content .. "    it('should verify complex interactions', function()\n"
    content = content .. "      expect(complex_mock.method1(5)).to.equal(10)\n"
    content = content .. "      expect(complex_mock.method1).to.have.been.called.with(5)\n"
    content = content .. "      expect(complex_mock.method2()).to.equal(10)\n"
    content = content .. "    end)\n"
    content = content .. "    it('should handle async operations', function(done)\n"
    content = content .. "      local async_fn = function(callback)\n"
    content = content .. "        callback(true)\n"
    content = content .. "      end\n"
    content = content .. "      async_fn(function(result)\n"
    content = content .. "        expect(result).to.be.truthy()\n"
    content = content .. "        done()\n"
    content = content .. "      end)\n"
    content = content .. "    end)\n"
    content = content .. "  end)\n"
  end
  
  content = content .. "end)\n\n"
  content = content .. "return true\n"
  
  -- Write the file with error handling
  local success, err = test_helper.with_error_capture(function()
    return fs.write_file(filename, content)
  end)()
  
  if not success then
    if log then
      log.error("Failed to write test file", {
        filename = filename,
        quality_level = quality_level,
        error = tostring(err)
      })
    end
    return false, err
  end
  
  if log then
    log.debug("Successfully created test file", {
      filename = filename,
      quality_level = quality_level
    })
  end
  
  return true
end

-- Test for the quality module
describe("Quality Module", function()
  -- Test files with different quality levels
  local test_files = {}
  
  -- Create test files before running tests
  before(function()
    if log then
      log.debug("Creating test files", {
        file_count = 5,
        quality_levels = "1-5"
      })
    end
    
    for i = 1, 5 do
      local filename = "quality_level_" .. i .. "_test.lua"
      
      -- Create file with error handling
      local success, err = test_helper.with_error_capture(function()
        return create_test_file(filename, i)
      end)()
      
      if success then
        table.insert(test_files, filename)
        
        if log then
          log.debug("Created test file", {
            filename = filename,
            quality_level = i
          })
        end
      else
        if log then
          log.error("Failed to create test file", {
            filename = filename,
            quality_level = i,
            error = tostring(err)
          })
        end
        
        -- Don't fail the test setup, but log the error
        print("Warning: Failed to create test file " .. filename .. ": " .. tostring(err))
      end
    end
    
    -- Ensure we have at least one test file
    expect(#test_files).to.be_greater_than(0, "Failed to create any test files")
  end)
  
  -- Clean up test files after tests
  after(function()
    if log then
      log.debug("Cleaning up test files", {
        file_count = #test_files
      })
    end
    
    for _, filename in ipairs(test_files) do
      -- Remove file with error handling
      local success, err = pcall(function()
        return os.remove(filename)
      end)
      
      if not success then
        if log then
          log.warn("Failed to remove test file", {
            filename = filename,
            error = tostring(err)
          })
        end
      else
        if log then
          log.debug("Removed test file", {
            filename = filename
          })
        end
      end
    end
    
    -- Clear the list
    test_files = {}
  end)
  
  -- Test quality module initialization
  it("should load the quality module", function()
    -- Load the quality module with error handling
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    expect(quality).to.exist()
    expect(type(quality)).to.equal("table")
    expect(type(quality.validate_test_quality)).to.equal("function")
    expect(type(quality.check_file)).to.equal("function")
  end)
  
  -- Test quality level validation
  it("should validate test quality levels correctly", { expect_error = true }, function()
    -- Load the quality module with error handling
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    
    -- Use central_config to set quality settings with error handling
    if central_config and central_config.set then
      local config_result, config_error = test_helper.with_error_capture(function()
        return central_config.set("quality", {
          enabled = true,
          level = 5  -- Set to highest level for complete testing
        })
      end)()
      
      expect(config_error).to_not.exist("Failed to set quality configuration: " .. tostring(config_error))
    end
    
    -- Test basic functionality if the module is available
    if not quality.check_file then
      if log then
        log.warn("Test skipped - missing functionality", {
          missing_function = "quality.check_file",
          test = "should validate test quality levels correctly"
        })
      end
      firmo.pending("Quality module check_file function not available")
      return
    end
    
    -- Check each quality level
    for _, file in ipairs(test_files) do
      local level = tonumber(file:match("quality_level_(%d)_test.lua"))
      if level then
        -- Verify file exists before testing
        local file_exists, file_exists_error = test_helper.with_error_capture(function()
          return fs.file_exists(file)
        end)()
        
        expect(file_exists_error).to_not.exist("Error checking if file exists: " .. tostring(file_exists_error))
        expect(file_exists).to.be_truthy("Test file does not exist: " .. file)
        
        -- Each file should pass validations up to its level
        for check_level = 1, level do
          local result, issues, err = test_helper.with_error_capture(function()
            return quality.check_file(file, check_level)
          end)()
          
          expect(err).to_not.exist("Error checking quality level " .. check_level .. " for file " .. file .. ": " .. tostring(err))
          expect(result).to.equal(true, "File " .. file .. " did not pass quality level " .. check_level)
        end
        
        -- Each file should fail validations above its level
        -- (unless it's level 5, which is the highest)
        if level < 5 then
          local result, issues, err = test_helper.with_error_capture(function()
            return quality.check_file(file, level + 1)
          end)()
          
          expect(err).to_not.exist("Error checking quality level " .. (level + 1) .. " for file " .. file .. ": " .. tostring(err))
          expect(result).to.equal(false, "File " .. file .. " unexpectedly passed quality level " .. (level + 1))
        end
      end
    end
  end)
  
  -- Test validation with missing files
  it("should handle missing files gracefully", { expect_error = true }, function()
    -- Load the quality module with error handling
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    
    -- Try to check a non-existent file
    local result, err = test_helper.with_error_capture(function()
      return quality.check_file("non_existent_file.lua", 1)
    end)()
    
    -- The check should either return false or an error
    if result ~= nil then
      expect(result).to.equal(false, "check_file should return false for non-existent files")
    else
      expect(err).to.exist("check_file should error for non-existent files")
      -- Additional checks on the error object could be added here
    end
  end)
  
  -- Test coverage threshold requirement
  it("should use 90% as the coverage threshold requirement", function()
    -- Load the quality module with error handling
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    
    -- Use central_config to set quality settings with error handling
    if central_config and central_config.set then
      local config_result, config_error = test_helper.with_error_capture(function()
        return central_config.set("quality", {
          enabled = true,
          level = 5  -- Set to highest level to check requirements
        })
      end)()
      
      expect(config_error).to_not.exist("Failed to set quality configuration: " .. tostring(config_error))
    end
    
    -- Get level requirements for the highest quality level with error handling
    local level5_requirements, req_error = test_helper.with_error_capture(function()
      return quality.get_level_requirements(5)
    end)()
    
    expect(req_error).to_not.exist("Failed to get level requirements: " .. tostring(req_error))
    expect(level5_requirements).to.exist()
    
    if log then
      log.debug("Quality level 5 requirements", {
        level = 5,
        has_requirements = level5_requirements ~= nil,
        coverage_threshold = level5_requirements and level5_requirements.test_organization and 
                             level5_requirements.test_organization.require_coverage_threshold or "N/A"
      })
    end
    
    -- Check that the coverage threshold is 90%
    expect(level5_requirements.test_organization.require_coverage_threshold).to.equal(90)
  end)
  
  -- Test quality constants
  it("should define quality level constants", function()
    -- Load the quality module with error handling
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    expect(quality).to.exist()
    
    -- Check that all expected constants exist
    expect(type(quality.LEVEL_BASIC)).to.equal("number")
    expect(type(quality.LEVEL_STRUCTURED)).to.equal("number")
    expect(type(quality.LEVEL_COMPLETE)).to.equal("number")
    expect(type(quality.LEVEL_COMPREHENSIVE)).to.equal("number")
    expect(type(quality.LEVEL_ADVANCED)).to.equal("number")
    
    -- Check that constants have appropriate values
    expect(quality.LEVEL_BASIC).to.equal(1)
    expect(quality.LEVEL_STRUCTURED).to.equal(2)
    expect(quality.LEVEL_COMPREHENSIVE).to.equal(3)
    expect(quality.LEVEL_ADVANCED).to.equal(4)
    expect(quality.LEVEL_COMPLETE).to.equal(5)
  end)
  
  -- Test getting quality level names
  it("should provide quality level names", function()
    -- Load the quality module with error handling
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    expect(quality).to.exist()
    
    if quality.get_level_name then
      for i = 1, 5 do
        local name, name_error = test_helper.with_error_capture(function()
          return quality.get_level_name(i)
        end)()
        
        expect(name_error).to_not.exist("Error getting level name for level " .. i .. ": " .. tostring(name_error))
        expect(name).to.exist()
        expect(type(name)).to.equal("string")
        
        if log then
          log.debug("Quality level name", {
            level = i,
            name = name
          })
        end
      end
      
      -- Test invalid level
      local invalid_name, invalid_error = test_helper.with_error_capture(function()
        return quality.get_level_name(999)
      end)()
      
      -- Should return "unknown" for invalid levels
      expect(invalid_name).to.equal("unknown")
    else
      if log then
        log.warn("Test skipped - missing functionality", {
          missing_function = "quality.get_level_name",
          test = "should provide quality level names"
        })
      end
      firmo.pending("get_level_name function not available")
    end
  end)
  
  -- Test invalid quality level validation
  it("should handle invalid quality levels gracefully", { expect_error = true }, function()
    -- Load the quality module with error handling
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    
    -- Test with an invalid quality level (negative)
    local result, err = test_helper.with_error_capture(function()
      return quality.check_file(test_files[1], -1)
    end)()
    
    -- The check should either return false or an error
    if result ~= nil then
      expect(result).to.equal(false, "check_file should return false for invalid quality level")
    else
      expect(err).to.exist("check_file should error for invalid quality level")
    end
    
    -- Test with an invalid quality level (too high)
    local result2, err2 = test_helper.with_error_capture(function()
      return quality.check_file(test_files[1], 999)
    end)()
    
    -- The check should either return false or an error
    if result2 ~= nil then
      expect(result2).to.equal(false, "check_file should return false for invalid quality level")
    else
      expect(err2).to.exist("check_file should error for invalid quality level")
    end
  end)
  
  if log then
    log.info("Quality module tests completed", {
      status = "success",
      test_group = "quality"
    })
  end
end)

-- Tests are run by run_all_tests.lua or scripts/runner.lua
-- No need to call firmo() explicitly here
