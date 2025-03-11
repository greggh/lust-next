-- Log export module for lust-next
-- This module provides export mechanisms for external log analysis tools

local M = {}

-- Try to import filesystem module (might not be available during first load)
local fs
local function get_fs()
  if not fs then
    fs = require("lib.tools.filesystem")
  end
  return fs
end

-- Try to import JSON module if available
local json
local function get_json()
  if not json then
    -- Try to load JSON module
    local status, json_module = pcall(require, "lib.tools.json")
    if status then
      json = json_module
    else
      -- Fallback to simple JSON serialization
      json = {
        encode = function(val)
          if type(val) == "table" then
            local result = "{"
            local first = true
            for k, v in pairs(val) do
              if not first then result = result .. "," end
              result = result .. '"' .. tostring(k) .. '":' 
              if type(v) == "string" then
                result = result .. '"' .. v:gsub('"', '\\"') .. '"'
              elseif type(v) == "number" or type(v) == "boolean" then
                result = result .. tostring(v)
              elseif type(v) == "table" then
                result = result .. json.encode(v)
              else
                result = result .. '""'
              end
              first = false
            end
            return result .. "}"
          elseif type(val) == "string" then
            return '"' .. val:gsub('"', '\\"') .. '"'
          elseif type(val) == "number" or type(val) == "boolean" then
            return tostring(val)
          else
            return '""'
          end
        end
      }
    end
  end
  return json
end

