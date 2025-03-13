-- Tests for the lust-next quality module
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local before, after = lust.before, lust.after
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")

-- Try to load the logging module
local logging, logger
local function try_load_logger()
  if not logger then
    local ok, log_module = pcall(require, "lib.tools.logging")
    if ok and log_module then
      logging = log_module
      logger = logging.get_logger("test.quality")
      
      if logger and logger.debug then
        logger.debug("Quality test initialized", {
          module = "test.quality",
          test_type = "unit",
          test_focus = "quality validation"
        })
      end
    end
  end
  return logger
end

-- Initialize logger
local log = try_load_logger()

-- Helper function to create a test file with different quality levels
local function create_test_file(filename, quality_level)
  local content = "-- Test file for quality level " .. quality_level .. "\n"
  content = content .. "local lust = require('lust-next')\n"
  content = content .. "local describe, it, expect = lust.describe, lust.it, lust.expect\n\n"
  
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
    content = content .. "    local mock = lust.mock({ test = function() return true end })\n"
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
    content = content .. "    local complex_mock = lust.mock({\n"
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
  
  local success, err = fs.write_file(filename, content)
  if success then
    return true
  end
  print("Failed to write test file: " .. (err or "unknown error"))
  return false
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
      if create_test_file(filename, i) then
        table.insert(test_files, filename)
        
        if log then
          log.debug("Created test file", {
            filename = filename,
            quality_level = i
          })
        end
      end
    end
  end)
  
  -- Clean up test files after tests
  after(function()
    if log then
      log.debug("Cleaning up test files", {
        file_count = #test_files
      })
    end
    
    for _, filename in ipairs(test_files) do
      os.remove(filename)
      
      if log then
        log.debug("Removed test file", {
          filename = filename
        })
      end
    end
  end)
  
  -- Test quality module initialization
  it("should load the quality module", function()
    local quality = require("lib.quality")
    expect(type(quality)).to.equal("table")
    expect(type(quality.validate_test_quality)).to.equal("function")
    expect(type(quality.check_file)).to.equal("function")
  end)
  
  -- Test quality level validation
  it("should validate test quality levels correctly", function()
    local quality = require("lib.quality")
    
    -- Use central_config to set quality settings
    if central_config and central_config.set then
      central_config.set("quality", {
        enabled = true,
        level = 5  -- Set to highest level for complete testing
      })
    end
    
    -- Test basic functionality if the module is available
    if not quality.check_file then
      if log then
        log.warn("Test skipped - missing functionality", {
          missing_function = "quality.check_file",
          test = "should validate test quality levels correctly"
        })
      end
      lust.pending("Quality module check_file function not available")
      return
    end
    
    -- Check each quality level
    for _, file in ipairs(test_files) do
      local level = tonumber(file:match("quality_level_(%d)_test.lua"))
      if level then
        -- Each file should pass validations up to its level
        for check_level = 1, level do
          local result, issues = quality.check_file(file, check_level)
          expect(result).to.equal(true)
        end
        
        -- Each file should fail validations above its level
        -- (unless it's level 5, which is the highest)
        if level < 5 then
          local result, issues = quality.check_file(file, level + 1)
          expect(result).to.equal(false)
        end
      end
    end
  end)
  
  -- Test coverage threshold requirement
  it("should use 90% as the coverage threshold requirement", function()
    local quality = require("lib.quality")
    
    -- Use central_config to set quality settings
    if central_config and central_config.set then
      central_config.set("quality", {
        enabled = true,
        level = 5  -- Set to highest level to check requirements
      })
    end
    
    -- Get level requirements for the highest quality level
    local level5_requirements = quality.get_level_requirements(5)
    
    if log then
      log.debug("Quality level 5 requirements", {
        level = 5,
        has_requirements = level5_requirements ~= nil,
        coverage_threshold = level5_requirements and level5_requirements.test_organization.require_coverage_threshold or "N/A"
      })
    end
    
    -- Check that the coverage threshold is 90%
    expect(level5_requirements.test_organization.require_coverage_threshold).to.equal(90)
  end)
  
  -- Test quality constants
  it("should define quality level constants", function()
    local quality = require("lib.quality")
    
    expect(type(quality.LEVEL_BASIC)).to.equal("number")
    expect(type(quality.LEVEL_STRUCTURED)).to.equal("number")
    expect(type(quality.LEVEL_COMPLETE)).to.equal("number")
    expect(type(quality.LEVEL_COMPREHENSIVE)).to.equal("number")
    expect(type(quality.LEVEL_ADVANCED)).to.equal("number")
  end)
  
  -- Test getting quality level names
  it("should provide quality level names", function()
    local quality = require("lib.quality")
    
    if quality.get_level_name then
      for i = 1, 5 do
        local name = quality.get_level_name(i)
        expect(type(name)).to.equal("string")
        
        if log then
          log.debug("Quality level name", {
            level = i,
            name = name
          })
        end
      end
    else
      if log then
        log.warn("Test skipped - missing functionality", {
          missing_function = "quality.get_level_name",
          test = "should provide quality level names"
        })
      end
      lust.pending("get_level_name function not available")
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
-- No need to call lust() explicitly here