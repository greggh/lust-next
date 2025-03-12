-- Example demonstrating log export to external analysis tools
local logging = require("lib.tools.logging")
local log_export = require("lib.tools.logging.export")

print("=== Log Export Example ===")
print("")
print("This example demonstrates:")
print("1. Exporting logs to formats compatible with external analysis tools")
print("2. Creating configuration files for external platforms")
print("3. Setting up real-time log exporters")
print("4. Working with multiple export formats simultaneously")
print("")

-- Configure logging
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  use_colors = true,
  output_file = "export_example.log",
  json_file = "export_example.json",
  log_dir = "logs",
  standard_metadata = {
    version = "1.0.0",
    environment = "development"
  }
})

-- Create a logger
local logger = logging.get_logger("export_example")

-- Generate sample logs
print("Generating sample logs...")

-- System logs
logger.info("Application started")
logger.debug("Initializing components", {
  components = {"database", "api", "ui"},
  config_file = "/etc/app/config.json"
})

-- Error scenario
logger.error("Failed to connect to service", {
  service = "payment-gateway",
  error_code = "ECONNREFUSED",
  retry_count = 3,
  host = "api.payment.example.com"
})

-- Security event
logger.warn("Authentication failure", {
  user_id = "user123",
  ip_address = "192.168.1.100",
  attempt = 2,
  max_attempts = 5
})

-- Performance data
logger.info("Performance metrics", {
  operation = "process_order",
  order_id = "order-456",
  duration_ms = 234,
  memory_used_kb = 1500,
  db_queries = 5
})

-- Flush logs to ensure they're written
logging.flush()

print("Sample logs generated in logs/export_example.log and logs/export_example.json")
print("")

-- Get supported platforms
local platforms = log_export.get_supported_platforms()
print("Supported export platforms:")
for i, platform in ipairs(platforms) do
  print(string.format("  %d. %s", i, platform))
end
print("")

-- Create export examples for each platform
print("=== Exporting Logs to External Platforms ===")

-- Function to demonstrate export to a platform
local function demonstrate_platform_export(platform, description)
  print("\n" .. description .. ":")
  
  -- Export logs to platform format
  local result = log_export.create_platform_file(
    "logs/export_example.json",
    platform,
    "logs/export_" .. platform .. ".json",
    {
      environment = "demo",
      service_name = "lust-next-example"
    }
  )
  
  if result then
    print(string.format("  Exported %d entries to %s format: %s", 
      result.entries_processed, platform, result.output_file))
      
    -- Show a sample of the first entry
    if result.entries and result.entries[1] then
      print("  Sample export format:")
      local formatted = ""
      local json_string = ""
      
      -- Simple JSON stringification for display
      local function json_stringify(t, indent)
        indent = indent or "    "
        local parts = {}
        
        if type(t) ~= "table" then
          return tostring(t)
        end
        
        -- Check if array or object
        local is_array = true
        local n = 0
        for k, _ in pairs(t) do
          n = n + 1
          if type(k) ~= "number" or k ~= n then
            is_array = false
            break
          end
        end
        
        if is_array then
          for _, v in ipairs(t) do
            if type(v) == "table" then
              table.insert(parts, indent .. json_stringify(v, indent .. "  "))
            else
              table.insert(parts, indent .. tostring(v))
            end
          end
          return "[\n" .. table.concat(parts, ",\n") .. "\n" .. string.sub(indent, 1, -3) .. "]"
        else
          for k, v in pairs(t) do
            local value
            if type(v) == "table" then
              value = json_stringify(v, indent .. "  ")
            else
              value = tostring(v)
              if type(v) == "string" then
                value = '"' .. value .. '"'
              end
            end
            table.insert(parts, indent .. '"' .. tostring(k) .. '": ' .. value)
          end
          return "{\n" .. table.concat(parts, ",\n") .. "\n" .. string.sub(indent, 1, -3) .. "}"
        end
      end
      
      -- Truncate to first few fields for display
      local first_entry = result.entries[1]
      local simplified = {}
      local count = 0
      for k, v in pairs(first_entry) do
        if count < 5 then  -- Only show first 5 fields
          simplified[k] = v
          count = count + 1
        end
      end
      simplified["..."] = "additional fields omitted"
      
      print(json_stringify(simplified))
    end
  else
    print("  Failed to export logs to " .. platform .. " format")
  end
  
  -- Create configuration file for the platform
  local config_result = log_export.create_platform_config(
    platform,
    "logs/config_" .. platform .. ".conf",
    {
      environment = "demo",
      service = "lust-next-example",
      es_host = "localhost:9200"
    }
  )
  
  if config_result then
    print(string.format("  Created %s configuration: %s", 
      platform, config_result.config_file))
  else
    print("  Failed to create " .. platform .. " configuration")
  end
end

-- Demonstrate export to each platform
demonstrate_platform_export("logstash", "Exporting to Logstash/Elasticsearch (ELK stack)")
demonstrate_platform_export("elasticsearch", "Exporting directly to Elasticsearch")
demonstrate_platform_export("splunk", "Exporting to Splunk")
demonstrate_platform_export("datadog", "Exporting to Datadog")
demonstrate_platform_export("loki", "Exporting to Grafana Loki")

-- Demonstrate real-time exporters
print("\n=== Real-time Log Exporters ===")
print("Creating exporters that can process logs as they're generated:")

-- Create real-time exporters for each platform
local exporters = {}
for _, platform in ipairs(platforms) do
  local exporter, err = log_export.create_realtime_exporter(
    platform,
    {
      environment = "demo",
      service = "lust-next-example"
    }
  )
  
  if exporter then
    table.insert(exporters, exporter)
    print(string.format("  Created %s exporter", platform))
    
    -- Show HTTP endpoint if available
    if exporter.http_endpoint then
      print(string.format("    Endpoint: %s %s", 
        exporter.http_endpoint.method,
        exporter.http_endpoint.url))
      
      if exporter.http_endpoint.headers then
        print("    Headers:")
        for k, v in pairs(exporter.http_endpoint.headers) do
          if k ~= "Authorization" then  -- Don't show auth tokens
            print(string.format("      %s: %s", k, v))
          else
            print("      Authorization: [redacted]")
          end
        end
      end
    end
  else
    print(string.format("  Failed to create %s exporter: %s", platform, err or "unknown error"))
  end
end

-- Demonstrate using the exporters
print("\nDemonstrating real-time export:")
-- Create a sample log entry
local sample_log = {
  timestamp = os.date("%Y-%m-%dT%H:%M:%S"),
  level = "INFO",
  module = "realtime_export",
  message = "This log would be sent to external systems in real-time",
  params = {
    transaction_id = "tx-789",
    duration_ms = 50,
    status = "success"
  }
}

-- Process with each exporter
for _, exporter in ipairs(exporters) do
  local formatted = exporter.export(sample_log)
  print(string.format("  Exported to %s format", exporter.platform))
end

print("")
print("In a real application implementation:")
print("1. The real-time exporters would be configured during startup")
print("2. A custom log handler would process each log entry as it's generated")
print("3. HTTP requests would be sent to the configured endpoints")
print("4. Response status would be monitored for delivery confirmation")
print("")
print("The generated export files can be found in the logs/ directory:")
for _, platform in ipairs(platforms) do
  print(string.format("- export_%s.json - %s compatible format", platform, platform))
  print(string.format("- config_%s.conf - %s configuration", platform, platform))
end