---@class CoberturaFormatter
---@field format_coverage fun(coverage_data: {files: table<string, {lines: table<number, {executable: boolean, executed: boolean, covered: boolean, source: string}>, stats: {total: number, covered: number, executable: number, percentage: number}}>, summary: {total_lines: number, executed_lines: number, covered_lines: number, coverage_percentage: number}}): string|nil, table? Format coverage data as Cobertura XML
---@field get_config fun(): CoberturaFormatterConfig Get current formatter configuration
---@field set_config fun(config: table): boolean Set formatter configuration options
---@field escape_xml fun(str: any): string Escape special characters in string for XML output
-- Cobertura XML formatter for coverage reports that produces XML compatible with
-- the Cobertura coverage reporting format, widely used by CI/CD systems
local M = {}

local logging = require("lib.tools.logging")
local logger = logging.get_logger("Reporting:Cobertura")

-- Add error_handler dependency
local error_handler = require("lib.tools.error_handler")

-- Configure module logging
logging.configure_from_config("Reporting:Cobertura")

---@class CoberturaFormatterConfig
---@field schema_version string XML schema version to use in output (e.g. "4.0")
---@field include_packages boolean Whether to include package information in XML structure
---@field include_branches boolean Whether to include branch coverage data (even if not available)
---@field include_line_counts boolean Whether to include line counts in XML summary
---@field add_xml_declaration boolean Whether to add XML declaration at the top of output (<?xml ...?>)
---@field format_output boolean Whether to format the output with indentation for readability
---@field normalize_paths boolean Whether to normalize file paths (convert backslashes, remove unnecessary parts)
---@field include_sources boolean Whether to include source file paths in XML output
---@field project_name? string Optional project name to include in coverage report
---@field timestamp? string Optional timestamp to include in coverage report (ISO format)
---@field source_encoding? string Optional source encoding to specify in XML

-- Default formatter configuration
---@type CoberturaFormatterConfig
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

---@private
---@return CoberturaFormatterConfig config The configuration for the Cobertura formatter
-- Retrieves configuration for the Cobertura formatter with the following priority:
-- 1. From the reporting module's formatter-specific configuration
-- 2. From the central_config system's formatter-specific configuration
-- 3. Falls back to default configuration if neither is available
-- Handles errors gracefully during configuration retrieval
local function get_config()
  -- Try to load the reporting module for configuration access
  local success, result, err = error_handler.try(function()
    local reporting = require("lib.reporting")
    if reporting.get_formatter_config then
      local formatter_config = reporting.get_formatter_config("cobertura")
      if formatter_config then
        logger.debug("Using configuration from reporting module")
        return formatter_config
      end
    end
    return nil
  end)
  
  if success and result then
    return result
  end
  
  -- If we can't get from reporting module, try central_config directly
  local config_success, config_result = error_handler.try(function()
    local central_config = require("lib.core.central_config")
    local formatter_config = central_config.get("reporting.formatters.cobertura")
    if formatter_config then
      logger.debug("Using configuration from central_config")
      return formatter_config
    end
    return nil
  end)
  
  if config_success and config_result then
    return config_result
  end
  
  -- Fall back to default configuration
  logger.debug("Using default configuration", {
    reason = "Could not load from reporting or central_config",
    module = "reporting.formatters.cobertura"
  })
  
  return DEFAULT_CONFIG
end

---@private
---@param xml string Raw XML string to format
---@param config CoberturaFormatterConfig|nil Configuration for the formatter
---@return string formatted_xml Indented XML if formatting is enabled, otherwise the original XML
-- Formats XML with proper indentation if config.format_output is enabled
-- The function analyzes XML tag structure to properly indent based on tag nesting
-- Handles opening tags, closing tags, and self-closing tags
-- Preserves content between tags and maintains original tag content
-- Falls back to the original XML string if formatting fails for any reason
local function format_xml(xml, config)
  if not config or not config.format_output then
    return xml
  end
  
  local success, formatted_result = error_handler.try(function()
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
  end)
  
  if success then
    return formatted_result
  else
    -- If formatting fails, log the error and return the original XML
    local err = error_handler.runtime_error(
      "Failed to format XML output",
      {
        operation = "format_xml",
        xml_length = #xml,
        module = "reporting.formatters.cobertura"
      },
      formatted_result
    )
    logger.warn(err.message, err.context)
    return xml  -- Return unformatted XML as fallback
  end
