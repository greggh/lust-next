-- Tests for the mocking functionality
package.path = "../?.lua;../lib/?.lua;../lib/?/init.lua;" .. package.path

-- Load firmo, which already has the mocking system loaded
local firmo = require("firmo")

-- Get direct access to the mocking library for testing
local mocking = require("lib.mocking")

local describe, it, expect, pending = firmo.describe, firmo.it, firmo.expect, firmo.pending

-- Import spy functionality
local spy_module = firmo.spy
local spy_on = spy_module.on
local spy_new = spy_module.new
local mock = firmo.mock
local stub = firmo.stub
local with_mocks = firmo.with_mocks

describe("Mocking System", function()
  
  describe("Enhanced Spy", function()
    it("tracks function calls", function()
      local fn = function() end
      local spy = spy_new(fn)
      
      spy()
      spy()
      
      expect(spy.called).to.be_truthy()
      expect(spy.call_count).to.equal(2)
      expect(#spy.calls).to.equal(2)
    end)
    
    it("preserves arguments and return values", function()
      local fn = function(a, b) return a + b end
      local spy = spy_new(fn)
      
      local result = spy(5, 3)
      
      expect(result).to.equal(8)
      expect(spy.calls[1][1]).to.equal(5)
      expect(spy.calls[1][2]).to.equal(3)
    end)
    
    it("can spy on object methods", function()
      local obj = {
        add = function(self, a, b) return a + b end
      }
      
      local spy = spy_on(obj, "add")
      
      local result = obj.add(nil, 7, 2)
      
      expect(result).to.equal(9)
      expect(spy.called).to.be_truthy()
      expect(spy.calls[1][2]).to.equal(7)
      expect(spy.calls[1][3]).to.equal(2)
    end)
    
    it("can check for specific arguments", function()
      local fn = function() end
      local spy = spy_new(fn)
      
      spy("hello", 42, true)
      spy("world", 1, false)
      
      expect(spy.called_with("hello", 42, true)).to.be_truthy()
      expect(spy.called_with("world", 1, false)).to.be_truthy()
      expect(spy.called_with("wrongarg")).to.equal(false)
    end)
    
    it("has call count verification helpers", function()
      local fn = function() end
      local spy = spy_new(fn)
      
      expect(spy.not_called()).to.be_truthy()
      
      spy()
      expect(spy.called_once()).to.be_truthy()
      expect(spy.called_times(1)).to.be_truthy()
      
      spy()
      expect(spy.called_times(2)).to.be_truthy()
      expect(spy.called_once()).to.equal(false)
    end)
    
    it("can get the last call details", function()
      local fn = function() end
      local spy = spy_new(fn)
      
      spy("first call")
      spy("second call", "extra arg")
      
      local last = spy.last_call()
      expect(last[1]).to.equal("second call")
      expect(last[2]).to.equal("extra arg")
    end)
    
    it("tracks call sequence for ordering checks", function()
      local spy1 = spy_new()
      local spy2 = spy_new()
      
      spy1()
      spy2()
      
      expect(spy1.called_before(spy2)).to.be_truthy()
      expect(spy2.called_after(spy1)).to.be_truthy()
    end)
    
    it("restores original functionality", function()
      local obj = {
        method = function() return "original" end
      }
      
      local spy = spy_on(obj, "method")
      expect(obj.method()).to.equal("original")
      
      spy:restore()
      
      -- After restoration, the spy isn't capturing calls anymore
      obj.method()
      expect(spy.call_count).to.equal(1) -- Should still be 1 from before restore
    end)
  end)
  
  describe("Mock Object", function()
    it("can stub object methods", function()
      -- Create a test object with methods
      local test_obj = {
        getData = function()
          -- Imagine this hits a database
          return {"real", "data"}
        end
      }
      
      -- Create a mock that replaces the getData method
      local mock_obj = mock(test_obj, "getData", function()
        return {"mock", "data"}
      end)
      
      -- Call the method
      local result = test_obj:getData()
      
      -- Verify the mock implementation was used
      expect(result[1]).to.equal("mock")
      expect(result[2]).to.equal("data")
      
      -- Clean up
      mock_obj:restore()
    end)
    
    it("can stub with simple return values", function()
      -- Create a test object with methods
      local test_obj = {
        isConnected = function()
          -- Imagine this checks actual connection
          return false
        end
      }
      
      -- Create a mock with a simple return value (not a function)
      local mock_obj = mock(test_obj, "isConnected", true)
      
      -- Call the method
      local result = test_obj:isConnected()
      
      -- Verify the mocked return value was used
      expect(result).to.be_truthy()
      
      -- Clean up
      mock_obj:restore()
    end)
    
    it("tracks stubbed method calls", function()
      -- Create a test object
      local test_obj = {
        getData = function() return "real_data" end
      }
      
      -- Create a mock and stub a method
      local mock_obj = mock(test_obj)
      mock_obj:stub("getData", function() return "mock_data" end)
      
      -- Call the method
      local result = test_obj.getData()
      
      -- Verify the stub was called and call is tracked
      expect(result).to.equal("mock_data")
      expect(mock_obj._stubs.getData.called).to.be_truthy()
      expect(mock_obj._stubs.getData.call_count).to.equal(1)
    end)
    
    it("can set expectations on a mock", function()
      -- Create a test object
      local test_obj = {
        getData = function(id) return { id = id, name = "test" } end
      }
      
      -- Create a mock and set expectations
      local mock_obj = mock(test_obj)
      mock_obj:stub("getData", function(id)
        return { id = id, name = "mocked" }
      end)
      
      -- Call the method with different arguments
      local result1 = test_obj.getData(1)
      local result2 = test_obj.getData(2)
      
      -- Verify expected calls were made
      expect(mock_obj._stubs.getData.call_count).to.equal(2)
      expect(mock_obj._stubs.getData.calls[1][1]).to.equal(1)
      expect(mock_obj._stubs.getData.calls[2][1]).to.equal(2)
      
      -- Verify correct return values
      expect(result1.name).to.equal("mocked")
      expect(result2.name).to.equal("mocked")
    end)
    
    it("can restore individual stubs", function()
      -- Create a test object with multiple methods
      local test_obj = {
        getName = function() return "real_name" end,
        getAge = function() return 25 end
      }
      
      -- Stub both methods
      local mock_obj = mock(test_obj)
      mock_obj:stub("getName", function() return "mock_name" end)
      mock_obj:stub("getAge", function() return 99 end)
      
      -- Verify both stubs work
      expect(test_obj.getName()).to.equal("mock_name")
      expect(test_obj.getAge()).to.equal(99)
      
      -- Restore just the getName stub
      mock_obj:restore_stub("getName")
      
      -- getName should be back to normal, but getAge still stubbed
      expect(test_obj.getName()).to.equal("real_name")
      expect(test_obj.getAge()).to.equal(99)
      
      -- Clean up
      mock_obj:restore()
    end)
    
    it("can restore all stubs", function()
      -- Create a test object with multiple methods
      local test_obj = {
        getName = function() return "real_name" end,
        getAge = function() return 25 end,
        getAddress = function() return "123 Real St" end
      }
      
      -- Save references to original methods for comparison
      local original_getName = test_obj.getName
      local original_getAge = test_obj.getAge
      local original_getAddress = test_obj.getAddress
      
      -- Create a mock and stub all methods
      local mock_obj = mock(test_obj)
      mock_obj:stub("getName", function() return "mock_name" end)
      mock_obj:stub("getAge", function() return 99 end)
      mock_obj:stub("getAddress", function() return "456 Mock Ave" end)
      
      -- Verify all stubs work
      expect(test_obj.getName()).to.equal("mock_name")
      expect(test_obj.getAge()).to.equal(99)
      expect(test_obj.getAddress()).to.equal("456 Mock Ave")
      
      -- Restore all stubs
      mock_obj:restore()
      
      -- All methods should be back to normal
      expect(test_obj.getName).to.equal(original_getName)
      expect(test_obj.getAge).to.equal(original_getAge)
      expect(test_obj.getAddress).to.equal(original_getAddress)
      
      -- Function should return original values again
      expect(test_obj.getName()).to.equal("real_name")
      expect(test_obj.getAge()).to.equal(25)
      expect(test_obj.getAddress()).to.equal("123 Real St")
    end)
    
    it("can verify all methods were called", function()
      -- Create a test object with multiple methods
      local test_obj = {
        getName = function() return "real_name" end,
        getAge = function() return 25 end
      }
      
      -- Create a mock and stub both methods
      local mock_obj = mock(test_obj)
      mock_obj:stub("getName", function() return "mock_name" end)
      mock_obj:stub("getAge", function() return 99 end)
      
      -- Call both methods
      test_obj.getName()
      test_obj.getAge()
      
      -- Verification should pass when all methods are called
      local success = pcall(function()
        mock_obj:verify()
      end)
      expect(success).to.be_truthy()
      
      -- Create another mock with methods that won't all be called
      local test_obj2 = {
        method1 = function() end,
        method2 = function() end
      }
      
      local mock_obj2 = mock(test_obj2)
      mock_obj2:stub("method1", function() end)
      mock_obj2:stub("method2", function() end)
      
      -- Only call one method
      test_obj2.method1()
      
      -- Verification should fail because method2 was never called
      local failed = not pcall(function()
        mock_obj2:verify()
      end)
      expect(failed).to.be_truthy()
      
      -- Clean up
      mock_obj:restore()
      mock_obj2:restore()
    end)
  end)
  
  describe("Standalone Stub", function()
    it("creates simple value stubs", function()
      -- Create a stub that returns a fixed value
      local stub_fn = stub(42)
      
      -- Call the stub and verify the return value
      expect(stub_fn()).to.equal(42)
      expect(stub_fn()).to.equal(42)
      
      -- Verify call tracking
      expect(stub_fn.call_count).to.equal(2)
    end)
    
    it("creates function stubs", function()
      -- Create a stub with a function implementation
      local stub_fn = stub(function(a, b)
        return a * b
      end)
      
      -- Call the stub and verify the implementation is used
      expect(stub_fn(6, 7)).to.equal(42)
      
      -- Verify call tracking
      expect(stub_fn.call_count).to.equal(1)
      expect(stub_fn.calls[1][1]).to.equal(6)
      expect(stub_fn.calls[1][2]).to.equal(7)
    end)
    
    it("can be configured to return different values", function()
      -- Create an initial stub
      local stub_fn = stub("initial")
      expect(stub_fn()).to.equal("initial")
      
      -- Configure it to return a different value
      local new_stub = stub_fn:returns("new value")
      expect(new_stub()).to.equal("new value")
      
      -- Original stub should still return initial value
      expect(stub_fn()).to.equal("initial")
    end)
    
    it("can be configured to throw errors", function()
      -- Create a stub that throws an error
      local stub_fn = stub("value"):throws("test error")
      
      -- The stub should throw an error when called
      expect(function() stub_fn() end).to.throw()
      
      -- Verify the error message
      local success, error_message = pcall(stub_fn)
      expect(success).to.equal(false)
      expect(error_message).to.match("test error")
    end)
  end)
  
  describe("with_mocks Context Manager", function()
    it("provides a scoped mock context", function()
      local obj = {
        method1 = function() return "original1" end,
        method2 = function() return "original2" end
      }
      
      -- Use with_mocks to create a temporary mock context
      with_mocks(function(mock, spy, stub)
        -- Spy on method1
        local spy1 = spy.on(obj, "method1")
        
        -- Stub method2
        local stub1 = stub.on(obj, "method2", "stubbed")
        
        -- Verify the spy and stub work within the context
        obj.method1()
        expect(spy1.called).to.be_truthy()
        
        expect(obj.method2()).to.equal("stubbed")
      end)
      
      -- After the context, mocks should be restored
      expect(obj.method1()).to.equal("original1")
      expect(obj.method2()).to.equal("original2")
    end)
    
    it("restores mocks even if an error occurs", function()
      local obj = {
        method = function() return "original" end
      }
      
      -- Use with_mocks with a function that throws an error
      local success, error_message = pcall(function()
        with_mocks(function(mock, spy, stub)
          -- Stub the method
          stub.on(obj, "method", "stubbed")
          
          -- Verify the stub works
          expect(obj.method()).to.equal("stubbed")
          
          -- Throw an error
          error("Test error")
        end)
      end)
      
      -- Expect the error to be propagated
      expect(success).to.equal(false)
      expect(error_message).to.match("Test error")
      
      -- The mock should still be restored despite the error
      expect(obj.method()).to.equal("original")
    end)
  end)
  
  describe("Complete Mocking System Integration", function()
    -- Mark this test as pending since it uses advanced features that may not be fully implemented
    it("allows full mocking and verification workflow", function()
      -- Create a complex test scenario with multiple objects
      local db = {
        connect = function() return { connected = true } end,
        query = function(query_string) return { rows = 10 } end,
        disconnect = function() end
      }
      
      local api = {
        fetch = function(resource) return { data = "real data" } end,
        submit = function(data) return { success = true } end
      }
      
      -- Create a service that uses both objects
      local service = {
        process_data = function()
          local connection = db.connect()
          if not connection.connected then
            return { error = "Database connection failed" }
          end
          
          local query_result = db.query("SELECT * FROM data")
          local api_result = api.fetch("/data")
          
          local processed = {
            record_count = query_result.rows,
            data = api_result.data
          }
          
          local submit_result = api.submit(processed)
          db.disconnect()
          
          return {
            success = submit_result.success,
            processed = processed
          }
        end
      }
      
      -- Use with_mocks to mock everything in one context
      with_mocks(function(mockfn)
        -- Mock the database
        local db_mock = mockfn(db)
        db_mock:stub("connect", function() return { connected = true } end)
        db_mock:stub("query", function() return { rows = 5 } end)
        db_mock:stub("disconnect", function() end)
        
        -- Mock the API
        local api_mock = mockfn(api)
        api_mock:stub("fetch", function() return { data = "mocked data" } end)
        api_mock:stub("submit", function() return { success = true } end)
        
        -- Call the service method that uses our mocks
        local result = service.process_data()
        
        -- Verify the result uses our mock data
        expect(result.success).to.be_truthy()
        expect(result.processed.record_count).to.equal(5)
        expect(result.processed.data).to.equal("mocked data")
        
        -- Verify all mocks were called
        expect(db_mock._stubs.connect.called).to.be_truthy()
        expect(db_mock._stubs.query.called).to.be_truthy()
        expect(db_mock._stubs.disconnect.called).to.be_truthy()
        expect(api_mock._stubs.fetch.called).to.be_truthy()
        expect(api_mock._stubs.submit.called).to.be_truthy()
        
        -- Verify db mock methods using verify()
        db_mock:verify()
        api_mock:verify()
      end)
      
      -- After the context, originals should be restored
      local connection = db.connect()
      expect(connection.connected).to.be_truthy()
    end)
  end)
end)
