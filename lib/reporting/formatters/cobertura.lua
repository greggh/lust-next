-- Cobertura XML formatter for coverage reports
local M = {}

local logging = require("lib.tools.logging")
local logger = logging.get_logger("Reporting:Cobertura")

-- Configure module logging
logging.configure_from_config("Reporting:Cobertura")

-- Default formatter configuration
local DEFAULT_CONFIG = {
  schema_version = "4.0",
  include_packages = true,
  include_branches = true,
  include_line_counts = true,
  add_xml_declaration = true,
  format_output = false,
  normalize_paths = true,
  include_sources = true
}

-- Get configuration for Cobertura formatter
local function get_config()
  -- Try to load the reporting module for configuration access
  local ok, reporting = pcall(require, "lib.reporting")
  if ok and reporting.get_formatter_config then
    local formatter_config = reporting.get_formatter_config("cobertura")
    if formatter_config then
      logger.debug("Using configuration from reporting module")
      return formatter_config
    end
  end
  
  -- If we can't get from reporting module, try central_config directly
  local success, central_config = pcall(require, "lib.core.central_config")
  if success then
    local formatter_config = central_config.get("reporting.formatters.cobertura")
    if formatter_config then
      logger.debug("Using configuration from central_config")
      return formatter_config
    end
  end
  
  -- Fall back to default configuration
  logger.debug("Using default configuration")
  return DEFAULT_CONFIG
end

-- Function to indent XML if formatting is enabled
local function format_xml(xml, config)
  if not config.format_output then
    return xml
  end
  
  -- Replace newlines with nothing to normalize the string
  local normalized = xml:gsub("\r\n", "\n"):gsub("\r", "\n")
  
  -- Initialize variables
  local formatted = ""
  local indent = 0
  
  -- Process each line
  for line in normalized:gmatch("[^\n]+") do
    local content = line:match("%s*(.-)%s*$")
    
    -- Detect if the line is an opening tag, a closing tag, or both
    local is_end_tag = content:match("^</")
    local is_self_closing = content:match("/>%s*$")
    local is_start_tag = content:match("^<[^/]") and not is_self_closing
    
    -- Adjust indentation based on tag type
    if is_end_tag then
      indent = indent - 1
    end
    
    -- Add indentation and content
    if indent > 0 then
      formatted = formatted .. string.rep("  ", indent)
    end
    formatted = formatted .. content .. "\n"
    
    -- Adjust indentation for next line
    if is_start_tag then
      indent = indent + 1
    end
  end
  
  return formatted
end

-- Helper function to escape XML special characters
local function escape_xml(str)
  if type(str) ~= "string" then
    return tostring(str or "")
  end
  
  return str:gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub("\"", "&quot;")
            :gsub("'", "&apos;")
end

-- Get current timestamp in ISO format
local function get_timestamp()
  local current_time = os.time()
  return os.date("%Y-%m-%dT%H:%M:%S", current_time)
end

-- Helper function to calculate line rate
local function calculate_line_rate(covered, total)
  if total == 0 then return 1.0 end
  return covered / total
end