end

---@private
---@param str any Value to escape (will be converted to string if not a string)
---@return string escaped_string The XML-escaped string
-- Helper function to escape XML special characters
local function escape_xml(str)
  -- Handle nil or non-string values safely
  if type(str) ~= "string" then
    local safe_str = tostring(str or "")
    logger.debug("Converting non-string value to string for XML escaping", {
      original_type = type(str),
      result_length = #safe_str
    })
    str = safe_str
  end
  
  -- Use error handling for the string operations
  local success, result = error_handler.try(function()
    return str:gsub("&", "&amp;")
              :gsub("<", "&lt;")
              :gsub(">", "&gt;")
              :gsub("\"", "&quot;")
              :gsub("'", "&apos;")
  end)
  
  if success then
    return result
  else
    -- If string operations fail, log the error and return a safe alternative
    local err = error_handler.runtime_error(
      "Failed to escape XML string",
      {
        operation = "escape_xml",
        module = "reporting.formatters.cobertura",
        string_length = #str
      },
      result -- On failure, result contains the error
    )
    logger.warn(err.message, err.context)
    
    -- Use fallback with individual replacements for better robustness
    local fallback_success, fallback_result = error_handler.try(function()
      local result = str
      result = result:gsub("&", "&amp;")
      result = result:gsub("<", "&lt;")
      result = result:gsub(">", "&gt;")
      result = result:gsub("\"", "&quot;")
      result = result:gsub("'", "&apos;")
      return result
    end)
    
    if fallback_success then
      return fallback_result
    else
      -- If even the fallback fails, return a sanitized string
      logger.error("XML escaping fallback also failed, using basic sanitization", {
        error = error_handler.format_error(fallback_result)
      })
      -- Return the original string with basic sanitization
      return "(sanitized content)"
    end
  end
end

---@private
---@return string timestamp Current timestamp in ISO format
-- Get current timestamp in ISO format
local function get_timestamp()
  local success, result = error_handler.try(function()
    local current_time = os.time()
    return os.date("%Y-%m-%dT%H:%M:%S", current_time)
  end)
  
  if success then
    return result
  else
    -- If timestamp generation fails, use a safe default
    logger.warn("Failed to generate timestamp, using default", {
      error = error_handler.format_error(result)
    })
    return "1970-01-01T00:00:00"
  end
end

---@private
---@param covered number|string Number of covered lines
---@param total number|string Total number of lines
---@return number line_rate Line coverage rate (0-1)
-- Helper function to calculate line rate
local function calculate_line_rate(covered, total)
  local success, result = error_handler.try(function()
    -- Validate inputs
    covered = tonumber(covered) or 0
    total = tonumber(total) or 0
    
    if total == 0 then 
      return 1.0 
    end
    
    return covered / total
  end)
  
  if success then
    return result
  else
    -- If calculation fails, log the error and return a safe default
    local err = error_handler.runtime_error(
      "Failed to calculate line rate",
      {
        operation = "calculate_line_rate",
        covered = covered,
        total = total,
        module = "reporting.formatters.cobertura"
      },
      result
    )
    logger.warn(err.message, err.context)
    
    -- Return a safe default value
    return 0.0
  end
end

