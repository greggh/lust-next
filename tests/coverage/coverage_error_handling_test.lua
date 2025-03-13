-- Test for coverage module error handling
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local before, after = lust.before, lust.after

local fs = require("lib.tools.filesystem")
local coverage = require("lib.coverage")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

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
    it("should handle missing file path", function()
      local process_module_structure = coverage.process_module_structure
      local success, err = process_module_structure(nil)
      
      expect(success).to.equal(nil)
      expect(err).to.be.a("table")
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("must be provided")
    end)

    it("should handle non-existent file", function()
      local process_module_structure = coverage.process_module_structure
      local success, err = process_module_structure("/path/to/nonexistent/file.lua")
      
      -- Process should fail but gracefully
      expect(success).to.equal(nil)
      expect(err).to.be.a("table")
      expect(err.category).to.equal(error_handler.CATEGORY.IO)
    end)
  end)

  describe("init method", function()
    it("should validate options parameter", function()
      -- Reset coverage first
      coverage.reset()
      
      -- Test with invalid options type
      local success, err = coverage.init("not a table")
      
      expect(success).to.equal(nil)
      expect(err).to.be.a("table")
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("Options must be a table or nil")
      
      -- Should still work with valid options after error
      success = coverage.init({enabled = true})
      expect(success).to.equal(coverage) -- Returns self on success
    end)
    
    it("should handle configuration errors gracefully", function()
      -- Create a test case with invalid configuration
      local central_config = require("lib.core.central_config")
      
      -- Save original get function to restore later
      local original_get = central_config.get
      
      -- Mock central_config.get to throw an error
      central_config.get = function()
        error("Simulated configuration error")
      end
      
      -- Reset coverage first
      coverage.reset()
      
      -- Initialize with configuration that will trigger central_config.get
      local success = coverage.init({enabled = true})
      
      -- Should not crash but still initialize with defaults
      expect(success).to.equal(coverage)
      expect(coverage.config.enabled).to.equal(true)
      
      -- Restore original function
      central_config.get = original_get
    end)
  end)

  describe("start method", function()
    it("should handle instrumentation failures gracefully", function()
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
    
    it("should handle hook errors gracefully", function()
      -- Original implementation to restore later
      local original_gethook = debug.gethook
      local original_sethook = debug.sethook
      
      -- Replace debug.sethook to simulate an error
      debug.sethook = function()
        error("Simulated sethook error")
      end
      
      -- Start should handle the error
      coverage.reset()
      coverage.init({enabled = true, use_instrumentation = false})
      
      local success, err = coverage.start()
      expect(success).to.equal(nil)
      expect(err).to.be.a("table")
      expect(err.category).to.equal(error_handler.CATEGORY.RUNTIME)
      expect(err.message).to.match("Failed to start coverage")
      
      -- Restore original functions
      debug.gethook = original_gethook
      debug.sethook = original_sethook
      
      -- Cleanup
      coverage.reset()
    end)
  end)

  describe("stop method", function()
    it("should handle hook restoration errors gracefully", function()
      -- Start coverage normally
      coverage.start()
      
      -- Original implementation to restore later
      local original_sethook = debug.sethook
      
      -- Replace debug.sethook to simulate an error
      debug.sethook = function()
        error("Simulated sethook error")
      end
      
      -- Stop should handle the error gracefully
      local result = coverage.stop()
      expect(result).to.equal(coverage)
      
      -- Restore original function
      debug.sethook = original_sethook
    end)
    
    it("should handle data processing errors gracefully", function()
      -- Start coverage normally
      coverage.start()
      
      -- Get local reference to patchup
      local patchup = require("lib.coverage.patchup")
      
      -- Save original patch_all function
      local original_patch_all = patchup.patch_all
      
      -- Replace with function that throws an error
      patchup.patch_all = function()
        error("Simulated patch_all error")
      end
      
      -- Stop should handle the error gracefully
      local result = coverage.stop()
      expect(result).to.equal(coverage)
      
      -- Restore original function
      patchup.patch_all = original_patch_all
    end)
  end)
  
  describe("get_report_data method", function()
    it("should handle file processing errors gracefully", function()
      -- Start coverage and track a file
      coverage.start()
      
      -- Track some coverage data
      local test_file = "test_file.lua"
      coverage.track_line(test_file, 1)
      coverage.track_line(test_file, 2)
      
      -- Original implementation to restore later
      local original_is_comment_line = coverage.is_comment_line
      
      -- Replace is_comment_line to simulate an error
      coverage.is_comment_line = function()
        error("Simulated is_comment_line error")
      end
      
      -- get_report_data should handle the error gracefully
      local result = coverage.get_report_data()
      expect(result).to.be.a("table")
      expect(result.summary).to.be.a("table")
      
      -- Restore original function
      coverage.is_comment_line = original_is_comment_line
      
      -- Cleanup
      coverage.stop()
    end)
  end)
end)