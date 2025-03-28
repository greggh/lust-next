---@class HTMLReporter
---@field generate fun(data: table, options: table): boolean|nil, table|nil Generate an HTML coverage report
---@field _VERSION string Module version
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local central_config = require("lib.core.central_config")
local fs = require("lib.tools.filesystem")

-- Version
M._VERSION = "3.0.0"

-- HTML Templates
local REPORT_TEMPLATE = [[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{title}}</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
  <style>
    :root {
      --covered-color: {{covered_color}};
      --executed-color: {{executed_color}};
      --not-covered-color: {{not_covered_color}};
    }
    
    .covered { background-color: var(--covered-color); }
    .executed { background-color: var(--executed-color); }
    .not-covered { background-color: var(--not-covered-color); }
    
    pre { tab-size: 4; }
  </style>
</head>
<body class="bg-gray-100 text-gray-900 dark:bg-gray-900 dark:text-gray-100">
  <div class="container mx-auto px-4 py-8" x-data="{ currentFile: '{{first_file}}' }">
    <h1 class="text-3xl font-bold mb-6">{{title}}</h1>
    
    <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
      <!-- Summary Panel -->
      <div class="col-span-1 bg-white dark:bg-gray-800 p-4 rounded shadow">
        <h2 class="text-xl font-semibold mb-4">Coverage Summary</h2>
        
        <div class="space-y-2">
          <div class="flex justify-between">
            <span>Files:</span>
            <span>{{summary.total_files}}</span>
          </div>
          
          <div class="flex justify-between">
            <span>Total Lines:</span>
            <span>{{summary.total_lines}}</span>
          </div>
          
          <div class="flex justify-between">
            <span>Covered Lines:</span>
            <span>{{summary.covered_lines}}</span>
          </div>
          
          <div class="flex justify-between">
            <span>Executed Lines:</span>
            <span>{{summary.executed_lines}}</span>
          </div>
          
          <div class="flex justify-between">
            <span>Not Covered Lines:</span>
            <span>{{summary.not_covered_lines}}</span>
          </div>
          
          <div class="flex justify-between font-semibold">
            <span>Coverage:</span>
            <span>{{summary.coverage_percent}}%</span>
          </div>
          
          <div class="flex justify-between font-semibold">
            <span>Execution:</span>
            <span>{{summary.execution_percent}}%</span>
          </div>
        </div>
        
        <div class="mt-6">
          <h3 class="text-lg font-semibold mb-2">Legend</h3>
          <div class="flex items-center space-x-2 mb-1">
            <div class="w-4 h-4 covered"></div>
            <span>Covered - Verified by assertions</span>
          </div>
          <div class="flex items-center space-x-2 mb-1">
            <div class="w-4 h-4 executed"></div>
            <span>Executed - Run but not verified</span>
          </div>
          <div class="flex items-center space-x-2">
            <div class="w-4 h-4 not-covered"></div>
            <span>Not Covered - Never executed</span>
          </div>
        </div>
        
        {{#if show_file_navigator}}
        <div class="mt-6">
          <h3 class="text-lg font-semibold mb-2">Files</h3>
          <div class="max-h-96 overflow-y-auto">
            <ul class="space-y-1">
              {{#each files}}
              <li>
                <button 
                  @click="currentFile = '{{@key}}'"
                  :class="{ 'font-bold': currentFile === '{{@key}}' }"
                  class="text-left text-sm hover:text-blue-500 truncate w-full"
                >
                  {{@key}} ({{this.summary.coverage_percent}}%)
                </button>
              </li>
              {{/each}}
            </ul>
          </div>
        </div>
        {{/if}}
      </div>
      
      <!-- File Content Panel -->
      <div class="col-span-1 lg:col-span-3">
        {{#each files}}
        <div x-show="currentFile === '{{@key}}'" class="bg-white dark:bg-gray-800 p-4 rounded shadow">
          <h2 class="text-xl font-semibold mb-4">{{@key}}</h2>
          
          <div class="flex justify-between text-sm mb-2">
            <div>
              <span class="font-semibold">Coverage:</span> {{this.summary.coverage_percent}}%
              <span class="mx-2">|</span>
              <span class="font-semibold">Execution:</span> {{this.summary.execution_percent}}%
            </div>
            <div>
              <span class="font-semibold">Lines:</span> {{this.summary.total_lines}}
              <span class="mx-1">|</span>
              <span class="font-semibold">Covered:</span> {{this.summary.covered_lines}}
              <span class="mx-1">|</span>
              <span class="font-semibold">Executed:</span> {{this.summary.executed_lines}}
              <span class="mx-1">|</span>
              <span class="font-semibold">Not Covered:</span> {{this.summary.not_covered_lines}}
            </div>
          </div>
          
          <div class="overflow-x-auto">
            <table class="w-full">
              <tbody>
                {{#each this.lines}}
                <tr class="hover:bg-gray-100 dark:hover:bg-gray-700">
                  <td class="text-right pr-4 text-gray-500 select-none w-12 border-r border-gray-300 dark:border-gray-600">{{this.line_number}}</td>
                  <td 
                    class="w-8 border-r border-gray-300 dark:border-gray-600 {{#if this.covered}}covered{{else if this.executed}}executed{{else}}not-covered{{/if}}"
                  ></td>
                  <td>
                    <pre class="px-4 py-1">{{#if this.content}}{{this.content}}{{/if}}</pre>
                  </td>
                </tr>
                {{/each}}
              </tbody>
            </table>
          </div>
        </div>
        {{/each}}
      </div>
    </div>
  </div>
</body>
</html>
]]

-- Escape HTML special characters
---@param str string The string to escape
---@return string escaped The escaped string
local function escape_html(str)
  if type(str) ~= "string" then return "" end
  
  return str:gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub("\"", "&quot;")
            :gsub("'", "&#39;")
end

-- Replace template placeholders with values
---@param template string The template string
---@param data table The data to replace placeholders with
---@return string result The resulting string
local function replace_template(template, data)
  local result = template
  
  -- Replace simple placeholders
  result = result:gsub("{{([^{}]+)}}", function(key)
    local value = data
    
    for part in key:gmatch("[^.]+") do
      if type(value) ~= "table" then
        return ""
      end
      value = value[part]
    end
    
    if type(value) == "number" then
      if key:match("percent$") then
        return string.format("%.2f", value)
      end
      return tostring(value)
    elseif type(value) == "string" then
      return value
    elseif type(value) == "boolean" then
      return tostring(value)
    else
      return ""
    end
  end)
  
  -- Process conditionals
  result = result:gsub("{{#if ([^{}]+)}}(.-){{/if}}", function(condition, content)
    local value = data
    
    for part in condition:gmatch("[^.]+") do
      if type(value) ~= "table" then
        return ""
      end
      value = value[part]
    end
    
    if value then
      return replace_template(content, data)
    else
      return ""
    end
  end)
  
  -- Process loops
  result = result:gsub("{{#each ([^{}]+)}}(.-){{/each}}", function(collection_path, template_block)
    local collection = data
    
    for part in collection_path:gmatch("[^.]+") do
      if type(collection) ~= "table" then
        return ""
      end
      collection = collection[part]
    end
    
    if type(collection) ~= "table" then
      return ""
    end
    
    local output = {}
    
    for k, v in pairs(collection) do
      local item_data = {}
      
      -- Copy all data
      for dk, dv in pairs(data) do
        item_data[dk] = dv
      end
      
      -- Add item-specific data
      item_data["@key"] = k
      item_data["@index"] = #output + 1
      item_data["this"] = v
      
      table.insert(output, replace_template(template_block, item_data))
    end
    
    return table.concat(output, "\n")
  end)
  
  return result
end

-- Get line content for a file
---@param file_path string The file path
---@return table|nil lines The line content or nil if file not found
---@return table|nil error Error object if file not found
local function get_file_content(file_path)
  -- Read the file
  local content, err = fs.read_file(file_path)
  if not content then
    return nil, err
  end
  
  -- Split into lines
  local lines = {}
  for line in content:gmatch("[^\n]+") do
    table.insert(lines, line)
  end
  
  return lines
end

-- Generate an HTML coverage report
---@param data table The coverage data
---@param options table The report options
---@return boolean|nil success Whether the report was successfully generated
---@return table|nil error Error object if failed to generate
function M.generate(data, options)
  -- Parameter validation
  if type(data) ~= "table" then
    return nil, error_handler.validation_error(
      "Coverage data must be a table",
      {parameter = "data", provided_type = type(data)}
    )
  end
  
  if type(options) ~= "table" then
    return nil, error_handler.validation_error(
      "Options must be a table",
      {parameter = "options", provided_type = type(options)}
    )
  end
  
  -- Get configuration
  local config = central_config.get_config()
  
  -- Prepare options with defaults
  options = options or {}
  options.output_dir = options.output_dir or config.coverage.report.dir or "./coverage-reports"
  options.title = options.title or config.coverage.report.title or "Coverage Report"
  options.show_file_navigator = options.show_file_navigator or config.coverage.report.show_file_navigator or true
  options.include_line_content = options.include_line_content or config.coverage.report.include_line_content or true
  
  -- Get color settings
  local colors = config.coverage.report.colors or {}
  options.covered_color = options.covered_color or colors.covered or "#00FF00"
  options.executed_color = options.executed_color or colors.executed or "#FFA500"
  options.not_covered_color = options.not_covered_color or colors.not_covered or "#FF0000"
  
  -- Ensure the output directory exists
  local dir_success, dir_err = fs.ensure_directory_exists(options.output_dir)
  if not dir_success then
    return nil, error_handler.io_error(
      "Failed to create output directory",
      {directory = options.output_dir, error = error_handler.format_error(dir_err)}
    )
  end
  
  -- Build the report data
  local report_data = {
    title = options.title,
    summary = data.summary or {
      total_files = 0,
      total_lines = 0,
      covered_lines = 0,
      executed_lines = 0,
      not_covered_lines = 0,
      coverage_percent = 0,
      execution_percent = 0
    },
    files = {},
    covered_color = options.covered_color,
    executed_color = options.executed_color,
    not_covered_color = options.not_covered_color,
    show_file_navigator = options.show_file_navigator
  }
  
  -- Process files
  local first_file = nil
  for file_path, file_data in pairs(data.files or {}) do
    if not first_file then
      first_file = file_path
    end
    
    -- Create file entry
    report_data.files[file_path] = {
      summary = file_data.summary or {
        total_lines = 0,
        covered_lines = 0,
        executed_lines = 0,
        not_covered_lines = 0,
        coverage_percent = 0,
        execution_percent = 0
      },
      lines = {}
    }
    
    -- Get file content if needed
    local content_lines = {}
    if options.include_line_content then
      local content, err = get_file_content(file_path)
      if content then
        content_lines = content
      else
        logger.warn("Failed to read file content", {
          file_path = file_path,
          error = error_handler.format_error(err)
        })
      end
    end
    
    -- Process lines
    local max_line = 0
    
    -- Find max line
    for line_number_str, _ in pairs(file_data.lines or {}) do
      local line_number = tonumber(line_number_str)
      if line_number and line_number > max_line then
        max_line = line_number
      end
    end
    
    -- Add all lines
    for i = 1, max_line do
      local line_number_str = tostring(i)
      local line_data = file_data.lines and file_data.lines[line_number_str] or {}
      
      report_data.files[file_path].lines[i] = {
        line_number = i,
        executed = line_data.executed or false,
        covered = line_data.covered or false,
        execution_count = line_data.execution_count or 0,
        content = content_lines[i] and escape_html(content_lines[i]) or ""
      }
    end
  end
  
  -- Set first file
  report_data.first_file = first_file or ""
  
  -- Generate HTML
  local html = replace_template(REPORT_TEMPLATE, report_data)
  
  -- Write the report
  local report_path = options.output_dir .. "/coverage-report.html"
  local write_success, write_err = fs.write_file(report_path, html)
  
  if not write_success then
    return nil, error_handler.io_error(
      "Failed to write HTML report",
      {file_path = report_path, error = error_handler.format_error(write_err)}
    )
  end
  
  logger.info("Generated HTML coverage report", {
    file_path = report_path,
    summary = {
      total_files = report_data.summary.total_files,
      coverage_percent = string.format("%.2f%%", report_data.summary.coverage_percent),
      execution_percent = string.format("%.2f%%", report_data.summary.execution_percent)
    }
  })
  
  return true
end

return M