-- Adapter collection for popular log analysis platforms
local adapters = {
  -- Common fields for all adapters
  common = {
    host = function() return os.getenv("HOSTNAME") or "unknown" end,
    timestamp = function() return os.date("%Y-%m-%dT%H:%M:%S") end
  },
  
  -- Logstash adapter
  logstash = {
    format = function(entry, options)
      options = options or {}
      return {
        ["@timestamp"] = entry.timestamp or M.adapters.common.timestamp(),
        ["@metadata"] = {
          type = options.type or "lust_log"
        },
        level = entry.level,
        module = entry.module,
        message = entry.message,
        params = entry.params,
        application = options.application_name or "lust-next",
        environment = options.environment or "development",
        host = options.host or M.adapters.common.host(),
        tags = options.tags or {}
      }
    end,
    
    http_endpoint = function(options)
      return {
        method = "POST",
        url = options.url or "http://localhost:5044",
        headers = {
          ["Content-Type"] = "application/json"
        }
      }
    end
  },
  
  -- Elasticsearch adapter
  elasticsearch = {
    format = function(entry, options)
      options = options or {}
      return {
        ["@timestamp"] = entry.timestamp or M.adapters.common.timestamp(),
        log = {
          level = entry.level,
          logger = entry.module
        },
        message = entry.message,
        params = entry.params,
        service = {
          name = options.service_name or "lust-next",
          environment = options.environment or "development"
        },
        host = {
          name = options.host or M.adapters.common.host()
        },
        tags = options.tags or {}
      }
    end,
    
    http_endpoint = function(options)
      options = options or {}
      local index = options.index or "logs-lust"
      return {
        method = "POST",
        url = (options.url or "http://localhost:9200") .. "/" .. index .. "/_doc",
        headers = {
          ["Content-Type"] = "application/json"
        }
      }
    end
  },
  
  -- Splunk adapter
  splunk = {
    format = function(entry, options)
      options = options or {}
      return {
        time = entry.timestamp or M.adapters.common.timestamp(),
        host = options.host or M.adapters.common.host(),
        source = options.source or "lust-next",
        sourcetype = options.sourcetype or "lust:log",
        index = options.index or "main",
        event = {
          level = entry.level,
          module = entry.module,
          message = entry.message,
          params = entry.params,
          environment = options.environment or "development"
        }
      }
    end,
    
    http_endpoint = function(options)
      return {
        method = "POST",
        url = options.url or "http://localhost:8088/services/collector/event",
        headers = {
          ["Content-Type"] = "application/json",
          ["Authorization"] = options.token and ("Splunk " .. options.token) or nil
        }
      }
    end
  },
  
  -- Datadog adapter
  datadog = {
    format = function(entry, options)
      options = options or {}
      
      -- Build tags string
      local tags = "env:" .. (options.environment or "development")
      if entry.module then
        tags = tags .. ",module:" .. entry.module
      end
      if options.tags then
        for k, v in pairs(options.tags) do
          if type(k) == "number" then
            tags = tags .. "," .. v
          else
            tags = tags .. "," .. k .. ":" .. v
          end
        end
      end
      
      return {
        timestamp = entry.timestamp or M.adapters.common.timestamp(),
        message = entry.message,
        level = entry.level and string.lower(entry.level) or "info",
        service = options.service or "lust-next",
        ddsource = "lust",
        ddtags = tags,
        hostname = options.hostname or M.adapters.common.host(),
        attributes = entry.params
      }
    end,
    
    http_endpoint = function(options)
      return {
        method = "POST",
        url = options.url or "https://http-intake.logs.datadoghq.com/v1/input",
        headers = {
          ["Content-Type"] = "application/json",
          ["DD-API-KEY"] = options.api_key or ""
        }
      }
    end
  },
  
  -- Grafana Loki adapter
  loki = {
    format = function(entry, options)
      options = options or {}
      
      -- Prepare labels
      local labels = {
        level = entry.level and string.lower(entry.level) or "info",
        app = "lust-next",
        env = options.environment or "development"
      }
      
      if entry.module then
        labels.module = entry.module
      end
      
      if options.labels then
        for k, v in pairs(options.labels) do
          labels[k] = v
        end
      end
      
      -- Format label string {key="value",key2="value2"}
      local label_str = "{"
      local first = true
      for k, v in pairs(labels) do
        if not first then label_str = label_str .. "," end
        label_str = label_str .. k .. '="' .. tostring(v):gsub('"', '\\"') .. '"'
        first = false
      end
      label_str = label_str .. "}"
      
      -- Format entry
      local timestamp_ns = os.time() * 1000000000 -- seconds to nanoseconds
      local formatted_entry = {
        streams = {
          {
            stream = labels,
            values = {
              {
                tostring(timestamp_ns),
                entry.message or ""
              }
            }
          }
        }
      }
      
      return formatted_entry
    end,
    
    http_endpoint = function(options)
      return {
        method = "POST",
        url = (options.url or "http://localhost:3100") .. "/loki/api/v1/push",
        headers = {
          ["Content-Type"] = "application/json"
        }
      }
    end
  }
}

-- Make adapters available externally
M.adapters = adapters

-- Export logs to an external platform
function M.export_to_platform(entries, platform, options)
  options = options or {}
  
  -- Get platform adapter
  local adapter = adapters[platform]
  if not adapter then
    return nil, "Unsupported platform: " .. platform
  end
  
  -- Format entries
  local formatted_entries = {}
  for i, entry in ipairs(entries) do
    formatted_entries[i] = adapter.format(entry, options)
  end
  
  -- Return formatted entries
  return formatted_entries
end

