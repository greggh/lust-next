-- Configuration Module Tests

local lust = require("lust-next")
local expect, describe, it = lust.expect, lust.describe, lust.it

describe("Configuration Module", function()
  local fs = require("lib.tools.filesystem")
  local config = require("lib.core.config")
  local coverage_module = require("lib.coverage")
  
  it("should have a default coverage threshold of 90%", function()
    -- Check the default configuration in the coverage module
    expect(coverage_module.config.threshold).to.equal(90)
  end)
  
  it("should apply configurations from a config file", function()
    -- Create a temporary config file
    local temp_config_path = "/tmp/test-lust-next-config.lua"
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
    
    -- Clean up
    fs.delete_file(temp_config_path)
  end)
end)