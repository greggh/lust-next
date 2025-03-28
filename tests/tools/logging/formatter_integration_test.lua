-- Logging Formatter Integration Module Tests
-- Tests for the logging formatter integration functionality

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local formatter_integration = require("lib.tools.logging.formatter_integration")
local logging = require("lib.tools.logging")

describe("Logging Formatter Integration Module", function()
  it("enhances formatters with logging capabilities", function()
    -- Create a mock formatters module
    local formatters = {
      available_formatters = {
        test = {
          type = "test",
          name = "test"
        }
      },
      init = function() return true end
    }
    
    -- Mock the try_require function to return our mock formatters
    local original_try_require = _G.try_require
    _G.try_require = function(name)
      if name == "lib.reporting.formatters" then
        return formatters
      end
      return nil
    end
    
    -- Test enhancement
    local result, err = formatter_integration.enhance_formatters()
    
    -- Restore original function
    _G.try_require = original_try_require
    
    -- Verify enhancement
    expect(err).to_not.exist()
    expect(result).to.exist()
    expect(formatters.available_formatters.test._logger).to.exist()
    expect(formatters.available_formatters.test.log_debug).to.be.a("function")
    expect(formatters.available_formatters.test.log_info).to.be.a("function")
    expect(formatters.available_formatters.test.log_error).to.be.a("function")
  end)
  
  it("creates test-specific loggers", function()
    local test_logger = formatter_integration.create_test_logger(
      "Test Name",
      { component = "test" }
    )
    
    expect(test_logger).to.exist()
    expect(test_logger.info).to.be.a("function")
    expect(test_logger.debug).to.be.a("function")
    expect(test_logger.error).to.be.a("function")
    expect(test_logger.warn).to.be.a("function")
    expect(test_logger.with_context).to.be.a("function")
    expect(test_logger.step).to.be.a("function")
  end)
  
  it("creates step-specific loggers", function()
    local test_logger = formatter_integration.create_test_logger(
      "Test Name",
      { component = "test" }
    )
    
    local step_logger = test_logger.step("Step 1")
    
    expect(step_logger).to.exist()
    expect(step_logger.info).to.be.a("function")
    
    -- Try logging with the step logger
    step_logger.info("Step message")
    
    -- No assertions here since we can't easily verify the log output
    -- But we can ensure the function doesn't throw errors
  end)
  
  it("captures and collects logs for tests", function()
    -- Start capturing logs
    formatter_integration.capture_start("Test Capture", "test-123")
    
    -- Generate some logs
    local logger = logging.get_logger("test_module")
    logger.info("Test message 1")
    logger.debug("Test message 2")
    
    -- End capture and get logs
    local logs = formatter_integration.capture_end("test-123")
    
    expect(logs).to.be.a("table")
    -- Number of logs may vary depending on configuration, so we don't assert the count
  end)
  
  it("formats logs for display", function()
    local logs = {
      {
        timestamp = "2025-03-26T14:32:45",
        level = "INFO",
        module = "test",
        message = "Test message"
      }
    }
    
    local formatted = formatter_integration.format_logs(logs)
    
    expect(formatted).to.be.a("string")
    expect(formatted).to.match("INFO")
    expect(formatted).to.match("Test message")
  end)
  
  it("attaches logs to test results", function()
    local results = {
      name = "Test Results",
      status = "passed"
    }
    
    local logs = {
      {
        timestamp = "2025-03-26T14:32:45",
        level = "INFO",
        module = "test",
        message = "Test message"
      }
    }
    
    local enhanced_results = formatter_integration.attach_logs_to_results(results, logs)
    
    expect(enhanced_results).to.exist()
    expect(enhanced_results.name).to.equal("Test Results")
    expect(enhanced_results.status).to.equal("passed")
    expect(enhanced_results.logs).to.exist()
    expect(enhanced_results.logs[1]).to.equal(logs[1])
  end)
  
  it("creates a log formatter", function()
    local log_formatter = formatter_integration.create_log_formatter()
    
    expect(log_formatter).to.exist()
    expect(log_formatter.init).to.be.a("function")
    expect(log_formatter.format).to.be.a("function")
    expect(log_formatter.format_json).to.be.a("function")
    expect(log_formatter.format_text).to.be.a("function")
  end)
  
  -- Add more tests for other formatter integration functionality
end)