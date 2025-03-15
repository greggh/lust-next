-- Example demonstrating enhanced mocking functionality
package.path = "../?.lua;" .. package.path
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock, spy, stub, with_mocks = firmo.mock, firmo.spy, firmo.stub, firmo.with_mocks
local arg_matcher = firmo.arg_matcher

-- Simulated API client we'll use to demonstrate advanced mocking
local api_client = {
  initialize = function(config)
    print("Actually initializing API client with config:", config)
    return true
  end,
  
  authenticate = function(credentials)
    print("Actually authenticating with credentials:", credentials)
    return "auth_token_12345"
  end,
  
  fetch_data = function(endpoint, params)
    print("Actually fetching data from:", endpoint, "with params:", params)
    return {
      status = 200,
      data = { items = {{id = 1}, {id = 2}} }
    }
  end,
  
  process_data = function(data)
    print("Actually processing data:", data)
    return "processed_" .. data.id
  end,
  
  update_record = function(id, fields)
    print("Actually updating record:", id, "with:", fields)
    return {success = true, id = id}
  end,
  
  close = function()
    print("Actually closing API connection")
    return true
  end
}

-- Service that uses the API client
local DataService = {
  fetch_and_process = function(endpoint, id)
    local client = api_client.initialize({timeout = 5000})
    local token = api_client.authenticate({key = "api_key_123"})
    local response = api_client.fetch_data(endpoint, {id = id, token = token})
    local result = api_client.process_data(response.data.items[1])
    api_client.close()
    return result
  end,
  
  update_record = function(id, name, status)
    local client = api_client.initialize({timeout = 5000})
    local token = api_client.authenticate({key = "api_key_123"})
    local result = api_client.update_record(id, {name = name, status = status})
    api_client.close()
    return result.success
  end
}

