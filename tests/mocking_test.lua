-- Tests for the mocking functionality
package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect
local mock, spy, stub, with_mocks = lust_next.mock, lust_next.spy, lust_next.stub, lust_next.with_mocks

describe("Mocking System", function()
  
  -- Test object to use in tests
  local test_obj = {
    count = 0,
    
    increment = function(self, amount)
      self.count = self.count + (amount or 1)
      return self.count
    end,
    
    reset = function(self)
      self.count = 0
    end,
    
    get_count = function(self)
      return self.count
    end
  }
  
  -- Clean up test object between tests
  lust_next.before(function()
    test_obj.count = 0
  end)
  
  -- Enhanced spy tests
  describe("Enhanced Spy", function()
    it("tracks function calls", function()
      local fn = function(a, b) return a + b end
      local spy_fn = spy(fn)
      
      spy_fn(2, 3)
      spy_fn(5, 6)
      
      expect(spy_fn.called).to.be.truthy()
      expect(spy_fn.call_count).to.equal(2)
    end)
    
    it("preserves arguments and return values", function()
      local fn = function(a, b) return a + b end
      local spy_fn = spy(fn)
      
      local result1 = spy_fn(2, 3)
      local result2 = spy_fn(5, 6)
      
      expect(result1).to.equal(5)
      expect(result2).to.equal(11)
      
      expect(spy_fn.calls[1][1]).to.equal(2)
      expect(spy_fn.calls[1][2]).to.equal(3)
      expect(spy_fn.calls[2][1]).to.equal(5)
      expect(spy_fn.calls[2][2]).to.equal(6)
    end)
    
    it("can spy on object methods", function()
      local method_spy = spy(test_obj, "increment")
      
      test_obj:increment()
      test_obj:increment(5)
      
      expect(method_spy.call_count).to.equal(2)
      expect(test_obj.count).to.equal(6)
      
      method_spy:restore()
    end)
    
    it("can check for specific arguments", function()
      local fn = spy(function() end)
      
      fn("test", 123, {key = "value"})
      
      expect(fn:called_with("test")).to.be.truthy()
      expect(fn:called_with("test", 123)).to.be.truthy()
      expect(fn:called_with("wrong")).to.equal(false)
    end)
    
    it("has call count verification helpers", function()
      local fn = spy(function() end)
      
      expect(fn:not_called()).to.be.truthy()
      
      fn()
      expect(fn:called_once()).to.be.truthy()
      expect(fn:called_times(1)).to.be.truthy()
      
      fn()
      expect(fn:called_times(2)).to.be.truthy()
      expect(fn:not_called()).to.equal(false)
      expect(fn:called_once()).to.equal(false)
    end)
    
    it("can get the last call details", function()
      local fn = spy(function() end)
      
      fn("first", 1)
      fn("second", 2)
      
      local last_call = fn:last_call()
      expect(last_call[1]).to.equal("second")
      expect(last_call[2]).to.equal(2)
    end)
    
    it("restores original functionality", function()
      local original_fn = test_obj.increment
      local method_spy = spy(test_obj, "increment")
      
      test_obj:increment()
      expect(test_obj.count).to.equal(1)
      
      method_spy:restore()
      expect(test_obj.increment).to.equal(original_fn)
    end)
  end)
  
  -- Mock object tests
  describe("Mock Object", function()
    it("can stub object methods", function()
      local test_mock = mock(test_obj)
      
      test_mock:stub("get_count", function() return 42 end)
      
      expect(test_obj:get_count()).to.equal(42)
      test_mock:restore()
    end)
    
    it("can stub with simple return values", function()
      local test_mock = mock(test_obj)
      
      test_mock:stub("get_count", 100)
      
      expect(test_obj:get_count()).to.equal(100)
      test_mock:restore()
    end)
    
    it("tracks stubbed method calls", function()
      local test_mock = mock(test_obj)
      
      test_mock:stub("increment", function() return 42 end)
      
      test_obj:increment()
      test_obj:increment(5)
      
      expect(test_mock._stubs.increment.call_count).to.equal(2)
      expect(test_mock._stubs.increment:called_with(test_obj)).to.be.truthy()
      expect(test_mock._stubs.increment:called_with(test_obj, 5)).to.be.truthy()
      
      test_mock:restore()
    end)
    
    it("can restore individual stubs", function()
      local test_mock = mock(test_obj)
      
      test_mock:stub("increment", function() return 100 end)
      test_mock:stub("get_count", function() return 200 end)
      
      expect(test_obj:increment()).to.equal(100)
      expect(test_obj:get_count()).to.equal(200)
      
      test_mock:restore_stub("increment")
      
      -- increment should be restored, get_count still stubbed
      test_obj:increment()
      expect(test_obj.count).to.equal(1)
      expect(test_obj:get_count()).to.equal(200)
      
      test_mock:restore()
    end)
    
    it("can restore all stubs", function()
      local test_mock = mock(test_obj)
      
      test_mock:stub("increment", function() return 100 end)
      test_mock:stub("get_count", function() return 200 end)
      
      test_mock:restore()
      
      -- Both methods should be restored
      test_obj:increment()
      expect(test_obj.count).to.equal(1)
      expect(test_obj:get_count()).to.equal(1)
    end)
    
    it("can verify all methods were called", function()
      local test_mock = mock(test_obj)
      
      test_mock:stub("increment", function() return 100 end)
      test_mock:stub("get_count", function() return 200 end)
      
      -- Call only one of the stubbed methods
      test_obj:increment()
      
      -- Verification should fail because get_count wasn't called
      local success = pcall(function()
        test_mock:verify()
      end)
      
      expect(success).to.equal(false)
      test_mock:restore()
    end)
  end)
  
  -- Standalone stub tests
  describe("Standalone Stub", function()
    it("creates simple value stubs", function()
      local config_stub = stub({version = "1.0", debug = true})
      
      local result = config_stub()
      
      expect(result.version).to.equal("1.0")
      expect(result.debug).to.equal(true)
      expect(config_stub.called).to.be.truthy()
    end)
    
    it("creates function stubs", function()
      local calculate_stub = stub(function(a, b) 
        return a * b 
      end)
      
      expect(calculate_stub(5, 6)).to.equal(30)
      expect(calculate_stub.call_count).to.equal(1)
      expect(calculate_stub:called_with(5, 6)).to.be.truthy()
    end)
  end)
  
  -- with_mocks context manager tests
  describe("with_mocks Context Manager", function()
    it("provides a scoped mock context", function()
      local original_increment = test_obj.increment
      
      with_mocks(function(create_mock)
        local test_mock = create_mock(test_obj)
        test_mock:stub("increment", function() return 42 end)
        
        expect(test_obj:increment()).to.equal(42)
      end)
      
      -- Should be restored after the context
      expect(test_obj.increment).to.equal(original_increment)
    end)
    
    it("restores mocks even if an error occurs", function()
      local original_increment = test_obj.increment
      
      -- This should throw an error, but mocks should still be restored
      pcall(function()
        with_mocks(function(create_mock)
          local test_mock = create_mock(test_obj)
          test_mock:stub("increment", function() return 42 end)
          
          error("Test error")
        end)
      end)
      
      -- Should be restored despite the error
      expect(test_obj.increment).to.equal(original_increment)
    end)
  end)
  
  -- Integration test
  describe("Complete Mocking System Integration", function()
    it("allows full mocking and verification workflow", function()
      -- Create a more complex test object
      local api = {
        settings = { debug = false },
        
        init = function(self, config)
          self.settings = config or self.settings
          return true
        end,
        
        fetch_data = function(self, id)
          -- In a real API, this would do a network request
          return { id = id, name = "Data_" .. id }
        end,
        
        process = function(self, data)
          if not data or not data.id then
            error("Invalid data")
          end
          return "Processed_" .. data.id
        end
      }
      
      -- Service using the API
      local service = {
        get_processed_data = function(id)
          local data = api:fetch_data(id)
          return api:process(data)
        end
      }
      
      -- Now test service using mocks
      with_mocks(function(create_mock)
        local api_mock = create_mock(api)
        
        -- Stub API methods
        api_mock:stub("fetch_data", function(self, id)
          expect(id).to.equal(123)
          return { id = id, name = "Mocked_" .. id }
        end)
        
        api_mock:stub("process", function(self, data)
          expect(data.id).to.equal(123)
          expect(data.name).to.equal("Mocked_123")
          return "Mocked_Process_Result"
        end)
        
        -- Call the service
        local result = service.get_processed_data(123)
        
        -- Verify result
        expect(result).to.equal("Mocked_Process_Result")
        
        -- Verify API call expectations
        expect(api_mock._stubs.fetch_data:called_once()).to.be.truthy()
        expect(api_mock._stubs.process:called_once()).to.be.truthy()
        
        -- Verify call sequence and arguments
        expect(api_mock._stubs.fetch_data:called_with(api, 123)).to.be.truthy()
        
        -- The process method should have been called with the mock data
        local process_call = api_mock._stubs.process:last_call()
        expect(process_call[2].id).to.equal(123)
        expect(process_call[2].name).to.equal("Mocked_123")
        
        -- Final verification
        api_mock:verify()
      end)
    end)
  end)
end)