--[[ 
  Enhanced Mock Sequence Returns Example
  This example demonstrates the advanced mock sequence features for controlling
  how mocks behave with sequential return values and exhaustion handling.
]]

local firmo = require "firmo"
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock, stub, with_mocks = firmo.mock, firmo.stub, firmo.with_mocks

describe("Enhanced Sequential Return Values", function()
  
  -- Example service that will be mocked
  local api_client = {
    get_status = function() return { status = "online" } end,
    fetch_data = function(id) return { id = id, data = "real data for " .. id } end
  }
  
  describe("1. Advanced Sequence Controls", function()
    it("demonstrates sequence reset functionality", function()
      local api_mock = mock(api_client)
      
      -- Setup sequence of return values
      api_mock:stub_in_sequence("get_status", {
        { status = "starting" },
        { status = "connecting" },
        { status = "online" }
      })
      
      -- Get the stub to work with
      local status_stub = api_mock._stubs.get_status
      
      -- First sequence
      expect(api_client.get_status().status).to.equal("starting")
      expect(api_client.get_status().status).to.equal("connecting")
      expect(api_client.get_status().status).to.equal("online")
      
      -- After sequence is exhausted
      expect(api_client.get_status()).to.equal(nil)
      
      -- Instead of reset, let's create a new sequence
      api_mock:stub_in_sequence("get_status", {
        { status = "starting" },
        { status = "connecting" }
      })
      
      -- Sequence starts with new values
      expect(api_client.get_status().status).to.equal("starting")
      expect(api_client.get_status().status).to.equal("connecting")
    end)

    it("demonstrates cycling through values indefinitely", function()
      local api_mock = mock(api_client)
      
      -- For cycling, we'll use a custom implementation
      local cycle_values = {
        { status = "connected" },
        { status = "connecting" },
        { status = "connected" },
        { status = "disconnected" }
      }
      local index = 1
      
      -- Create a stub that manually handles cycling
      api_mock:stub("get_status", function()
        local result = cycle_values[index]
        index = (index % #cycle_values) + 1
        return result
      end)
      
      -- First loop through the sequence
      expect(api_client.get_status().status).to.equal("connected")
      expect(api_client.get_status().status).to.equal("connecting")
      expect(api_client.get_status().status).to.equal("connected")
      expect(api_client.get_status().status).to.equal("disconnected")
      
      -- Second loop - should repeat the same values
      expect(api_client.get_status().status).to.equal("connected")
      expect(api_client.get_status().status).to.equal("connecting")
      expect(api_client.get_status().status).to.equal("connected")
      expect(api_client.get_status().status).to.equal("disconnected")
      
      -- Third loop start
      expect(api_client.get_status().status).to.equal("connected")
    end)
  end)
  
  describe("2. Exhaustion Behavior Options", function()
    it("returns nil by default when sequence is exhausted", function()
      local api_mock = mock(api_client)
      
      -- Setup a sequence with only two values
      api_mock:stub_in_sequence("get_status", {
        { status = "connecting" },
        { status = "connected" }
      })
      
      -- First two calls return values from sequence
      expect(api_client.get_status().status).to.equal("connecting")
      expect(api_client.get_status().status).to.equal("connected")
      
      -- Third call returns nil since sequence is exhausted (default behavior)
      expect(api_client.get_status()).to.equal(nil)
    end)
    
    it("can specify a custom value when exhausted", function()
      local api_mock = mock(api_client)
      
      -- Setup a sequence with only two values
      api_mock:stub_in_sequence("get_status", {
        { status = "connecting" },
        { status = "connected" }
      })
      
      -- Create a sequence with custom fallback behavior
      local sequence_values = {
        { status = "connecting" },
        { status = "connected" }
      }
      local exhausted_value = { status = "exhausted" }
      local index = 1
      local exhausted = false
      
      api_mock:stub("get_status", function()
        if index <= #sequence_values then
          local result = sequence_values[index]
          index = index + 1
          return result
        else
          -- Return custom exhausted value
          return exhausted_value
        end
      end)
      
      -- First two calls return values from sequence
      expect(api_client.get_status().status).to.equal("connecting")
      expect(api_client.get_status().status).to.equal("connected")
      
      -- Third call returns custom value since sequence is exhausted
      expect(api_client.get_status().status).to.equal("exhausted")
      expect(api_client.get_status().status).to.equal("exhausted") -- Still returns custom value
    end)
    
    it("can fall back to original implementation when exhausted", function()
      -- Create an object with real implementation
      local real_value = { status = "real implementation" }
      local original_fn = function() return real_value end
      local obj = { get_value = original_fn }
      
      -- Create a sequence with fallback to original
      local sequence_values = {
        { status = "mocked 1" },
        { status = "mocked 2" }
      }
      local index = 1
      
      -- Create a mock with the fallback behavior
      local obj_mock = mock(obj)
      obj_mock:stub("get_value", function()
        if index <= #sequence_values then
          local result = sequence_values[index]
          index = index + 1
          return result
        else
          -- Fall back to original implementation
          return original_fn()
        end
      end)
      
      -- First two calls return values from sequence
      expect(obj.get_value().status).to.equal("mocked 1")
      expect(obj.get_value().status).to.equal("mocked 2")
      
      -- Third call falls back to original implementation
      expect(obj.get_value().status).to.equal("real implementation")
    end)
  end)
  
  describe("3. Practical Examples", function()
    it("simulates a retry mechanism with fallbacks", function()
      -- Define retry function to test
      local function retry_operation(client, max_attempts)
        local attempts = 0
        local result
        
        repeat
          attempts = attempts + 1
          result = client.fetch_data("resource123")
          
          if result and result.success then
            return result.data
          end
          
          -- In real code would wait before retrying
        until attempts >= max_attempts
        
        return nil, "Failed after " .. attempts .. " attempts"
      end
      
      local api_mock = mock(api_client)
      
      -- Simulate initial failures then success
      api_mock:stub_in_sequence("fetch_data", {
        { success = false, error = "Network error" },
        { success = false, error = "Timeout" },
        { success = true, data = "Success data!" }
      })
      
      -- With enough retries, it succeeds
      local data, err = retry_operation(api_client, 3)
      expect(data).to.equal("Success data!")
      expect(err).to.equal(nil)
      expect(api_mock._stubs.fetch_data.call_count).to.equal(3)
      
      -- Reset for next test
      api_mock._stubs.fetch_data:reset_sequence()
      
      -- With fewer retries than needed, it fails
      local data2, err2 = retry_operation(api_client, 2)
      expect(data2).to.equal(nil)
      expect(err2).to.match("Failed after 2 attempts")
    end)
    
    it("simulates state machine transitions", function()
      -- Fake state machine implementation
      local state_machine = {
        current_state = "initial",
        transition = function(self, event)
          -- In reality would compute next state from current + event
          return "next state after " .. self.current_state
        end
      }
      
      -- Mock the state machine
      local mock_machine = mock(state_machine)
      
      -- Model a specific sequence of state transitions
      mock_machine:stub_in_sequence("transition", {
        "pending",
        "active",
        "processing",
        "completed"
      })
      
      -- Enable fallback to dynamic behavior after sequence is exhausted
      local fallback_transition = function(self, event)
        if event == "reset" then
          return "initial"
        else
          return "error"
        end
      end
      
      -- Create custom implementation with fallback function
      local sequence_transitions = {
        "pending",
        "active",
        "processing",
        "completed"
      }
      local index = 1
      
      mock_machine:stub("transition", function(self, event)
        if index <= #sequence_transitions then
          local result = sequence_transitions[index]
          index = index + 1
          return result
        else
          -- Fall back to custom function
          return fallback_transition(self, event)
        end
      end)
      
      -- First four transitions follow the sequence
      expect(state_machine:transition("start")).to.equal("pending")
      expect(state_machine:transition("process")).to.equal("active")
      expect(state_machine:transition("continue")).to.equal("processing")
      expect(state_machine:transition("finish")).to.equal("completed")
      
      -- After sequence is exhausted, falls back to custom function
      expect(state_machine:transition("unknown")).to.equal("error")
      expect(state_machine:transition("reset")).to.equal("initial")
    end)
  end)
  
  describe("4. Complex Configuration Chains", function()
    it("supports fluent interface for advanced configuration", function()
      local api_mock = mock(api_client)
      
      -- Create a fluent implementation with cycling and custom behavior
      local sequence_values = {
        { status = "pending", data = nil },
        { status = "processing", data = { partial = true } }
      }
      local exhausted_value = { status = "error", error = "Unexpected sequence end" }
      local index = 1
      local cycling = true
      
      api_mock:stub("fetch_data", function()
        if index <= #sequence_values or cycling then
          -- Get index with cycling
          local actual_index = ((index - 1) % #sequence_values) + 1
          
          -- Get value and advance index
          local result = sequence_values[actual_index]
          index = index + 1
          
          return result
        else
          -- Return custom exhaustion value
          return exhausted_value
        end
      end)
      
      -- Method to disable cycling for test purposes
      local disable_cycling = function()
        cycling = false
        -- Set index to start of sequence
        index = 1
      end
      
      -- Test the first cycle
      expect(api_client.fetch_data().status).to.equal("pending")
      expect(api_client.fetch_data().status).to.equal("processing")
      
      -- Test the second cycle (should repeat due to cycling)
      expect(api_client.fetch_data().status).to.equal("pending")
      expect(api_client.fetch_data().status).to.equal("processing")
      
      -- We can disable cycling mid-test to test exhaustion
      disable_cycling()
      
      -- Process the remaining sequence values
      expect(api_client.fetch_data().status).to.equal("pending")
      expect(api_client.fetch_data().status).to.equal("processing")
      
      -- Now it should return the custom exhaustion value
      expect(api_client.fetch_data().status).to.equal("error")
      expect(api_client.fetch_data().error).to.equal("Unexpected sequence end")
    end)
  end)
end)

print("\nEnhanced Mock Sequence Features Example completed!")
