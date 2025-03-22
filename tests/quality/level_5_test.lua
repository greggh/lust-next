-- Test file for quality level 5
---@type Firmo
local firmo = require('firmo')
---@type fun(description: string, callback: function) describe Test suite container function
---@type fun(description: string, options: table|nil, callback: function) it Test case function with optional parameters
---@type fun(value: any) expect Assertion generator function
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
---@type fun(callback: function) before Setup function that runs before each test
---@type fun(callback: function) after Teardown function that runs after each test
local before, after = firmo.before, firmo.after
---@type fun(...:string):nil tags Function to tag test suites or test cases
local tags = firmo.tags

-- Import all needed test functionality
---@type TestHelperModule
local test_helper = require("lib.tools.test_helper")

describe('Sample Test Suite', function()
  it('should perform basic assertion', function()
    expect(true).to.be.truthy()
    expect(1 + 1).to.equal(2)
  end)
  describe('Nested Group', function()
    it('should have multiple assertions', function()
      local value = 'test'
      expect(value).to.be.a('string')
      expect(#value).to.equal(4)
      expect(value:sub(1, 1)).to.equal('t')
    end)
  end)
  local setup_value = nil
  before(function()
    setup_value = 'initialized'
  end)
  after(function()
    setup_value = nil
  end)
  it('should use setup and teardown', function()
    expect(setup_value).to.equal('initialized')
    -- We verify that setup ran properly and after will run to clean up
  end)
  describe('Edge Cases', function()
    it('should handle nil values', function()
      expect(nil).to.be.falsy()
      -- Test a function returning nil
      local fn = function() return nil end
      expect(fn()).to.equal(nil)
    end)
    it('should handle empty strings', function()
      expect('').to.be.a('string')
      expect(#'').to.equal(0)
    end)
    it('should handle large numbers', function()
      expect(1e10).to.be.a('number')
      expect(1e10 > 1e9).to.be.truthy()
    end)
  end)
  describe('Advanced Features', function()
    -- Add a tag to this test group
    tags('advanced', 'integration')
    
    it('should support tagging feature', function()
      -- The presence of tags on this block is sufficient to test the tagging feature
      expect(true).to.be.truthy()
    end)
    
    it('should verify complex assertions', function()
      -- Complex assertions about tables
      local data = {
        name = "Test", 
        items = {1, 2, 3},
        metadata = {
          version = 1.0,
          author = "Tester"
        }
      }
      
      expect(data).to.be.a("table")
      expect(data.name).to.equal("Test") 
      expect(#data.items).to.equal(3)
      expect(data.metadata.version).to.equal(1.0)
    end)
  end)
end)

return true