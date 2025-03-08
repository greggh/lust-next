-- Comprehensive tests for the expect assertion system

local lust = require('lust-next')
local describe, it, expect = lust.describe, lust.it, lust.expect

describe('Expect Assertion System', function()
  describe('Basic Assertions', function()
    it('checks for equality', function()
      expect(5).to.equal(5)
      expect("hello").to.equal("hello")
      expect(true).to.equal(true)
      expect({a = 1, b = 2}).to.equal({a = 1, b = 2})
    end)
    
    it('compares values with be', function()
      expect(5).to.be(5)
      expect("hello").to.be("hello")
      expect(true).to.be(true)
    end)
    
    it('checks for existence', function()
      expect(5).to.exist()
      expect("hello").to.exist()
      expect(true).to.exist()
      expect({}).to.exist()
    end)
    
    it('checks for truthiness', function()
      expect(5).to.be.truthy()
      expect("hello").to.be.truthy()
      expect(true).to.be.truthy()
      expect({}).to.be.truthy()
    end)
    
    it('checks for falsiness', function()
      expect(nil).to.be.falsey()
      expect(false).to.be.falsey()
    end)
  end)
  
  describe('Negative Assertions', function()
    it('checks for inequality', function()
      expect(5).to_not.equal(6)
      expect("hello").to_not.equal("world")
      expect(true).to_not.equal(false)
      expect({a = 1}).to_not.equal({a = 2})
    end)
    
    it('compares values with to_not.be', function()
      expect(5).to_not.be(6)
      expect("hello").to_not.be("world")
      expect(true).to_not.be(false)
    end)
    
    it('checks for non-existence', function()
      expect(nil).to_not.exist()
      expect(false).to.exist() -- false exists, it's not nil
    end)
    
    it('checks for non-truthiness', function()
      expect(nil).to_not.be.truthy()
      expect(false).to_not.be.truthy()
    end)
    
    it('checks for non-falsiness', function()
      expect(5).to_not.be.falsey()
      expect("hello").to_not.be.falsey()
      expect(true).to_not.be.falsey()
      expect({}).to_not.be.falsey()
    end)
  end)
  
  describe('Function Testing', function()
    it('checks for function failure', function()
      local function fails() error("This function fails") end
      expect(fails).to.fail()
    end)
    
    it('checks for function success', function()
      local function succeeds() return true end
      expect(succeeds).to_not.fail()
    end)
    
    it('checks for error message', function()
      local function fails_with_message() error("Expected message") end
      expect(fails_with_message).to.fail.with("Expected message")
    end)
  end)
  
  describe('Table Assertions', function()
    it('checks for value in table', function()
      local t = {1, 2, 3, "hello"}
      expect(t).to.have(1)
      expect(t).to.have(2)
      expect(t).to.have("hello")
    end)
    
    it('checks for absence of value in table', function()
      local t = {1, 2, 3}
      expect(t).to_not.have(4)
      expect(t).to_not.have("hello")
    end)
  end)
  
  describe('Additional Assertions', function()
    it('checks string matching', function()
      expect("hello world").to.match("world")
      expect("hello world").to_not.match("universe")
    end)
    
    it('checks for type', function()
      expect(5).to.be.a("number")
      expect("hello").to.be.a("string")
      expect(true).to.be.a("boolean")
      expect({}).to.be.a("table")
      expect(function() end).to.be.a("function")
    end)
  end)
  
  describe('Reset Function', function()
    it('allows chaining syntax', function()
      -- Create a local function to avoid affecting main tests
      local function test_reset_chaining()
        -- If we get to here without errors, it means reset() supports chaining
        -- since reset() is called in the chain below
        lust.reset().describe('test', function() end)
        return true
      end
      
      -- If test_reset_chaining succeeds, this will pass
      expect(test_reset_chaining()).to.be.truthy()
    end)
    
    it('has important API functions', function()
      -- Just check that the main API functions exist and are proper types
      expect(type(lust.reset)).to.equal("function")
      expect(type(lust.describe)).to.equal("function")
      expect(type(lust.it)).to.equal("function")
      expect(type(lust.expect)).to.equal("function")
    end)
  end)
end)

print("Expect assertion tests completed successfully!")