-- Create a log file in a format suitable for a specific platform
function M.create_platform_file(log_file, platform, output_file, options)
  options = options or {}
  
  local fs = get_fs()
  if not fs then
    return nil, "Filesystem module not available"
  end
  
  -- Check if source file exists
  if not fs.file_exists(log_file) then
    return nil, "Log file does not exist: " .. log_file
  end
  
  -- Get platform adapter
  local adapter = adapters[platform]
  if not adapter then
    return nil, "Unsupported platform: " .. platform
  end
  
  -- Determine source log format (text or JSON)
  local is_json_source = log_file:match("%.json$") or options.source_format == "json"
  
  -- Read source log file
  local source_content, err = fs.read_file(log_file)
  if not source_content then
    return nil, "Failed to read source log file: " .. (err or "unknown error")
  end
  
  -- Prepare output content (will be written at the end)
  local output_content = ""
  
  -- Parse functions for different log formats
  local function parse_json_log_line(line)
    if not line or line:sub(1, 1) ~= "{" then return nil end
    
    -- Simple extraction of fields from JSON
    local timestamp = line:match('"timestamp":"([^"]*)"')
    local level = line:match('"level":"([^"]*)"')
    local module = line:match('"module":"([^"]*)"')
    local message = line:match('"message":"([^"]*)"')
    
    -- Try to parse additional parameters
    local params = {}
    for k, v in line:gmatch('"([^",:]*)":"([^"]*)"') do
      if k ~= "timestamp" and k ~= "level" and k ~= "module" and k ~= "message" then
        params[k] = v
      end
    end
    
    return {
      timestamp = timestamp,
      level = level,
      module = module,
      message = message,
      params = params,
      raw = line
    }
  end
  
  local function parse_text_log_line(line)
    if not line then return nil end
    
    -- Parse timestamp
    local timestamp = line:match("^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d)")
    
    -- Parse log level
    local level = line:match(" | ([A-Z]+) | ")
    
    -- Parse module name
    local module = line:match(" | [A-Z]+ | ([^|]+) | ")
    
    -- Parse message (everything after module)
    local message
    if module then
      message = line:match(" | [A-Z]+ | [^|]+ | (.+)")
    else
      message = line:match(" | [A-Z]+ | (.+)")
    end
    
    -- Parse parameters if present
    local params = {}
    local params_str = message and message:match("%([^)]+%)$")
    if params_str then
      -- Extract parameters from parentheses
      for k, v in params_str:gmatch("([%w_]+)=([^,)]+)") do
        params[k] = v
      end
      
      -- Clean up message
      message = message:gsub("%([^)]+%)$", ""):gsub("%s+$", "")
    end
    
    return {
      timestamp = timestamp,
      level = level,
      module = module and module:gsub("%s+$", ""),
      message = message,
      params = params,
      raw = line
    }
  end
  
  -- Get JSON module
  local json = get_json()
  if not json then
    source_file:close()
    output:close()
    return nil, "JSON module not available and fallback failed"
  end
  
  -- Process each line
  local count = 0
  local entries = {}
  
  -- Split content into lines and process each one
  for line in source_content:gmatch("([^\r\n]+)[\r\n]*") do
    local log_entry
    
    -- Parse based on format
    if is_json_source then
      log_entry = parse_json_log_line(line)
    else
      log_entry = parse_text_log_line(line)
    end
    
    -- Process entries that were successfully parsed
    if log_entry then
      count = count + 1
      
      -- Format for the target platform
      local formatted = adapter.format(log_entry, options)
      table.insert(entries, formatted)
      
      -- Add to output content
      output_content = output_content .. json.encode(formatted) .. "\n"
    end
  end
  
  -- Write the complete output content to file
  local success, write_err = fs.write_file(output_file, output_content)
  if not success then
    return nil, "Failed to write output file: " .. (write_err or "unknown error")
  end
  
  return {
    entries_processed = count,
    output_file = output_file,
    entries = entries
  }
end

