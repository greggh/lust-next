-- Test for coverage module error handling
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

local fs = require("lib.tools.filesystem")
local coverage = require("lib.coverage")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local test_helper = require("lib.tools.test_helper")

-- Configure logging for testing - use FATAL level to reduce output
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

describe("Coverage Error Handling", function()
  -- Set up a clean test environment before each test
  before(function()
    coverage.reset()
    coverage.init({
      enabled = true,
      use_static_analysis = true,
      discover_uncovered = false,
      threshold = 0
    })
  end)

  -- Clean up after each test
  after(function()
    coverage.stop()
    coverage.reset()
  end)

  describe("process_module_structure", function()
    it("should handle missing file path", { expect_error = true }, function()
      local process_module_structure = coverage.process_module_structure
      local success, err = process_module_structure(nil)
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("must be provided")
    end)

    it("should handle non-existent file", { expect_error = true }, function()
      local process_module_structure = coverage.process_module_structure
      local success, err = process_module_structure("/path/to/nonexistent/file.lua")
      
      -- Process should fail but gracefully
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.IO)
    end)
  end)

  describe("init method", function()
    it("should validate options parameter", { expect_error = true }, function()
      -- Reset coverage first
      coverage.reset()
      
      -- Test with invalid options type
      local success, err = coverage.init("not a table")
      
      expect(success).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("Options must be a table or nil")
      
      -- Should still work with valid options after error
      success = coverage.init({enabled = true})
      expect(success).to.equal(coverage) -- Returns self on success
    end)
    
    it("should handle configuration errors gracefully", { expect_error = true }, function()
      -- Create a test case with invalid configuration
      local mock = require("lib.mocking.mock")
      
      -- Create a wrapper with error capture around mock.with_mocks
      test_helper.with_error_capture(function()
        -- Use mock.with_mocks to safely mock and restore functions
        return mock.with_mocks(function()
          -- Create a mock for central_config.get
          local central_config = require("lib.core.central_config")
          mock.mock(central_config, "get", function()
            return nil, error_handler.create("Test configuration error", error_handler.CATEGORY.CONFIGURATION)
          end)
          
          -- Reset coverage first
          coverage.reset()
          
          -- Initialize with configuration that will trigger central_config.get
          local success = coverage.init({enabled = true})
          
          -- Should not crash but still initialize with defaults
          expect(success).to.equal(coverage)
          expect(coverage.config.enabled).to.equal(true)
        end)
      end)()
    end)
  end)

  describe("start method", function()
    it("should handle instrumentation failures gracefully", { expect_error = true }, function()
      local mock = require("lib.mocking.mock")
      
      test_helper.with_error_capture(function()
        return mock.with_mocks(function()
          -- Configure with instrumentation mode
          coverage.reset()
          coverage.init({
            enabled = true,
            use_instrumentation = true,
            instrument_on_load = true
          })
          
          -- Start should succeed even if instrumentation has issues
          local result = coverage.start()
          expect(result).to.equal(coverage)
          
          -- We can't reliably test instrumentation_mode directly as it's not accessible
          -- Instead, let's check that it doesn't crash, which is the main purpose
        end)
      end)()
    end)
    
    it("should handle hook errors gracefully", { expect_error = true }, function()
      local mock = require("lib.mocking.mock")
      
      test_helper.with_error_capture(function()
        return mock.with_mocks(function()
          -- Mock debug.sethook to simulate an error
          mock.mock(debug, "sethook", function()
            error("Simulated sethook error")
          end)
          
          -- Start should handle the error
          coverage.reset()
          coverage.init({enabled = true, use_instrumentation = false})
          
          local success, err = coverage.start()
          expect(success).to_not.exist()
          expect(err).to.exist()
          expect(err.category).to.equal(error_handler.CATEGORY.RUNTIME)
          expect(err.message).to.match("Failed to start coverage")
        end)
      end)()
      
      -- Cleanup
      coverage.reset()
    end)
  end)

  describe("stop method", function()
    it("should handle hook restoration errors gracefully", { expect_error = true }, function()
      local mock = require("lib.mocking.mock")
      
      test_helper.with_error_capture(function()
        return mock.with_mocks(function()
          -- Start coverage normally
          coverage.start()
          
          -- Mock debug.sethook to simulate an error
          mock.mock(debug, "sethook", function()
            error("Simulated sethook error")
          end)
          
          -- Stop should handle the error gracefully
          local result = coverage.stop()
          expect(result).to.equal(coverage)
        end)
      end)()
    end)
    
    it("should handle data processing errors gracefully", { expect_error = true }, function()
      local mock = require("lib.mocking.mock")
      
      test_helper.with_error_capture(function()
        return mock.with_mocks(function()
          -- Start coverage normally
          coverage.start()
          
          -- Get local reference to patchup
          local patchup = require("lib.coverage.patchup")
          
          -- Mock patch_all function
          mock.mock(patchup, "patch_all", function()
            error("Simulated patch_all error")
          end)
          
          -- Stop should handle the error gracefully
          local result = coverage.stop()
          expect(result).to.equal(coverage)
        end)
      end)()
    end)
  end)
  
  describe("get_report_data method", function()
    it("should handle file processing errors gracefully", { expect_error = true }, function()
      local mock = require("lib.mocking.mock")
      
      test_helper.with_error_capture(function()
        return mock.with_mocks(function()
          -- Start coverage and track a file
          coverage.start()
          
          -- Track some coverage data
          local test_file = "test_file.lua"
          coverage.track_line(test_file, 1)
          coverage.track_line(test_file, 2)
          
          -- Mock any function that might cause an error
          local debug_hook = require("lib.coverage.debug_hook")
          mock.mock(debug_hook, "get_active_files", function()
            error("Simulated get_active_files error")
          end)
          
          -- get_report_data should handle the error gracefully
          local result = coverage.get_report_data()
          expect(result).to.be.a("table")
          expect(result.summary).to.be.a("table")
        end)
      end)()
      
      -- Cleanup
      coverage.stop()
    end)
  end)
end)
