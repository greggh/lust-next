--[[ 
  Mock Sequence Returns Example
  This example demonstrates using sequential return values with mocks,
  allowing mocks to return different values on successive calls to the same method.
]]

local firmo = require "firmo"
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock, stub, with_mocks = firmo.mock, firmo.stub, firmo.with_mocks

describe("Sequential Return Values for Mocks", function()
  
  -- Example service that will be mocked
  local data_service = {
    fetch_data = function() return "real data" end,
    get_user = function(id) return { id = id, name = "User " .. id } end,
    connection_status = function() return "connected" end
  }
  
  describe("1. Basic sequential returns", function()
    it("returns different values on successive calls", function()
      local mock_service = mock(data_service)
      
      -- Setup sequence of return values
      mock_service:stub_in_sequence("fetch_data", {
        "first response",
        "second response",
        "third response"
      })
      
      -- First call returns first value
      expect(data_service.fetch_data()).to.equal("first response")
      
      -- Second call returns second value
      expect(data_service.fetch_data()).to.equal("second response")
      
      -- Third call returns third value
      expect(data_service.fetch_data()).to.equal("third response")
      
      -- Test that calls were tracked
      expect(mock_service._stubs.fetch_data.call_count).to.equal(3)
    end)
    
    it("works with functions in the sequence", function()
      local mock_service = mock(data_service)
      
      -- Setup sequence of values with functions
      mock_service:stub_in_sequence("get_user", {
        { id = 1, name = "Admin" },
        function(id) return { id = id, name = "Dynamic User " .. id } end,
        { id = 3, name = "Guest" }
      })
      
      -- First call returns first value
      local user1 = data_service.get_user(1)
      expect(user1.name).to.equal("Admin")
      
      -- Second call invokes the function
      local user2 = data_service.get_user(42)
      expect(user2.name).to.equal("Dynamic User 42")
      
      -- Third call returns third value regardless of input
      local user3 = data_service.get_user(999)
      expect(user3.name).to.equal("Guest")
    end)
  end)
  
  describe("2. Behavior after sequence is exhausted", function()
    it("returns nil when sequence is exhausted", function()
      local mock_service = mock(data_service)
      
      -- Setup a sequence with only two values
      mock_service:stub_in_sequence("fetch_data", {
        "first response",
        "second response"
      })
      
      -- First two calls return values from sequence
      expect(data_service.fetch_data()).to.equal("first response")
      expect(data_service.fetch_data()).to.equal("second response")
      
      -- Third call returns nil since sequence is exhausted
      expect(data_service.fetch_data()).to.equal(nil)
    end)
    
    it("can cycle through values (with standalone stub)", function()
      -- Create a standalone stub with cycling enabled
      local cycle_stub = stub(nil)
      
      -- Set up sequence values with cycling
      local cycled_values = {"A", "B", "C"}
      local current_index = 1
      
      -- Create a stub function that manually cycles through values
      local stub_impl = function()
        local result = cycled_values[current_index]
        current_index = current_index % #cycled_values + 1
        return result
      end
      
      -- Use the cycling implementation
      local cycling_stub = stub(stub_impl)
      
      -- First three calls
      expect(cycling_stub()).to.equal("A")
      expect(cycling_stub()).to.equal("B")
      expect(cycling_stub()).to.equal("C")
      
      -- Next calls should cycle
      expect(cycling_stub()).to.equal("A")
      expect(cycling_stub()).to.equal("B")
      expect(cycling_stub()).to.equal("C")
      expect(cycling_stub()).to.equal("A")
    end)
  end)
  
  describe("3. Using with_mocks context", function()
    it("works with the with_mocks context", function()
      with_mocks(function(mock_fn)
        local service = mock_fn(data_service)
        
        -- Setup sequential returns - use the stub_in_sequence directly
        service:stub_in_sequence("connection_status", {
          "connected",
          "unstable",
          "disconnected",
          "reconnecting",
          "connected"
        })
        
        -- Test the sequence
        expect(data_service.connection_status()).to.equal("connected")
        expect(data_service.connection_status()).to.equal("unstable")
        expect(data_service.connection_status()).to.equal("disconnected")
        expect(data_service.connection_status()).to.equal("reconnecting")
        expect(data_service.connection_status()).to.equal("connected")
      end)
      
      -- After with_mocks, original method is restored
      expect(data_service.connection_status()).to.equal("connected")
    end)
  end)
  
  describe("4. Using standalone stubs", function()
    it("works with standalone stubs", function()
      -- Create a standalone stub with sequential return values
      local status_stub = stub(nil):returns_in_sequence({
        "starting",
        "processing",
        "completed"
      })
      
      -- Test the sequence
      expect(status_stub()).to.equal("starting")
      expect(status_stub()).to.equal("processing")
      expect(status_stub()).to.equal("completed")
      expect(status_stub()).to.equal(nil) -- Exhausted
    end)
    
    it("can be used with error conditions", function()
      -- Create a stub that throws on second call
      local api_stub = stub(nil):returns_in_sequence({
        { success = true, data = "result" },
        function() error("Network error", 0) end,
        { success = true, data = "retry success" }
      })
      
      -- First call succeeds
      local result1 = api_stub()
      expect(result1.success).to.equal(true)
      
      -- Second call throws
      local success, err = pcall(function() api_stub() end)
      expect(success).to.equal(false)
      expect(err).to.match("Network error")
      
      -- Third call succeeds again
      local result3 = api_stub()
      expect(result3.success).to.equal(true)
      expect(result3.data).to.equal("retry success")
    end)
  end)
  
  describe("5. Practical examples", function()
    it("simulates an API with changing status", function()
      -- Setup a mock API client
      local api_client = {
        get_status = function() return "online" end,
        fetch_resource = function(id) return { id = id, status = "active" } end
      }
      
      local mock_api = mock(api_client)
      
      -- Simulate a resource that changes status over time
      mock_api:stub_in_sequence("fetch_resource", {
        { id = 1, status = "starting" },
        { id = 1, status = "pending" },
        { id = 1, status = "processing" },
        { id = 1, status = "completed" }
      })
      
      -- Function that polls until resource is complete
      local function wait_for_completion(client, id)
        local max_attempts = 5
        local attempts = 0
        
        repeat
          attempts = attempts + 1
          local resource = client.fetch_resource(id)
          
          if resource.status == "completed" then
            return true, resource
          end
          
          -- In real code, this would wait between attempts
        until attempts >= max_attempts
        
        return false, "Timed out waiting for completion"
      end
      
      -- Test the polling function
      local success, result = wait_for_completion(api_client, 1)
      
      expect(success).to.equal(true)
      expect(result.status).to.equal("completed")
      expect(mock_api._stubs.fetch_resource.call_count).to.equal(4)
    end)
    
    it("simulates authentication flow with token expiry", function()
      -- Setup a mock auth service
      local auth_service = {
        login = function() return { token = "valid_token", expires_in = 3600 } end,
        verify_token = function(token) return { valid = true } end,
        refresh_token = function(token) return { token = "new_token", expires_in = 3600 } end
      }
      
      local mock_auth = mock(auth_service)
      
      -- Token validity changes over time
      mock_auth:stub_in_sequence("verify_token", {
        { valid = true },
        { valid = true },
        { valid = false, reason = "expired" },  -- Token expires on third check
        { valid = true }                        -- After refresh
      })
      
      -- Refreshes token only when needed
      mock_auth:stub("refresh_token", { token = "refreshed_token", expires_in = 3600 })
      
      -- Function that ensures a valid token
      local function ensure_valid_token(auth, token)
        local status = auth.verify_token(token)
        
        if not status.valid then
          local refresh_result = auth.refresh_token(token)
          return refresh_result.token
        end
        
        return token
      end
      
      -- First two calls should keep original token
      expect(ensure_valid_token(auth_service, "token")).to.equal("token")
      expect(ensure_valid_token(auth_service, "token")).to.equal("token")
      
      -- Third call should refresh the token
      expect(ensure_valid_token(auth_service, "token")).to.equal("refreshed_token")
      
      -- Verify token was checked three times and refreshed once
      expect(mock_auth._stubs.verify_token.call_count).to.equal(3)
      expect(mock_auth._stubs.refresh_token.call_count).to.equal(1)
    end)
  end)
end)

print("\nMock Sequence Returns Examples completed!")