-- Create a configuration file for the specified platform
function M.create_platform_config(platform, output_file, options)
  options = options or {}
  
  -- Get platform adapter
  local adapter = adapters[platform]
  if not adapter then
    return nil, "Unsupported platform: " .. platform
  end
  
  -- Get filesystem module
  local fs = get_fs()
  if not fs then
    return nil, "Filesystem module not available"
  end
  
  -- Ensure parent directory exists
  local parent_dir = output_file:match("(.+)/[^/]+$")
  if parent_dir then
    fs.ensure_directory_exists(parent_dir)
  end
  
  -- Create output file
  local output, err = io.open(output_file, "w")
  if not output then
    return nil, "Failed to create output file: " .. (err or "unknown error")
  end
  
  -- Write platform-specific configuration
  if platform == "logstash" then
    output:write([[
input {
  file {
    path => "logs/lust-next.json"
    codec => "json"
    type => "lust-next"
  }
}

filter {
  if [type] == "lust-next" {
    date {
      match => [ "@timestamp", "ISO8601" ]
    }
    
    # Extract module for better filtering
    if [module] {
      mutate {
        add_field => { "[@metadata][module]" => "%{module}" }
      }
    }
    
    # Set log level as a tag for filtering
    if [level] {
      mutate {
        add_tag => [ "%{level}" ]
      }
    }
  }
}

output {
  if [type] == "lust-next" {
    elasticsearch {
      hosts => ["]] .. (options.es_host or "localhost:9200") .. [["]
      index => "lust-next-%{+YYYY.MM.dd}"
    }
    
    # Uncomment to enable stdout output for debugging
    # stdout { codec => rubydebug }
  }
}
]])
  elseif platform == "elasticsearch" then
    output:write([[
{
  "index_patterns": ["lust-next-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "index.refresh_interval": "5s"
    },
    "mappings": {
      "properties": {
        "@timestamp": { "type": "date" },
        "log.level": { "type": "keyword" },
        "log.logger": { "type": "keyword" },
        "message": { "type": "text" },
        "service.name": { "type": "keyword" },
        "service.environment": { "type": "keyword" },
        "host.name": { "type": "keyword" },
        "tags": { "type": "keyword" }
      }
    }
  }
}
]])
  elseif platform == "splunk" then
    output:write([[
[lust_logs]
DATETIME_CONFIG = 
INDEXED_EXTRACTIONS = json
KV_MODE = none
LINE_BREAKER = ([\r\n]+)
NO_BINARY_CHECK = true
category = Custom
disabled = false
pulldown_type = true
TIME_FORMAT = %Y-%m-%dT%H:%M:%S
TIME_PREFIX = "time":"
]])
  elseif platform == "datadog" then
    output:write([[
# Datadog Agent configuration for lust-next logs
logs:
  - type: file
    path: "logs/lust-next.json"
    service: "]] .. (options.service or "lust-next") .. [["
    source: "lust"
    sourcecategory: "logging"
    log_processing_rules:
      - type: multi_line
        name: log_start_with_date
        pattern: \d{4}-\d{2}-\d{2}
    json:
      message: message
      service: service
      ddsource: ddsource
      ddtags: ddtags
      hostname: hostname
      level: level
]])
  elseif platform == "loki" then
    output:write([[
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /tmp/loki/boltdb-shipper-active
    cache_location: /tmp/loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /tmp/loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
]])
  else
    output:close()
    return nil, "No configuration template available for platform: " .. platform
  end
  
  -- Close output file
  output:close()
  
  return {
    config_file = output_file,
    platform = platform
  }
end

-- Create a real-time log exporter
function M.create_realtime_exporter(platform, options)
  options = options or {}
  
  -- Get platform adapter
  local adapter = adapters[platform]
  if not adapter then
    return nil, "Unsupported platform: " .. platform
  end
  
  -- Define export function
  local function export_entry(entry)
    -- Format for the target platform
    local formatted = adapter.format(entry, options)
    
    -- In a real implementation, this would send to an external service
    -- For this example, we'll just return the formatted entry
    return formatted
  end
  
  -- Return the exporter
  return {
    export = export_entry,
    platform = platform,
    http_endpoint = adapter.http_endpoint and adapter.http_endpoint(options) or nil
  }
end

-- Get list of supported platforms
function M.get_supported_platforms()
  local platforms = {}
  for k, _ in pairs(adapters) do
    if k ~= "common" then
      table.insert(platforms, k)
    end
  end
  return platforms
end

return M