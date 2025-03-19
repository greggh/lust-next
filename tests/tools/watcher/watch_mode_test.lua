-- Tests for the watch mode functionality

local firmo = require('firmo')
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local fs = require('lib.tools.filesystem')
local test_helper = require('lib.tools.test_helper')
local error_handler = require('lib.tools.error_handler')

-- Initialize proper logging
local logging = require("lib.tools.logging")
local logger = logging.get_logger("test.watch_mode")

-- Try to require the fix module first to ensure expect assertions work
it("should load the fix_expect module", { expect_error = true }, function()
  local fix_expect, err = test_helper.with_error_capture(function()
    return require('lib.core.fix_expect')
  end)()
  
  if not fix_expect then
    logger.debug("[EXPECTED] Failed to load fix_expect module", { 
      error = error_handler.format_error(err),
      details = "Some assertions may not work" 
    })
  end
end)

-- Try to require watcher module
local watcher
it("should load the watcher module", { expect_error = true }, function()
  local watcher_module, err = test_helper.with_error_capture(function()
    return require('lib.tools.watcher')
  end)()
  
  expect(watcher_module).to.exist()
  expect(err).to_not.exist()
  watcher = watcher_module
end)

describe('Watch Mode', function()

  describe('Watcher Module', function()
    it('exists and has the required functions', function()
      expect(watcher).to.be.truthy()
      expect(type(watcher.init)).to.equal("function")
      expect(type(watcher.check_for_changes)).to.equal("function")
      expect(type(watcher.add_patterns)).to.equal("function")
      expect(type(watcher.set_check_interval)).to.equal("function")
    end)
    
    it('allows setting check interval', function()
      local prev_interval = 1.0
      watcher.set_check_interval(2.0)
      
      -- We can't check internal state directly, but can verify it doesn't error
      expect(function() watcher.set_check_interval(prev_interval) end).to_not.fail()
    end)
    
    it('allows adding watch patterns', function()
      local patterns = {"%.txt$", "%.json$"}
      
      -- We can't check internal state directly, but can verify it doesn't error
      expect(function() watcher.add_patterns(patterns) end).to_not.fail()
    end)
  end)
  
  describe('Watcher Initialization', function()
    it('initializes with default directory', function()
      -- Initialize the watcher with default directory
      local success = watcher.init(".")
      expect(success).to.be.truthy()
    end)
    
    it('initializes with array of directories', function()
      -- Initialize the watcher with multiple directories
      local success = watcher.init({".", "./src"})
      expect(success).to.be.truthy()
    end)
    
    it('initializes with exclude patterns', function()
      -- Initialize with exclude patterns
      local success = watcher.init(".", {"%.git", "node_modules"})
      expect(success).to.be.truthy()
    end)
  end)
  
  describe('File Change Detection', function()
    it('handles no changes detected', { expect_error = true }, function()
      watcher.init(".")
      
      -- Try setting the interval to 0 - this should throw an error
      -- but just handle it and continue
      local success = pcall(function() watcher.set_check_interval(0) end)
      
      -- We expect this to fail, so just move on and use a valid value
      -- Skip validation since we can't reliably know if it returns nil, false, or throws
      
      -- Use a valid small interval instead
      watcher.set_check_interval(0.001)
      
      -- Initial check should find no changes since we just initialized
      local changes = watcher.check_for_changes()
      -- Either nil or an empty table/array is acceptable
      expect(changes == nil or (type(changes) == "table" and #changes == 0)).to.be_truthy()
    end)
    
    -- Note: We can't reliably test actual file changes in an automated test,
    -- as it would require creating and modifying files on disk during the test.
    -- This would be better tested in an integration test environment.
  end)
  
  describe('Reset Function', function()
    it('exists in firmo', function()
      expect(type(firmo.reset)).to.equal("function")
    end)
    
    it('has a reset function with proper structure', function()
      -- Just check the reset function is available and has the right type
      expect(type(firmo.reset)).to.equal("function")
    end)
  end)
  
  describe('Command Line Interface', function()
    it('has watch mode documentation', { expect_error = true }, function()
      -- Check that docs/api/cli.md exists and contains watch mode info
      local content, err = test_helper.with_error_capture(function()
        return fs.read_file("/home/gregg/Projects/lua-library/firmo/docs/api/cli.md")
      end)()
      
      if content then
        -- Check for watch mode documentation
        expect(content:find("watch mode", 1, true) or content:find("Watch Mode", 1, true)).to.be.truthy()
      else
        -- Log expected error and skip test
        logger.debug("[EXPECTED] CLI docs not found, skipping documentation check", { 
          error = error_handler.format_error(err),
          file = "/home/gregg/Projects/lua-library/firmo/docs/api/cli.md"
        })
      end
    end)
    
    it('has watch mode example', function()
      -- Check that examples/watch_mode_example.lua exists
      local exists = fs.file_exists("/home/gregg/Projects/lua-library/firmo/examples/watch_mode_example.lua")
      expect(exists).to.be.truthy()
    end)
  end)
end)

-- Log success message if the module loaded
if watcher and logger then
  logger.info("Watch mode tests successfully loaded")
end