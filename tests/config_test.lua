-- Configuration Module Tests

local lust = require("lust-next")
local expect, describe, it, before, after = lust.expect, lust.describe, lust.it, lust.before, lust.after

describe("Configuration Module", function()
  local fs = require("lib.tools.filesystem")
  local config = require("lib.core.config")
  local coverage_module = require("lib.coverage")
  local temp_config_path = "/tmp/test-lust-next-config.lua"
  
  -- Clean up any test files before and after tests
  before(function()
    if fs.file_exists(temp_config_path) then
      fs.delete_file(temp_config_path)
    end
  end)
  
  after(function()
    if fs.file_exists(temp_config_path) then
      fs.delete_file(temp_config_path)
    end
  end)
  
  it("should have a default coverage threshold of 90%", function()
    -- Check the default configuration in the coverage module
    expect(coverage_module.config.threshold).to.equal(90)
    
    -- The above check confirms our configuration code has been applied properly
    -- and the default threshold is 90% as desired
  end)
  
  it("should apply configurations from a config file", function()
    -- Create a temporary config file
    local config_content = [[
    return {
      coverage = {
        threshold = 95,  -- Set threshold higher than default
        debug = false
      }
    }
    ]]
    
    -- Write the config file
    fs.write_file(temp_config_path, config_content)
    
    -- Load the config file
    local user_config = config.load_from_file(temp_config_path)
    
    -- Check that the config was loaded correctly
    expect(user_config).to.exist()
    expect(user_config.coverage).to.exist()
    expect(user_config.coverage.threshold).to.equal(95)
    
    -- Create a mock lust_next instance to apply config to
    local lust_next = {
      coverage_options = {
        threshold = 90  -- Default threshold we set
      }
    }
    
    -- Apply the config
    config.apply_to_lust(lust_next)
    
    -- Check that the threshold was updated
    expect(lust_next.coverage_options.threshold).to.equal(95)
  end)
  
  it("should handle non-existent config files gracefully", function()
    -- Try to load a non-existent config file
    local non_existent_path = "/tmp/non-existent-config.lua"
    local user_config, err = config.load_from_file(non_existent_path)
    
    -- Check that it returns nil and an appropriate error message
    expect(user_config).to.equal(nil)
    expect(err).to.match("Config file not found")
  end)
  
  it("should handle invalid config files gracefully", function()
    -- Create a temporary invalid config file (syntax error)
    local invalid_config_content = [[
    return {
      coverage = {
        threshold = 95,  -- Set threshold higher than default
        debug = false,
      } -- Missing closing brace
    ]]
    
    -- Write the config file
    fs.write_file(temp_config_path, invalid_config_content)
    
    -- Try to load the invalid config file
    local user_config, err = config.load_from_file(temp_config_path)
    
    -- Check that it returns nil and an appropriate error message
    expect(user_config).to.equal(nil)
    expect(err).to.match("Error loading config file")
  end)
  
  it("should apply multiple configuration options", function()
    -- Create a temporary config file with multiple options
    local config_content = [[
    return {
      coverage = {
        threshold = 95,
        debug = true
      },
      async = {
        timeout = 3000
      },
      format = {
        use_color = false
      }
    }
    ]]
    
    -- Write the config file
    fs.write_file(temp_config_path, config_content)
    
    -- Load the config file
    local user_config = config.load_from_file(temp_config_path)
    
    -- Create a mock lust_next instance with multiple option groups
    local lust_next = {
      coverage_options = {
        threshold = 90,
        debug = false
      },
      async_options = {
        timeout = 1000
      },
      format_options = {
        use_color = true
      }
    }
    
    -- Apply the config
    config.apply_to_lust(lust_next)
    
    -- Check that all configurations were applied correctly
    expect(lust_next.coverage_options.threshold).to.equal(95)
    expect(lust_next.coverage_options.debug).to.equal(true)
    expect(lust_next.async_options.timeout).to.equal(3000)
    expect(lust_next.format_options.use_color).to.equal(false)
  end)
  
  it("should register config with lust", function()
    -- Create a minimal mock lust instance
    local mock_lust = {}
    
    -- Register config module with mock lust
    config.register_with_lust(mock_lust)
    
    -- Check that the config module was properly registered
    expect(mock_lust.config).to.exist()
  end)
end)