-- Examples demonstrating enhanced mocking features
describe("Enhanced Mocking Features", function()
  
  describe("Argument Matchers", function()
    it("allows matching any argument", function()
      with_mocks(function(mock_fn)
        local api_mock = mock_fn(api_client)
        
        api_mock:stub("initialize", true)
        api_mock:stub("authenticate", "mock_token")
        api_mock:stub("fetch_data", {status = 200, data = {items = {{id = 999}}}})
        api_mock:stub("process_data", "processed_data")
        api_mock:stub("close", true)
        
        -- Use the service
        local result = DataService.fetch_and_process("users", 123)
        expect(result).to.equal("processed_data")
        
        -- Get spy objects for verification
        local init_spy = api_mock._stubs.initialize
        local auth_spy = api_mock._stubs.authenticate
        local fetch_spy = api_mock._stubs.fetch_data
        local process_spy = api_mock._stubs.process_data
        local close_spy = api_mock._stubs.close
        
        -- Verify calls with argument matchers
        expect(init_spy.called).to.be.truthy()
        expect(auth_spy:called_with({key = "api_key_123"})).to.be.truthy()
        expect(fetch_spy:called_with("users", arg_matcher.table_containing({id = 123}))).to.be.truthy()
        expect(process_spy.call_count > 0).to.be.truthy()
        expect(close_spy.called).to.be.truthy()
      end)
    end)
    
    it("provides type-based matchers", function()
      with_mocks(function(mock_fn)
        local fn = stub(true)
        
        -- Call with different argument types
        fn("string arg")
        fn(123)
        fn({key = "value"})
        fn(function() return true end)
        
        -- Verify with type matchers
        expect(fn:called_with(arg_matcher.string())).to.be.truthy()
        expect(fn:called_with(arg_matcher.number())).to.be.truthy()
        expect(fn:called_with(arg_matcher.table())).to.be.truthy()
        expect(fn:called_with(arg_matcher.func())).to.be.truthy()
        
        -- Check if any call had this pattern of args
        expect(fn:has_calls_with(arg_matcher.string(), arg_matcher.number())).to.equal(false)
      end)
    end)
    
    it("supports custom matchers", function()
      with_mocks(function(mock_fn)
        local update_fn = stub(true)
        
        -- Call with different arguments
        update_fn(123, "Active")
        update_fn(456, "Inactive")
        
        -- Create a custom matcher for validation
        local status_matcher = arg_matcher.custom(function(val)
          return type(val) == "string" and (val == "Active" or val == "Inactive")
        end, "valid status ('Active' or 'Inactive')")
        
        -- Verify with custom matcher
        expect(update_fn:called_with(arg_matcher.number(), status_matcher)).to.be.truthy()
        expect(update_fn:called_with(123, status_matcher)).to.be.truthy()
        expect(update_fn:called_with(789, status_matcher)).to.equal(false)
        
        -- Invalid status should fail the matcher
        expect(update_fn:called_with(arg_matcher.any(), "Unknown")).to.equal(false)
      end)
    end)
  end)
  
  describe("Call Sequence Verification", function()
    it("verifies call order with in_order", function()
      with_mocks(function(mock_fn)
        local api_mock = mock_fn(api_client)
        
        -- Stub all methods
        api_mock:stub("initialize", true)
        api_mock:stub("authenticate", "token")
        api_mock:stub("fetch_data", {data = {}})
        api_mock:stub("close", true)
        
        -- Make calls in order - no delays needed with sequence-based tracking
        api_client.initialize()
        api_client.authenticate()
        api_client.fetch_data()
        api_client.close()
        
        -- Verify the exact call sequence - should pass
        expect(api_mock:verify_sequence({
          {method = "initialize"},
          {method = "authenticate"},
          {method = "fetch_data"},
          {method = "close"}
        })).to.be.truthy()
        
        -- Test a negative case - wrong order should fail
        local success, error_message = pcall(function()
          api_mock:verify_sequence({
            {method = "initialize"},
            {method = "fetch_data"}, -- Wrong order
            {method = "authenticate"},
            {method = "close"}
          })
        end)
        
        expect(success).to.equal(false)
        expect(error_message).to.match("Call sequence mismatch")
        expect(error_message).to.match("Expected method 'fetch_data'")
        expect(error_message).to.match("but got 'authenticate'")
      end)
    end)
    
    it("verifies call order with arguments", function()
      with_mocks(function(mock_fn)
        local api_mock = mock_fn(api_client)
        
        -- Stub methods
        api_mock:stub("initialize", true)
        api_mock:stub("update_record", {success = true})
        api_mock:stub("close", true)
        
        -- Make calls with arguments
        api_client.initialize({timeout = 1000})
        api_client.update_record(123, {name = "Test"})
        api_client.update_record(456, {status = "Active"})
        api_client.close()
        
        -- Verify sequence with arguments
        expect(api_mock:verify_sequence({
          {method = "initialize", args = {arg_matcher.table()}},
          {method = "update_record", args = {123, arg_matcher.any()}},
          {method = "update_record", args = {456, arg_matcher.table_containing({status = "Active"})}},
          {method = "close"}
        })).to.be.truthy()
      end)
    end)
    
    it("provides methods for checking call order", function()
      with_mocks(function(mock_fn)
        -- Create a new mock object for each test
        local sequence = mock_fn({
          first = function() end,
          second = function() end,
          third = function() end
        })
        
        -- Stub the methods - stubs return values and track calls
        sequence:stub("first", "one")
        sequence:stub("second", "two")
        sequence:stub("third", "three")
        
        -- Make calls in sequence - no delays needed with sequence-based tracking
        sequence.target.first()
        sequence.target.second()
        sequence.target.third()
        
        -- Should have stubs
        expect(sequence._stubs ~= nil).to.be.truthy()
        
        -- Should have created all stubs
        expect(sequence._stubs.first ~= nil).to.be.truthy()
        expect(sequence._stubs.second ~= nil).to.be.truthy()
        expect(sequence._stubs.third ~= nil).to.be.truthy()
        
        -- Get call sequence arrays
        local first_sequences = sequence._stubs.first.call_sequence
        local second_sequences = sequence._stubs.second.call_sequence
        local third_sequences = sequence._stubs.third.call_sequence
        
        -- Should have sequence arrays
        expect(first_sequences ~= nil).to.be.truthy()
        expect(second_sequences ~= nil).to.be.truthy()
        expect(third_sequences ~= nil).to.be.truthy()
        
        -- Should have a sequence number for each call
        expect(#first_sequences).to.equal(1)
        expect(#second_sequences).to.equal(1)
        expect(#third_sequences).to.equal(1)
        
        -- Verify in correct order - sequence numbers should increase with each call
        expect(first_sequences[1] < second_sequences[1]).to.be.truthy()
        expect(second_sequences[1] < third_sequences[1]).to.be.truthy()
        
        -- Verify sequence
        expect(sequence:verify_sequence({
          {method = "first"},
          {method = "second"},
          {method = "third"}
        })).to.be.truthy()
      end)
    end)
  end)
  
  describe("Expectation Setting", function()
    it("allows setting expectations before calls", function()
      with_mocks(function(mock_fn)
        local api_mock = mock_fn(api_client)
        
        -- Set expectations for what will be called
        api_mock:expect("initialize").with({timeout = 5000}).to.be.called.once()
        api_mock:expect("authenticate").with({key = "api_key_123"}).to.be.called.once()
        api_mock:expect("update_record").with(123, arg_matcher.table_containing({name = "Test"})).to.be.called.once()
        api_mock:expect("close").to.be.called.once()
        
        -- Stub return values
        api_mock:stub("initialize", true)
        api_mock:stub("authenticate", "token")
        api_mock:stub("update_record", {success = true, id = 123})
        api_mock:stub("close", true)
        
        -- Run the actual code
        DataService.update_record(123, "Test", "Active")
        
        -- Verify all expectations were met
        api_mock:verify_expectations()
      end)
    end)
    
    it("allows setting call count expectations", function()
      with_mocks(function(mock_fn)
        local cache = mock_fn({
          get = function() end,
          set = function() end,
          clear = function() end
        })
        
        -- Set expectations with call counts
        cache:expect("get").to.be.called.times(2)
        cache:expect("set").to.be.called.times(1)
        cache:expect("clear").to.not_be.called()
        
        -- Stub implementations
        cache:stub("get", nil) -- First call returns nil (miss)
        cache:stub("get", {data = "cached"}) -- Second call returns cached data
        cache:stub("set", true)
        
        -- Make calls
        cache.target.get("key1")
        cache.target.set("key1", "value1")
        cache.target.get("key1") 
        
        -- Verify the expected call counts
        cache:verify_expectations()
        
        -- Failed expectation example
        expect(function()
          local bad_mock = mock_fn({
            validate = function() end
          })
          bad_mock:expect("validate").to.be.called.times(1)
          bad_mock:verify_expectations() -- This should fail
        end).to.fail()
      end)
    end)
    
    it("supports expectation chains for more readable tests", function()
      with_mocks(function(mock_fn)
        local auth = mock_fn({
          login = function() end,
          validate = function() end,
          logout = function() end
        })
        
        -- Set up expectations with fluent chains
        auth:expect("login").with("user", "pass").to.be.called.once()
        auth:expect("validate").with(arg_matcher.string()).to.be.called.at_least(1)
        auth:expect("logout").to.be.called.once()
        
        -- Stub implementations
        auth:stub("login", "token123")
        auth:stub("validate", true)
        auth:stub("logout", true)
        
        -- Make calls
        auth.target.login("user", "pass")
        auth.target.validate("token123")
        auth.target.logout()
        
        -- Verify everything meets expectations
        auth:verify_expectations()
        
        -- Test negative cases
        local bad_auth = mock_fn({
          process = function() end
        })
        
        -- Set expectation for calls that won't happen
        bad_auth:expect("process").to.be.called.times(2)
        bad_auth:stub("process", true)
        
        -- Only call once (expectation is for twice)
        bad_auth.target.process()
        
        -- Should fail verification
        local success, err = pcall(function()
          bad_auth:verify_expectations()
        end)
        
        expect(success).to.equal(false)
        expect(err).to.match("expected to be called exactly 2 times but was called 1 times")
      end)
    end)
  end)
  
  describe("Integration Example", function()
    it("demonstrates a complete workflow with enhanced mocking", function()
      with_mocks(function(mock_fn)
        local api_mock = mock_fn(api_client)
        
        -- Set expectations for the workflow - with one that should fail
        api_mock:expect("initialize").to.be.called.once()
        api_mock:expect("authenticate").to.be.called.once()
        api_mock:expect("fetch_data").to.be.called.once()
        api_mock:expect("process_data").to.be.called.once()
        api_mock:expect("close").to.be.called.times(2) -- Expecting 2 calls, but will only get 1
          
        -- Set up return values
        api_mock:stub("initialize", true)
        api_mock:stub("authenticate", "mock_token")
        api_mock:stub("fetch_data", {status = 200, data = {items = {{id = 999, name = "Test User"}}}})
        api_mock:stub("process_data", "processed_data")
        api_mock:stub("close", true)
        
        -- Run the code with our expectations
        local result = DataService.fetch_and_process("users", 123)
        
        -- Verify the test result value
        expect(result).to.equal("processed_data")
        
        -- Expectation verification should fail (expecting 2 calls to close but only got 1)
        local success, err = pcall(function()
          api_mock:verify_expectations()
        end)
        
        -- Verification should fail
        expect(success).to.equal(false)
        
        -- Error message should mention the specific failure
        expect(err).to.match("close")
        expect(err).to.match("expected to be called exactly 2 times but was called 1 times")
      end)
    end)
    
    it("provides detailed error messages on failure", function()
      -- Simplified test for error messages
      with_mocks(function(mock_fn)
        local dummy_obj = mock_fn({ test_method = function() end })
        
        -- Stub a method
        dummy_obj:stub("test_method", true)
        
        -- Call it
        dummy_obj.target.test_method("actual arg")
        
        -- Verify we can get details about the call
        expect(dummy_obj._stubs.test_method.calls[1][1]).to.equal("actual arg")
        expect(dummy_obj._stubs.test_method.call_count).to.equal(1)
        
        -- Demonstrate that argument matching works
        expect(dummy_obj._stubs.test_method:called_with("actual arg")).to.be.truthy()
        expect(dummy_obj._stubs.test_method:called_with("wrong arg")).to.equal(false)
      end)
    end)
  end)
end)

print("\nEnhanced Mocking Examples completed!")
