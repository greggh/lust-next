-- Tests for the async testing functionality
package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect
local it_async = lust_next.it_async
local async = lust_next.async
local await = lust_next.await
local wait_until = lust_next.wait_until

describe("Asynchronous Testing", function()
  -- Verify basic async functionality
  describe("async() function", function()
    it("wraps a function for async execution", function()
      local fn = function() return "test" end
      local wrapped = async(fn)
      
      expect(wrapped).to.be.a("function")
      local executor = wrapped()
      expect(executor).to.be.a("function")
    end)
    
    it("preserves function arguments", function()
      local args_received = nil
      
      local fn = function(a, b, c)
        args_received = {a, b, c}
        return args_received
      end
      
      local result = async(fn)(1, 2, 3)()
      expect(args_received[1]).to.equal(1)
      expect(args_received[2]).to.equal(2)
      expect(args_received[3]).to.equal(3)
    end)
  end)
  
  -- Test await functionality
  describe("await() function", function()
    it_async("waits for the specified time", function()
      local start = os.clock()
      
      await(50) -- Wait 50ms
      
      local elapsed = (os.clock() - start) * 1000
      expect(elapsed >= 40).to.be.truthy() -- Allow for small timing differences
    end)
    
    it("fails when used outside async context", function()
      expect(function()
        await(10)
      end).to.fail.with("can only be called within an async test")
    end)
  end)
  
  -- Test wait_until functionality
  describe("wait_until() function", function()
    it_async("waits until condition is true", function()
      local value = 0
      local start_time = os.clock() * 1000
      
      -- Create a condition function that becomes true after 30ms
      local function condition()
        if os.clock() * 1000 - start_time >= 30 then
          value = 42
          return true
        end
        return false
      end
      
      wait_until(condition, 200, 5)
      
      expect(value).to.equal(42)
    end)
    
    it_async("times out if condition never becomes true", function()
      local success = pcall(function()
        wait_until(function() return false end, 50, 5)
      end)
      
      expect(success).to.equal(false)
    end)
    
    it("fails when used outside async context", function()
      expect(function()
        wait_until(function() return true end)
      end).to.fail.with("can only be called within an async test")
    end)
  end)
  
  -- Test the async/await pattern for assertions
  describe("Async assertions", function()
    it_async("can make assertions after async operations", function()
      local result = nil
      
      -- Simulate async operation
      local start_time = os.clock() * 1000
      local function operation_complete()
        if os.clock() * 1000 - start_time >= 20 then
          result = "completed"
          return true
        end
        return false
      end
      
      -- Wait for operation to complete
      wait_until(operation_complete, 100)
      
      -- Assertions after the async operation
      expect(result).to.equal("completed")
    end)
  end)
  
  -- Test it_async convenience function
  describe("it_async() function", function()
    it("is a shorthand for it() with async()", function()
      -- This test verifies that it_async exists and calls the right functions
      -- The actual async functionality is tested in other tests
      expect(lust_next.it_async).to.be.a("function")
    end)
  end)
end)