---@param coverage_data table|nil Coverage data from the coverage module
---@return string xml_output XML representation of the coverage report in Cobertura format
-- Generate Cobertura XML coverage report
-- Format specification: https://github.com/cobertura/cobertura/wiki/XML-Format
function M.format_coverage(coverage_data)
  -- Validate input parameter
  if not coverage_data then
    local err = error_handler.validation_error(
      "Missing coverage data parameter",
      {
        operation = "format_coverage",
        module = "reporting.formatters.cobertura"
      }
    )
    logger.warn(err.message, err.context)
    -- Continue with empty report generation
  end
  
  -- Get formatter configuration with error handling
  local config_success, config, config_err = error_handler.try(function()
    return get_config()
  end)
  
  local config = DEFAULT_CONFIG
  if config_success and config then
    -- Use the successfully retrieved config
  else
    -- Log error and use default config
    local err = error_handler.runtime_error(
      "Failed to get Cobertura formatter configuration",
      {
        operation = "format_coverage",
        module = "reporting.formatters.cobertura"
      },
      config -- On failure, config contains the error
    )
    logger.warn(err.message, err.context)
  end
  
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
    logger.warn("Missing or invalid coverage data for Cobertura report, generating empty report", {
      has_data = coverage_data ~= nil,
      has_summary = coverage_data and coverage_data.summary ~= nil
    })
    
    -- Build empty report with configuration options using error handling
    local empty_report_success, empty_report = error_handler.try(function()
      local xml = {}
      
      -- Add XML declaration if configured
      if config.add_xml_declaration then
        table.insert(xml, '<?xml version="1.0" encoding="UTF-8"?>')
      end
      
      -- Add DOCTYPE for specified schema version
      table.insert(xml, string.format('<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-%s.dtd">', 
                                      config.schema_version))
                                      
      -- Root coverage element
      local timestamp_value = tostring(os.time())
      local safe_timestamp = error_handler.try(function() return os.time() end)
      if safe_timestamp then
        timestamp_value = tostring(safe_timestamp)
      end
      
      table.insert(xml, '<coverage lines-valid="0" lines-covered="0" line-rate="0" branches-valid="0" ' ..
                         'branches-covered="0" branch-rate="0" timestamp="' .. timestamp_value .. '" complexity="0" ' ..
                         'version="' .. escape_xml(config.schema_version) .. '">')
      
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
    end)
    
    if empty_report_success then
      return empty_report
    else
      -- If empty report generation fails, return a minimal valid XML document
      local err = error_handler.runtime_error(
        "Failed to generate empty Cobertura report",
        {
          operation = "format_coverage",
          module = "reporting.formatters.cobertura"
        },
        empty_report
      )
      logger.error(err.message, err.context)
      
      return '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-4.0.dtd">\n<coverage lines-valid="0" lines-covered="0" line-rate="0" branches-valid="0" branches-covered="0" branch-rate="0" timestamp="0" complexity="0" version="4.0"><packages></packages></coverage>'
    end
  end
  
  -- Safe file count calculation
  local files_count = 0
  local count_success, count_result = error_handler.try(function()
    local count = 0
    if coverage_data.files then
      for _ in pairs(coverage_data.files) do
        count = count + 1
      end
    end
    return count
  end)
  
  if count_success then
    files_count = count_result
  end
  
  logger.debug("Formatting Cobertura XML for coverage data", {
    total_lines = coverage_data.summary.total_lines or 0,
    covered_lines = coverage_data.summary.covered_lines or 0,
    total_files = coverage_data.summary.total_files or 0,
    files_count = files_count
  })
  
  -- Extract summary data with error handling
  local extract_success, summary_data = error_handler.try(function()
    -- Get summary data
    local summary = coverage_data.summary or {}
    local total_lines = tonumber(summary.total_lines) or 0
    local covered_lines = tonumber(summary.covered_lines) or 0
    
    -- Safely calculate line rate
    local line_rate = calculate_line_rate(covered_lines, total_lines)
    
    return {
      total_lines = total_lines,
      covered_lines = covered_lines,
      line_rate = line_rate
    }
  end)
  
  local summary = { total_lines = 0, covered_lines = 0, line_rate = 0 }
  if extract_success and summary_data then
    summary = summary_data
  else
    -- If extraction fails, log the error
    local err = error_handler.runtime_error(
      "Failed to extract summary data for Cobertura report",
      {
        operation = "format_coverage",
        module = "reporting.formatters.cobertura",
        has_summary = coverage_data and coverage_data.summary ~= nil
      },
      summary_data
    )
    logger.warn(err.message, err.context)
  end
  
  -- Start building XML with error handling
  local xml_success, output_elements = error_handler.try(function()
    local output = {}
    
    -- Add XML declaration if configured
    if config.add_xml_declaration then
      table.insert(output, '<?xml version="1.0" encoding="UTF-8"?>')
    end
    
    -- Add DOCTYPE for specified schema version
    table.insert(output, string.format('<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-%s.dtd">', 
                                      escape_xml(config.schema_version)))
    
    -- Create coverage element with attributes based on configuration
    local coverage_attrs = {}
    
    -- Add line coverage attributes if configured
    if config.include_line_counts then
      table.insert(coverage_attrs, string.format('lines-valid="%d"', summary.total_lines))
      table.insert(coverage_attrs, string.format('lines-covered="%d"', summary.covered_lines))
      table.insert(coverage_attrs, string.format('line-rate="%.4f"', summary.line_rate))
    end
    
    -- Add branch coverage attributes if configured 
    if config.include_branches then
      local branch_valid = tonumber(coverage_data.summary.total_branches) or 0
      local branch_covered = tonumber(coverage_data.summary.covered_branches) or 0
      local branch_rate = 0
      
      -- Safe branch rate calculation
      if branch_valid > 0 then
        local calc_success, br_rate = error_handler.try(function()
          return branch_covered / branch_valid
        end)
        
        if calc_success then
          branch_rate = br_rate
        end
      end
      
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
    local timestamp = "0"
    local timestamp_success, timestamp_result = error_handler.try(function()
      return tostring(os.time())
    end)
    
    if timestamp_success then
      timestamp = timestamp_result
    end
    
    table.insert(coverage_attrs, 'timestamp="' .. timestamp .. '"')
    table.insert(coverage_attrs, 'complexity="0"')
    table.insert(coverage_attrs, 'version="' .. escape_xml(config.schema_version) .. '"')
    
    -- Create the coverage element
    local attrs_join_success, attrs_str = error_handler.try(function()
      return table.concat(coverage_attrs, ' ')
    end)
    
    if attrs_join_success then
      table.insert(output, '<coverage ' .. attrs_str .. '>')
    else
      -- Fallback if joining fails
      table.insert(output, '<coverage lines-valid="0" lines-covered="0" line-rate="0" branches-valid="0" branches-covered="0" branch-rate="0" timestamp="0" complexity="0" version="' .. escape_xml(config.schema_version) .. '">')
    end
    
    -- Add sources section if configured
    if config.include_sources then
      table.insert(output, '  <sources>')
      table.insert(output, '    <source>.</source>')
      table.insert(output, '  </sources>')
    end
    
    return output
  end)
  
  local output = {}
  if xml_success and output_elements then
    output = output_elements
  else
    -- If XML building fails, log the error and start with a minimal valid document
    local err = error_handler.runtime_error(
      "Failed to build basic XML structure for Cobertura report",
      {
        operation = "format_coverage",
        module = "reporting.formatters.cobertura"
      },
      output_elements
    )
    logger.error(err.message, err.context)
    
    -- Create minimal valid XML structure
    if config.add_xml_declaration then
      table.insert(output, '<?xml version="1.0" encoding="UTF-8"?>')
    end
    table.insert(output, '<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-4.0.dtd">')
    table.insert(output, '<coverage lines-valid="0" lines-covered="0" line-rate="0" branches-valid="0" branches-covered="0" branch-rate="0" timestamp="0" complexity="0" version="4.0">')
    if config.include_sources then
      table.insert(output, '  <sources><source>.</source></sources>')
    end
  end
  
  -- Process packages with error handling
  local packages_success, packages_xml = error_handler.try(function()
    -- Start packages section
    local packages_elements = {'  <packages>'}
    
    -- Group files by "package" (directory)
    local packages = {}
    for filepath, file_data in pairs(coverage_data.files or {}) do
      -- Skip if file_data is nil
      if not file_data then
        logger.warn("Nil file data encountered, skipping file", {
          filepath = filepath
        })
        goto continue
      end
      
      -- Extract package (directory) from file path
      local package_path = "."
      
      -- Normalize path based on configuration
      local normalized_path = filepath
      if config.normalize_paths then
        -- Normalize with error handling
        local normalize_success, norm_result = error_handler.try(function()
          local result = filepath:gsub("\\", "/") -- Convert Windows paths to Unix style
          -- Remove ./ at the beginning if present
          result = result:gsub("^%./", "")
          return result
        end)
        
        if normalize_success then
          normalized_path = norm_result
        else
          logger.warn("Path normalization failed, using original path", {
            filepath = filepath,
            error = error_handler.format_error(norm_result)
          })
        end
      end
      
      -- Extract package path with error handling
      local extract_pkg_success, pkg_path = error_handler.try(function()
        if normalized_path:find("/") then
          return normalized_path:match("^(.+)/[^/]+$") or "."
        end
        return "."
      end)
      
      if extract_pkg_success then
        package_path = pkg_path
      else
        package_path = "."
      end
      
      -- Skip package grouping if not configured
      if not config.include_packages then
        package_path = "default"
      end
      
      -- Initialize package data
      if not packages[package_path] then
        packages[package_path] = {
          files = {},
          total_lines = 0,
          covered_lines = 0
        }
      end
      
      -- Add file to package with error handling
      local add_file_success, _ = error_handler.try(function()
        packages[package_path].files[filepath] = file_data
        packages[package_path].total_lines = packages[package_path].total_lines + (tonumber(file_data.total_lines) or 0)
        packages[package_path].covered_lines = packages[package_path].covered_lines + (tonumber(file_data.covered_lines) or 0)
        return true
      end)
      
      if not add_file_success then
        logger.warn("Failed to add file to package, skipping file", {
          filepath = filepath,
          package_path = package_path
        })
      end
      
      ::continue::
    end
    
    -- Generate XML for each package
    for package_path, package_data in pairs(packages) do
      -- Calculate package line rate with error handling
      local package_line_rate = calculate_line_rate(package_data.covered_lines, package_data.total_lines)
      
      -- Add package element
      local pkg_format_success, pkg_element = error_handler.try(function()
        return string.format('    <package name="%s" line-rate="%.4f" branch-rate="0" complexity="0">',
          escape_xml(package_path),
          package_line_rate)
      end)
      
      if pkg_format_success then
        table.insert(packages_elements, pkg_element)
      else
        -- Use fallback if formatting fails
        table.insert(packages_elements, '    <package name="' .. escape_xml(package_path) .. 
                         '" line-rate="0" branch-rate="0" complexity="0">')
      end
      
      table.insert(packages_elements, '      <classes>')
      
      -- Add class (file) information
      for filepath, file_data in pairs(package_data.files) do
        -- Skip if file_data is nil
        if not file_data then goto continue_file end
        
        -- Extract filename with error handling
        local filename = filepath
        local extract_name_success, name_result = error_handler.try(function()
          return filepath:match("([^/]+)$") or filepath
        end)
        
        if extract_name_success then
          filename = name_result
        end
        
        -- Calculate file line rate with error handling
        local file_line_rate = calculate_line_rate(
          tonumber(file_data.covered_lines) or 0, 
          tonumber(file_data.total_lines) or 0
        )
        
        -- Format class element with error handling
        local class_format_success, class_element = error_handler.try(function()
          return string.format('        <class name="%s" filename="%s" line-rate="%.4f" branch-rate="0" complexity="0">',
            escape_xml(filename),
            escape_xml(filepath),
            file_line_rate)
        end)
        
        if class_format_success then
          table.insert(packages_elements, class_element)
        else
          -- Use fallback if formatting fails
          table.insert(packages_elements, '        <class name="' .. escape_xml(filename) .. 
                           '" filename="' .. escape_xml(filepath) .. 
                           '" line-rate="0" branch-rate="0" complexity="0">')
        end
        
        -- Add methods section
        table.insert(packages_elements, '          <methods/>')
        
        -- Add lines section
        table.insert(packages_elements, '          <lines>')
        
        -- Add line hits with error handling
        local add_lines_success, lines_elements = error_handler.try(function()
          local line_elements = {}
          local line_hits = {}
          
          -- Collect line hits
          if file_data.lines then
            for line_num, is_covered in pairs(file_data.lines) do
              table.insert(line_hits, {
                line = tonumber(line_num) or 0,
                hits = is_covered and 1 or 0
              })
            end
            
            -- Sort lines by number
            table.sort(line_hits, function(a, b) return a.line < b.line end)
            
            -- Format line elements
            for _, line_info in ipairs(line_hits) do
              table.insert(line_elements, string.format('            <line number="%d" hits="%d" branch="false"/>',
                line_info.line,
                line_info.hits))
            end
          end
          
          return line_elements
        end)
        
        if add_lines_success and lines_elements then
          -- Add all line elements
          for _, line_element in ipairs(lines_elements) do
            table.insert(packages_elements, line_element)
          end
        else
          -- Add placeholder if line addition fails
          logger.warn("Failed to add line hits for file", {
            filepath = filepath,
            error = error_handler.format_error(lines_elements)
          })
          table.insert(packages_elements, '            <!-- Failed to process line information -->')
        end
        
        table.insert(packages_elements, '          </lines>')
        table.insert(packages_elements, '        </class>')
        
        ::continue_file::
      end
      
      table.insert(packages_elements, '      </classes>')
      table.insert(packages_elements, '    </package>')
    end
    
    -- Add closing packages element
    table.insert(packages_elements, '  </packages>')
    
    return packages_elements
  end)
  
  if packages_success and packages_xml then
    -- Add package elements to output
    for _, element in ipairs(packages_xml) do
      table.insert(output, element)
    end
  else
    -- Add empty packages section if processing fails
    local err = error_handler.runtime_error(
      "Failed to process packages for Cobertura report",
      {
        operation = "format_coverage",
        module = "reporting.formatters.cobertura",
        files_count = coverage_data.files and table.concat(coverage_data.files) or 0
      },
      packages_xml
    )
    logger.error(err.message, err.context)
    
    table.insert(output, '  <packages>')
    table.insert(output, '    <!-- Failed to process packages -->')
    table.insert(output, '  </packages>')
  end
  
  -- Close coverage element
  table.insert(output, '</coverage>')
  
  -- Join all lines and apply formatting with error handling
  local join_success, result = error_handler.try(function()
    return table.concat(output, '\n')
  end)
  
  if not join_success or not result then
    -- If joining fails, log the error and return a minimal valid document
    local err = error_handler.runtime_error(
      "Failed to join XML elements for Cobertura report",
      {
        operation = "format_coverage",
        element_count = #output,
        module = "reporting.formatters.cobertura"
      },
      result
    )
    logger.error(err.message, err.context)
    
    return '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-4.0.dtd">\n<coverage lines-valid="0" lines-covered="0" line-rate="0" branches-valid="0" branches-covered="0" branch-rate="0" timestamp="0" complexity="0" version="4.0"><packages></packages></coverage>'
  end
  
  -- Apply XML formatting if enabled
  if config.format_output then
    local format_success, formatted_output = error_handler.try(function()
      return format_xml(result, config)
    end)
    
    if format_success then
      return formatted_output
    else
      -- If formatting fails, log the error and return the unformatted output
      local err = error_handler.runtime_error(
        "Failed to format XML output for Cobertura report",
        {
          operation = "format_coverage",
          output_length = #result,
          module = "reporting.formatters.cobertura"
        },
        formatted_output
      )
      logger.warn(err.message, err.context)
      
      return result  -- Return unformatted output as fallback
    end
  end
  
  return result
end

---@param formatters table Table of formatter registries
---@return boolean success True if registration was successful
---@return table|nil error Error object if registration failed
-- Register formatter
return function(formatters)
  -- Validate parameters
  if not formatters then
    local err = error_handler.validation_error(
      "Missing required formatters parameter",
      {
        operation = "register_cobertura_formatter",
        module = "reporting.formatters.cobertura"
      }
    )
    logger.error(err.message, err.context)
    return false, err
  end
  
  -- Use try/catch pattern for the registration
  local success, result = error_handler.try(function()
    -- Initialize coverage formatters if needed
    formatters.coverage = formatters.coverage or {}
    formatters.coverage.cobertura = M.format_coverage
    
    logger.debug("Cobertura formatter registered successfully", {
      formatter_type = "coverage",
      module = "reporting.formatters.cobertura"
    })
    
    return true
  end)
  
  if not success then
    -- If registration fails, log the error and return false
    local err = error_handler.runtime_error(
      "Failed to register Cobertura formatter",
      {
        operation = "register_cobertura_formatter",
        module = "reporting.formatters.cobertura"
      },
      result -- On failure, result contains the error
    )
    logger.error(err.message, err.context)
    return false, err
  end
  
  return true
end