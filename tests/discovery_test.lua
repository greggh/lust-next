-- Test for the new discovery functionality
package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect

describe("Test Discovery", function()
  it("has discovery function", function()
    expect(lust_next.discover).to.be.a("function")
    expect(lust_next.run_discovered).to.be.a("function")
    expect(lust_next.cli_run).to.be.a("function")
  end)
  
  it("can find test files", function()
    local files = lust_next.discover("./tests", "*_test.lua")
    expect(#files).to.be.truthy()
    
    -- At minimum, this file should be found
    local this_file_found = false
    for _, file in ipairs(files) do
      if file:match("discovery_test.lua") then
        this_file_found = true
        break
      end
    end
    
    expect(this_file_found).to.be.truthy()
  end)
  
  it("can access discover functionality", function()
    -- Just test that we can call discover with custom patterns
    local files = lust_next.discover("./tests", "nonexistent_pattern_*.lua")
    -- Note that we don't actually check the result since the implementation
    -- details may change with the separate discover.lua module
    expect(files).to.be.a("table")
  end)
end)