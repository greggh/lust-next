-- Tests for coverage/init.lua error handling
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local before, after = lust.before, lust.after

-- Core dependencies
local fs = require("lib.tools.filesystem")
local coverage = require("lib.coverage")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

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

describe("Coverage Init Module Error Handling", function()
  -- Set up a clean test environment before each test
  before(function()
    coverage.full_reset()
  end)

  -- Clean up after each test
  after(function()
    coverage.stop()
    coverage.full_reset()
  end)

  describe("init", function()
    it("should validate options parameter type", function()
      -- Test with invalid options type (string)
      local result, err = coverage.init("not a table")
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("Options must be a table or nil")
      expect(err.context.provided_type).to.equal("string")
      
      -- Test with invalid options type (number)
      result, err = coverage.init(123)
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("Options must be a table or nil")
      expect(err.context.provided_type).to.equal("number")
      
      -- Test with valid options
      result = coverage.init({enabled = true})
      expect(result).to.equal(coverage) -- Returns self on success
    end)
    
    it("should handle errors in debug_hook configuration", function()
      -- Save original debug_hook.set_config method
      local debug_hook = require("lib.coverage.debug_hook")
      local original_set_config = debug_hook.set_config
      
      -- Replace with function that throws an error
      debug_hook.set_config = function()
        error("Simulated debug_hook.set_config error")
      end
      
      -- Test init with the mocked debug_hook
      local result, err = coverage.init({enabled = true})
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.RUNTIME)
      expect(err.message).to.match("Failed to configure debug hook")
      
      -- Restore original function
      debug_hook.set_config = original_set_config
    end)
    
    it("should handle errors in static analyzer initialization", function()
      -- Force loading of static_analyzer first
      local static_analyzer = require("lib.coverage.static_analyzer")
      local original_init = static_analyzer.init
      
      -- Replace with function that throws an error
      static_analyzer.init = function()
        error("Simulated static_analyzer.init error")
      end
      
      -- Test init with the mocked static_analyzer
      local result = coverage.init({
        enabled = true,
        use_static_analysis = true
      })
      
      -- Should still succeed but show a warning
      expect(result).to.equal(coverage)
      
      -- Restore original function
      static_analyzer.init = original_init
    end)
  end)
  
  describe("start", function()
    it("should do nothing when coverage is disabled", function()
      -- Initialize with coverage disabled
      coverage.init({enabled = false})
      
      -- Start should succeed but not activate
      local result = coverage.start()
      expect(result).to.equal(coverage)
      
      -- Verify we didn't set a debug hook
      local hook, mask, count = debug.gethook()
      expect(hook).to_not.exist()
    end)
    
    it("should handle instrumentation module loading errors", function()
      -- Prepare package.loaded to force error when loading instrumentation
      local original_loaded = package.loaded["lib.coverage.instrumentation"]
      package.loaded["lib.coverage.instrumentation"] = nil
      
      -- Modify package.loaders to simulate loading error
      local original_loaders = package.loaders or package.searchers
      local temp_loaders = {}
      for i, loader in ipairs(original_loaders) do
        temp_loaders[i] = loader
      end
      
      -- Add a loader that triggers an error for our module
      table.insert(temp_loaders, 1, function(modname)
        if modname == "lib.coverage.instrumentation" then
          error("Simulated module loading error")
        end
      end)
      
      if package.loaders then
        package.loaders = temp_loaders
      else
        package.searchers = temp_loaders
      end
      
      -- Initialize with instrumentation enabled
      coverage.init({
        enabled = true,
        use_instrumentation = true
      })
      
      -- Start should succeed but fall back to debug hook approach
      local result = coverage.start()
      expect(result).to.equal(coverage)
      
      -- Restore original state
      package.loaded["lib.coverage.instrumentation"] = original_loaded
      if package.loaders then
        package.loaders = original_loaders
      else
        package.searchers = original_loaders
      end
    end)
    
    it("should handle instrumentation config errors", function()
      -- Load instrumentation module directly
      local instrumentation = require("lib.coverage.instrumentation")
      local original_set_config = instrumentation.set_config
      
      -- Replace with function that throws an error
      instrumentation.set_config = function()
        error("Simulated instrumentation.set_config error")
      end
      
      -- Initialize with instrumentation enabled
      coverage.init({
        enabled = true,
        use_instrumentation = true
      })
      
      -- Start should succeed but fall back to debug hook approach
      local result = coverage.start()
      expect(result).to.equal(coverage)
      
      -- Restore original function
      instrumentation.set_config = original_set_config
    end)
    
    it("should handle debug hook setup errors", function()
      -- Save original debug.sethook function
      local original_sethook = debug.sethook
      
      -- Replace with function that throws an error
      debug.sethook = function()
        error("Simulated debug.sethook error")
      end
      
      -- Initialize with debug hook approach
      coverage.init({
        enabled = true,
        use_instrumentation = false
      })
      
      -- Start should fail with error
      local result, err = coverage.start()
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.RUNTIME)
      expect(err.message).to.match("Failed to start coverage")
      
      -- Restore original function
      debug.sethook = original_sethook
    end)
  end)
  
  describe("stop", function()
    it("should do nothing when coverage is not active", function()
      -- Reset coverage to ensure it's not active
      coverage.full_reset()
      coverage.init({enabled = true})
      
      -- Should return self without error
      local result = coverage.stop()
      expect(result).to.equal(coverage)
    end)
    
    it("should handle hook restoration errors", function()
      -- Start coverage normally
      coverage.init({enabled = true})
      coverage.start()
      
      -- Replace debug.sethook to simulate an error
      local original_sethook = debug.sethook
      debug.sethook = function()
        error("Simulated debug.sethook error during stop")
      end
      
      -- Stop should handle the error gracefully
      local result = coverage.stop()
      expect(result).to.equal(coverage)
      
      -- Restore original function
      debug.sethook = original_sethook
    end)
    
    it("should handle patchup errors during stop", function()
      -- Start coverage normally
      coverage.init({enabled = true})
      coverage.start()
      
      -- Get patchup module
      local patchup = require("lib.coverage.patchup")
      local original_patch_all = patchup.patch_all
      
      -- Replace with function that throws an error
      patchup.patch_all = function()
        error("Simulated patchup.patch_all error")
      end
      
      -- Stop should handle the error gracefully
      local result = coverage.stop()
      expect(result).to.equal(coverage)
      
      -- Restore original function
      patchup.patch_all = original_patch_all
    end)
  end)
  
  describe("track_file", function()
    it("should do nothing when coverage is disabled", function()
      -- Initialize with coverage disabled
      coverage.init({enabled = false})
      
      -- Function should return without error
      local result = coverage.track_file("test_file.lua")
      expect(result).to_not.exist()
    end)
    
    it("should normalize file paths", function()
      -- Initialize and start coverage
      coverage.init({enabled = true})
      coverage.start()
      
      -- Track file with non-normalized path
      local result = coverage.track_file("./test//file.lua")
      
      -- Function should normalize path internally
      local debug_hook = require("lib.coverage.debug_hook")
      local coverage_data = debug_hook.get_coverage_data()
      
      -- Check that the file is tracked with normalized path
      expect(coverage_data.files["./test/file.lua"]).to.exist()
    end)
    
    it("should handle file read errors", function()
      -- Initialize and start coverage
      coverage.init({enabled = true})
      coverage.start()
      
      -- Save original fs.read_file
      local original_read_file = fs.read_file
      
      -- Replace with function that throws an error
      fs.read_file = function()
        return nil, "Simulated file read error"
      end
      
      -- Track non-existent file
      local result = coverage.track_file("non_existent_file.lua")
      expect(result).to.equal(false)
      
      -- Restore original function
      fs.read_file = original_read_file
    end)
  end)
  
  describe("track_line", function()
    it("should do nothing when coverage is disabled", function()
      -- Initialize with coverage disabled
      coverage.init({enabled = false})
      
      -- Function should return without error
      local result = coverage.track_line("test_file.lua", 10)
      expect(result).to_not.exist()
    end)
    
    it("should normalize file paths", function()
      -- Initialize and start coverage
      coverage.init({enabled = true})
      coverage.start()
      
      -- Track line with non-normalized path
      coverage.track_line("./test//file.lua", 10)
      
      -- Function should normalize path internally
      local debug_hook = require("lib.coverage.debug_hook")
      local coverage_data = debug_hook.get_coverage_data()
      
      -- Check that the file is tracked with normalized path
      expect(coverage_data.files["./test/file.lua"]).to.exist()
    end)
    
    it("should handle file initialization automatically", function()
      -- Initialize and start coverage
      coverage.init({enabled = true})
      coverage.start()
      
      -- Track line in a file that hasn't been initialized yet
      coverage.track_line("auto_init_file.lua", 10)
      
      -- Function should initialize the file
      local debug_hook = require("lib.coverage.debug_hook")
      local coverage_data = debug_hook.get_coverage_data()
      
      -- Check that the file exists in coverage data
      expect(coverage_data.files["auto_init_file.lua"]).to.exist()
    end)
    
    it("should handle file content loading errors", function()
      -- Initialize and start coverage
      coverage.init({enabled = true})
      coverage.start()
      
      -- Save original fs.read_file
      local original_read_file = fs.read_file
      
      -- Replace with function that throws an error
      fs.read_file = function()
        error("Simulated file read error")
      end
      
      -- Track line should handle the error gracefully
      coverage.track_line("error_file.lua", 10)
      
      -- Function should still initialize the file
      local debug_hook = require("lib.coverage.debug_hook")
      local coverage_data = debug_hook.get_coverage_data()
      
      -- Check that the file exists in coverage data
      expect(coverage_data.files["error_file.lua"]).to.exist()
      
      -- Restore original function
      fs.read_file = original_read_file
    end)
  end)
  
  describe("get_report_data", function()
    it("should handle empty coverage data gracefully", function()
      -- Initialize without starting coverage
      coverage.init({enabled = true})
      
      -- Get report data
      local report_data = coverage.get_report_data()
      
      -- Should return a valid structure even with no data
      expect(report_data).to.be.a("table")
      expect(report_data.files).to.be.a("table")
      expect(report_data.summary).to.be.a("table")
      expect(report_data.summary.total_files).to.equal(0)
    end)
    
    it("should handle errors during data processing", function()
      -- Initialize and start coverage
      coverage.init({enabled = true})
      coverage.start()
      
      -- Track a file to ensure there's some data
      coverage.track_file("test_file.lua")
      
      -- Get debug_hook module
      local debug_hook = require("lib.coverage.debug_hook")
      local original_get_coverage_data = debug_hook.get_coverage_data
      
      -- Replace with function that throws an error
      debug_hook.get_coverage_data = function()
        error("Simulated get_coverage_data error")
      end
      
      -- Get report data should handle the error gracefully
      local report_data = coverage.get_report_data()
      
      -- Should return a valid empty structure
      expect(report_data).to.be.a("table")
      expect(report_data.files).to.be.a("table")
      expect(report_data.summary).to.be.a("table")
      expect(report_data.summary.total_files).to.equal(0)
      
      -- Restore original function
      debug_hook.get_coverage_data = original_get_coverage_data
    end)
    
    it("should handle errors in file data processing", function()
      -- Initialize and start coverage
      coverage.init({enabled = true})
      coverage.start()
      
      -- Track a file
      coverage.track_file("test_file.lua")
      
      -- Get debug_hook module
      local debug_hook = require("lib.coverage.debug_hook")
      local original_get_active_files = debug_hook.get_active_files
      
      -- Replace with function that throws an error
      debug_hook.get_active_files = function()
        error("Simulated get_active_files error")
      end
      
      -- Get report data should handle the error gracefully
      local report_data = coverage.get_report_data()
      
      -- Should return data even with the error
      expect(report_data).to.be.a("table")
      expect(report_data.files).to.be.a("table")
      
      -- Restore original function
      debug_hook.get_active_files = original_get_active_files
    end)
  end)
  
  describe("reset and full_reset", function()
    it("should handle reset errors gracefully", function()
      -- Initialize and start coverage
      coverage.init({enabled = true})
      coverage.start()
      
      -- Get debug_hook module
      local debug_hook = require("lib.coverage.debug_hook")
      local original_reset = debug_hook.reset
      
      -- Replace with function that throws an error
      debug_hook.reset = function()
        error("Simulated reset error")
      end
      
      -- Reset should handle the error gracefully
      local result = coverage.reset()
      expect(result).to.equal(coverage)
      
      -- Full reset should also handle the error
      result = coverage.full_reset()
      expect(result).to.equal(coverage)
      
      -- Restore original function
      debug_hook.reset = original_reset
    end)
  end)
end)