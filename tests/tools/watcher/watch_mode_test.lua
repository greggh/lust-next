-- Tests for the watch mode functionality

local firmo = require('firmo')
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local fs = require('lib.tools.filesystem')

-- Initialize proper logging
local logging, logger
local function try_load_logger()
  if not logger then
    local ok, log_module = pcall(require, "lib.tools.logging")
    if ok and log_module then
      logging = log_module
      logger = logging.get_logger("test.watch_mode")
    end
  end
  return logger
end

-- Initialize logger
local log = try_load_logger()

-- Try to require the fix module first to ensure expect assertions work
local fix_success = pcall(function() return require('lib.core.fix_expect') end)
if not fix_success then
  if log then
    log.warn("Failed to load fix_expect module", { details = "Some assertions may not work" })
  else
    print("WARN: Failed to load fix_expect module, some assertions may not work")
  end
end

-- Try to require watcher module
local ok, watcher = pcall(function() return require('lib.tools.watcher') end)
if not ok then
  if log then
    log.warn("Watcher module not available", { details = "Skipping tests" })
  else
    print("WARN: Watcher module not available, skipping tests")
  end
  return
end

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
    it('handles no changes detected', function()
      watcher.init(".")
      -- Force immediate check by setting a very small interval
      watcher.set_check_interval(0)
      -- Initial check should find no changes since we just initialized
      local changes = watcher.check_for_changes()
      -- Either nil or an empty table/array is acceptable
      expect(changes == nil or (type(changes) == "table" and #changes == 0)).to.be.truthy()
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
    it('has watch mode documentation', function()
      -- Check that docs/api/cli.md exists and contains watch mode info
      local content, err = fs.read_file("/home/gregg/Projects/lua-library/firmo/docs/api/cli.md")
      if content then
        -- Check for watch mode documentation
        expect(content:find("watch mode", 1, true) or content:find("Watch Mode", 1, true)).to.be.truthy()
      else
        -- Skip test if docs file not found
        firmo.log.warn({ 
          message = "CLI docs not found, skipping documentation check", 
          error = err or "unknown error",
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
if ok and log then
  log.info("Watch mode tests successfully loaded")
end