-- Generate Cobertura XML coverage report
-- Format specification: https://github.com/cobertura/cobertura/wiki/XML-Format
function M.format_coverage(coverage_data)
  -- Get formatter configuration
  local config = get_config()
  
  logger.debug("Generating Cobertura XML coverage report", {
    has_data = coverage_data ~= nil,
    has_summary = coverage_data and coverage_data.summary ~= nil,
    schema_version = config.schema_version,
    include_packages = config.include_packages,
    include_branches = config.include_branches,
    include_line_counts = config.include_line_counts,
    format_output = config.format_output,
    normalize_paths = config.normalize_paths
  })
  
  -- Validate input
  if not coverage_data or not coverage_data.summary then
    logger.warn("Missing or invalid coverage data for Cobertura report, generating empty report")
    
    -- Build empty report with configuration options
    local xml = {}
    
    -- Add XML declaration if configured
    if config.add_xml_declaration then
      table.insert(xml, '<?xml version="1.0" encoding="UTF-8"?>')
    end
    
    -- Add DOCTYPE for specified schema version
    table.insert(xml, string.format('<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-%s.dtd">', 
                                    config.schema_version))
                                    
    -- Root coverage element
    table.insert(xml, '<coverage lines-valid="0" lines-covered="0" line-rate="0" branches-valid="0" ' ..
                       'branches-covered="0" branch-rate="0" timestamp="' .. os.time() .. '" complexity="0" ' ..
                       'version="' .. config.schema_version .. '">')
    
    -- Add sources if configured
    if config.include_sources then
      table.insert(xml, '  <sources><source>.</source></sources>')
    end
    
    -- Add empty packages
    table.insert(xml, '  <packages></packages>')
    table.insert(xml, '</coverage>')
    
    -- Format output if configured
    local output = table.concat(xml, '\n')
    if config.format_output then
      return format_xml(output, config)
    end
    
    return output
  end
  
  logger.debug("Formatting Cobertura XML for coverage data", {
    total_lines = coverage_data.summary.total_lines or 0,
    covered_lines = coverage_data.summary.covered_lines or 0,
    total_files = coverage_data.summary.total_files or 0,
    files_count = (function()
      -- Count files in a safer way than using deprecated table.getn
      local count = 0
      if coverage_data.files then
        for _ in pairs(coverage_data.files) do
          count = count + 1
        end
      end
      return count
    end)()
  })
  
  -- Get summary data
  local summary = coverage_data.summary
  local total_lines = summary.total_lines or 0
  local covered_lines = summary.covered_lines or 0
  local line_rate = calculate_line_rate(covered_lines, total_lines)
  
  -- Start building XML
  local output = {}
  
  -- Add XML declaration if configured
  if config.add_xml_declaration then
    table.insert(output, '<?xml version="1.0" encoding="UTF-8"?>')
  end
  
  -- Add DOCTYPE for specified schema version
  table.insert(output, string.format('<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-%s.dtd">', 
                                    config.schema_version))
  
  -- Create coverage element with attributes based on configuration
  local coverage_attrs = {}
  
  -- Add line coverage attributes if configured
  if config.include_line_counts then
    table.insert(coverage_attrs, string.format('lines-valid="%d"', total_lines))
    table.insert(coverage_attrs, string.format('lines-covered="%d"', covered_lines))
    table.insert(coverage_attrs, string.format('line-rate="%.4f"', line_rate))
  end
  
  -- Add branch coverage attributes if configured 
  if config.include_branches then
    local branch_valid = coverage_data.summary.total_branches or 0
    local branch_covered = coverage_data.summary.covered_branches or 0
    local branch_rate = branch_valid > 0 and (branch_covered / branch_valid) or 0
    
    table.insert(coverage_attrs, string.format('branches-valid="%d"', branch_valid))
    table.insert(coverage_attrs, string.format('branches-covered="%d"', branch_covered))
    table.insert(coverage_attrs, string.format('branch-rate="%.4f"', branch_rate))
  else
    -- Add zeros if branches not available
    table.insert(coverage_attrs, 'branches-valid="0"')
    table.insert(coverage_attrs, 'branches-covered="0"')
    table.insert(coverage_attrs, 'branch-rate="0"')
  end
  
  -- Add timestamp and version
  table.insert(coverage_attrs, string.format('timestamp="%d"', os.time()))
  table.insert(coverage_attrs, 'complexity="0"')
  table.insert(coverage_attrs, string.format('version="%s"', config.schema_version))
  
  -- Create the coverage element
  table.insert(output, '<coverage ' .. table.concat(coverage_attrs, ' ') .. '>')
  
  -- Add sources section if configured
  if config.include_sources then
    table.insert(output, '  <sources>')
    table.insert(output, '    <source>.</source>')
    table.insert(output, '  </sources>')
  end
  
  -- Start packages section
  table.insert(output, '  <packages>')
  
  -- Group files by "package" (directory)
  local packages = {}
  for filepath, file_data in pairs(coverage_data.files or {}) do
    -- Extract package (directory) from file path
    local package_path = "."
    
    -- Normalize path based on configuration
    local normalized_path = filepath
    if config.normalize_paths then
      normalized_path = filepath:gsub("\\", "/") -- Convert Windows paths to Unix style
      -- Remove ./ at the beginning if present
      normalized_path = normalized_path:gsub("^%./", "")
    else
      normalized_path = filepath
    end
    
    if normalized_path:find("/") then
      package_path = normalized_path:match("^(.+)/[^/]+$") or "."
    end
    
    -- Skip package grouping if not configured
    if not config.include_packages then
      package_path = "default"
    end
    
    if not packages[package_path] then
      packages[package_path] = {
        files = {},
        total_lines = 0,
        covered_lines = 0
      }
    end
    
    -- Add file to package
    packages[package_path].files[filepath] = file_data
    packages[package_path].total_lines = packages[package_path].total_lines + (file_data.total_lines or 0)
    packages[package_path].covered_lines = packages[package_path].covered_lines + (file_data.covered_lines or 0)
  end
  
  -- Generate XML for each package
  for package_path, package_data in pairs(packages) do
    local package_line_rate = calculate_line_rate(package_data.covered_lines, package_data.total_lines)
    
    table.insert(output, '    <package name="' .. escape_xml(package_path) .. 
                        '" line-rate="' .. string.format("%.4f", package_line_rate) .. 
                        '" branch-rate="0" complexity="0">')
    table.insert(output, '      <classes>')
    
    -- Add class (file) information
    for filepath, file_data in pairs(package_data.files) do
      local filename = filepath:match("([^/]+)$") or filepath
      local file_line_rate = calculate_line_rate(file_data.covered_lines or 0, file_data.total_lines or 0)
      
      table.insert(output, '        <class name="' .. escape_xml(filename) .. 
                          '" filename="' .. escape_xml(filepath) .. 
                          '" line-rate="' .. string.format("%.4f", file_line_rate) .. 
                          '" branch-rate="0" complexity="0">')
      
      -- Add methods section (empty for now since we don't track method-level coverage)
      table.insert(output, '          <methods/>')
      
      -- Add lines section
      table.insert(output, '          <lines>')
      
      -- Add line hits
      local line_hits = {}
      for line_num, is_covered in pairs(file_data.lines or {}) do
        table.insert(line_hits, {
          line = line_num,
          hits = is_covered and 1 or 0
        })
      end
      
      -- Sort lines by number
      table.sort(line_hits, function(a, b) return a.line < b.line end)
      
      -- Add lines to XML
      for _, line_info in ipairs(line_hits) do
        table.insert(output, '            <line number="' .. line_info.line .. 
                            '" hits="' .. line_info.hits .. 
                            '" branch="false"/>')
      end
      
      table.insert(output, '          </lines>')
      table.insert(output, '        </class>')
    end
    
    table.insert(output, '      </classes>')
    table.insert(output, '    </package>')
  end
  
  -- Close XML
  table.insert(output, '  </packages>')
  table.insert(output, '</coverage>')
  
  -- Join all lines and apply formatting if configured
  local result = table.concat(output, '\n')
  
  -- Apply XML formatting if enabled
  if config.format_output then
    return format_xml(result, config)
  end
  
  return result
end

-- Register formatter
return function(formatters)
  formatters.coverage.cobertura = M.format_coverage
end