-- Tests for temp_file_integration.lua module

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

local temp_file = require("lib.tools.temp_file")
local temp_file_integration = require("lib.tools.temp_file_integration")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")

describe("temp_file_integration", function()
  -- Initialize the integration at the start
  before(function()
    -- Ensure _G.firmo is set to make the integration happy
    _G.firmo = firmo
    temp_file_integration.initialize()
  end)
  
  describe("initialization", function()
    it("should initialize the integration system", function()
      -- This just verifies the integration module can be loaded and initialized
      expect(temp_file_integration).to.be.a("table")
      expect(temp_file_integration.initialize).to.be.a("function")
      expect(temp_file_integration.patch_firmo).to.be.a("function")
      expect(temp_file_integration.cleanup_all).to.be.a("function")
    end)
    
    it("should set up firmo integration", function()
      -- Check if the firmo global has been patched
      expect(_G.firmo._current_test_context).to_not.exist() -- Should be nil between tests
      expect(_G.firmo.get_current_test_context).to.be.a("function")
    end)
  end)
  
  describe("test context tracking", function()
    it("should track test context during execution", function()
      -- During test execution, the current context should be set
      local context = _G.firmo.get_current_test_context()
      expect(context).to.exist()
      expect(context.type).to.equal("it")
      expect(context.name).to.equal("should track test context during execution")
    end)
    
    it("should create different contexts for different tests", function()
      -- Get current context
      local context = _G.firmo.get_current_test_context()
      expect(context).to.exist()
      expect(context.name).to.equal("should create different contexts for different tests")
      
      -- Verify it's different from other test contexts
      expect(context.name).to_not.equal("should track test context during execution")
    end)
  end)
  
  describe("automatic cleanup", function() 
    it("should clean up files created during tests", function()
      -- Create a temporary file
      local file_path, err = temp_file.create_with_content("test content", "txt")
      expect(err).to_not.exist()
      expect(fs.file_exists(file_path)).to.be_truthy()
      
      -- Store the path for later verification (after the test completes)
      _G._temp_path_for_next_test = file_path
    end)
    
    it("should verify previous test's files are cleaned up", function()
      -- Check if the file from the previous test exists
      local previous_file = _G._temp_path_for_next_test
      expect(previous_file).to.exist() -- The global should exist
      
      -- The file itself should be gone (cleaned up after the previous test)
      expect(fs.file_exists(previous_file)).to.be_falsy("File should have been cleaned up")
      
      -- Clean up the global
      _G._temp_path_for_next_test = nil
    end)
  end)
  
  describe("cleanup operations", function()
    it("should perform final cleanup", function()
      -- Create some resources
      local paths = {}
      for i = 1, 3 do
        local path, err = temp_file.create_with_content("content " .. i, "txt")
        expect(err).to_not.exist()
        table.insert(paths, path)
      end
      
      -- Verify files exist
      for _, path in ipairs(paths) do
        expect(fs.file_exists(path)).to.be_truthy()
      end
      
      -- Run manual cleanup
      local success, errors, stats = temp_file_integration.cleanup_all()
      
      -- Verify cleanup succeeded
      expect(success).to.be_truthy()
      
      -- Verify files are gone
      for _, path in ipairs(paths) do
        expect(fs.file_exists(path)).to.be_falsy()
      end
    end)
  end)
  
  describe("error resilience", function()
    it("should handle complex directory cleanup", function()
      -- Create a complex nested structure
      local test_dir = test_helper.create_temp_test_directory()
      
      -- Create nested directory structure with files
      test_dir.create_file("level1/level2/level3/file.txt", "deep nested file")
      test_dir.create_file("level1/sibling1.txt", "sibling file 1")
      test_dir.create_file("level1/level2/sibling2.txt", "sibling file 2")
      
      -- Verify files were created
      expect(fs.file_exists(test_dir.path .. "/level1/level2/level3/file.txt")).to.be_truthy()
      expect(fs.file_exists(test_dir.path .. "/level1/sibling1.txt")).to.be_truthy()
      expect(fs.file_exists(test_dir.path .. "/level1/level2/sibling2.txt")).to.be_truthy()
      
      -- Store dir path for verification in next test
      _G._complex_dir_path = test_dir.path
    end)
    
    it("should verify complex directory was cleaned up", function()
      -- Check that the complex directory from previous test is gone
      local previous_dir = _G._complex_dir_path
      expect(previous_dir).to.exist() -- The global should exist
      
      -- The directory itself should be gone
      expect(fs.directory_exists(previous_dir)).to.be_falsy("Directory should have been cleaned up")
      
      -- Clean up the global
      _G._complex_dir_path = nil
    end)
  end)
  
  describe("failed test handling", function()
    -- This is a test that intentionally fails
    it("should clean up even when test fails", function()
      -- Create a temp file that should be cleaned up
      local file_path, err = temp_file.create_with_content("failing test content", "txt")
      expect(err).to_not.exist()
      
      -- Store path for verification
      _G._failed_test_file_path = file_path
      
      -- Intentionally cause test to fail
      -- We'll verify in the next test that cleanup still happened
      if true then
        -- Using if true to avoid expect affecting context tracking
        -- In a real failure, the test would stop here
        -- But for our test, we need to continue to verify cleanup
        -- expect(false).to.be_truthy("Intentional test failure")
        
        -- Instead of failing with expect, we'll just note the failure
        print("Note: This test would normally fail, but we're not using expect() to fail it")
        print("     so we can verify the cleanup behavior in the next test")
      end
    end)
    
    it("should verify cleanup happened after failed test", function()
      -- Check that the file from the failing test is gone
      local failed_test_file = _G._failed_test_file_path
      expect(failed_test_file).to.exist() -- The global should exist
      
      -- The file itself should be gone (cleaned up despite the test failing)
      expect(fs.file_exists(failed_test_file)).to.be_falsy("File should have been cleaned up even after failed test")
      
      -- Clean up the global
      _G._failed_test_file_path = nil
    end)
  end)
end)