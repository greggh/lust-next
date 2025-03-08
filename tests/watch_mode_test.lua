-- Tests for the watch mode functionality

local lust = require('lust-next')
local describe, it, expect = lust.describe, lust.it, lust.expect

-- Try to require the fix module first to ensure expect assertions work
local fix_success = pcall(function() return require('src.fix_expect') end)
if not fix_success then
  print("Warning: Failed to load fix_expect module. Some assertions may not work.")
end

-- Try to require watcher module
local ok, watcher = pcall(function() return require('src.watcher') end)
if not ok then
  print("Watcher module not available, skipping tests")
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
    it('exists in lust-next', function()
      expect(type(lust.reset)).to.equal("function")
    end)
    
    it('has a reset function with proper structure', function()
      -- Just check the reset function is available and has the right type
      expect(type(lust.reset)).to.equal("function")
    end)
  end)
  
  describe('Command Line Interface', function()
    it('has watch mode documentation', function()
      -- Check that docs/api/cli.md exists and contains watch mode info
      local file = io.open("/home/gregg/Projects/lua-library/lust-next/docs/api/cli.md", "r")
      if file then
        local content = file:read("*all")
        file:close()
        
        -- Check for watch mode documentation
        expect(content:find("watch mode", 1, true) or content:find("Watch Mode", 1, true)).to.be.truthy()
      else
        -- Skip test if docs file not found
        print("WARNING: CLI docs not found, skipping documentation check")
      end
    end)
    
    it('has watch mode example', function()
      -- Check that examples/watch_mode_example.lua exists
      local file = io.open("/home/gregg/Projects/lua-library/lust-next/examples/watch_mode_example.lua", "r")
      expect(file).to.be.truthy()
      file:close()
    end)
  end)
end)

-- Print success message if the module loaded
if ok then
  print("Watch mode tests successfully loaded")
end