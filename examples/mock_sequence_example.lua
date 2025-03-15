--[[ 
  Mock Sequence Example
  This example demonstrates the benefits of sequence-based tracking for mocks
  over timestamp-based approaches and how to use the sequence verification API.
]]

local firmo = require "firmo"
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock = firmo.mock
local sleep = require "socket".sleep

describe("Mock Sequence Tracking", function()
  
  -- Example service that will be mocked
  local service = {
    getData = function() return "real data" end,
    processData = function(data) return "processed: " .. data end,
    saveResult = function(result) return true end
  }
  
  describe("1. Problems with timestamp-based tracking", function()
    it("can fail due to execution speed/timing issues", function()
      -- In timestamp-based systems, if calls happen too quickly,
      -- they might get the same timestamp and ordering becomes ambiguous
      
      local mockService = mock(service)
      
      -- These calls happen so quickly they might get the same timestamp
      mockService.getData()
      mockService.processData("test")
      mockService.saveResult("test result")
      
      -- In a timestamp system, this verification might fail intermittently
      print("With timestamps, verification could fail if calls have identical timestamps")
      print("making it difficult to verify exact call order reliably")
    end)
    
    it("can have flaky tests due to system load", function()
      -- Under system load, execution timing becomes unpredictable
      local mockService = mock(service)
      
      -- Simulate unpredictable execution timing
      mockService.getData()
      sleep(0.001) -- Tiny delay that could vary based on system load
      mockService.processData("test")
      
      print("Timestamp verification becomes unreliable when system load affects timing")
    end)
  end)
  
  describe("2. Sequence-based tracking solution", function()
    it("provides deterministic ordering regardless of timing", function()
      local mockService = mock(service)
      
      -- No matter how quickly these execute, sequence is preserved
      mockService.getData()
      mockService.processData("test")
      mockService.saveResult("test result")
      
      -- Verify calls happened in expected order
      expect(mockService.getData).was_called()
      expect(mockService.processData).was_called_after(mockService.getData)
      expect(mockService.saveResult).was_called_after(mockService.processData)
      
      print("Sequence-based tracking guarantees correct order verification regardless of timing")
    end)
    
    it("maintains correct order even with asynchronous operations", function()
      local mockService = mock(service)
      
      -- Even with delays, sequence numbers preserve order
      mockService.getData()
      sleep(0.1) -- Substantial delay
      mockService.processData("test")
      
      expect(mockService.getData).was_called_before(mockService.processData)
      
      print("Sequence tracking works consistently even with delays between calls")
    end)
  end)
  
  describe("3. Using sequence verification API", function()
    it("provides was_called_before/after assertions", function()
      local mockService = mock(service)
      
      mockService.getData()
      mockService.processData("test")
      mockService.saveResult("test result")
      
      -- Verify relative ordering
      expect(mockService.getData).was_called_before(mockService.processData)
      expect(mockService.processData).was_called_before(mockService.saveResult)
      expect(mockService.getData).was_called_before(mockService.saveResult)
      
      -- Alternative syntax
      expect(mockService.saveResult).was_called_after(mockService.processData)
      expect(mockService.processData).was_called_after(mockService.getData)
    end)
    
    it("can verify call order with was_called_with", function()
      local mockService = mock(service)
      
      mockService.getData()
      mockService.processData("first")
      mockService.processData("second")
      
      -- Can combine sequence with argument checking
      expect(mockService.processData).was_called_with("first")
          .before(function(call) return call.args[1] == "second" end)
      
      -- Or use the shorthand for checking multiple calls in order
      expect(mockService.processData).calls_were_in_order(
        function(call) return call.args[1] == "first" end,
        function(call) return call.args[1] == "second" end
      )
    end)
  end)
  
  describe("4. Sequence verification failures and debugging", function()
    it("provides helpful error messages when sequence is wrong", function()
      local mockService = mock(service)
      
      -- Intentionally call in wrong order
      mockService.processData("test")
      mockService.getData()
      
      -- This should fail with helpful message about call order
      local success, error_message = pcall(function()
        expect(mockService.getData).was_called_before(mockService.processData)
      end)
      
      print("Sequence verification failure example:")
      print(error_message or "Error message not captured")
      
      -- The error shows the actual sequence numbers and call order
    end)
    
    it("allows debugging sequence with inspect", function()
      local mockService = mock(service)
      
      mockService.getData()
      mockService.processData("test")
      mockService.saveResult("result")
      
      -- Inspect keeps track of sequence numbers for each call
      local calls = mockService.__calls
      
      print("Debugging call sequence:")
      for i, call in ipairs(calls) do
        print(string.format("Call #%d: %s (sequence: %d)", 
          i, call.name, call.sequence))
      end
      
      -- Can get global sequence number to compare across different mocks
      local lastSequence = firmo.mock.__global_sequence
      print("Current global sequence number: " .. lastSequence)
    end)
  end)
end)
