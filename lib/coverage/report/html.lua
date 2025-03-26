---@class HTMLReportGenerator
---@field generate fun(data: table, output_path: string): boolean, string|nil Generate an HTML coverage report
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")
local data_store = require("lib.coverage.runtime.data_store")

-- Version
M._VERSION = "3.0.0"

-- CSS styles for the report
local CSS = [[
:root {
  --covered-color: #4caf50;
  --executed-color: #ff9800;
  --not-covered-color: #f44336;
  --text-color: #333;
  --header-bg: #f5f5f5;
  --border-color: #ddd;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  margin: 0;
  padding: 0;
  color: var(--text-color);
  line-height: 1.5;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

header {
  background-color: var(--header-bg);
  padding: 20px;
  margin-bottom: 20px;
  border-bottom: 1px solid var(--border-color);
}

h1, h2, h3 {
  margin: 0 0 15px 0;
}

table {
  width: 100%;
  border-collapse: collapse;
  margin-bottom: 20px;
}

table th, table td {
  padding: 10px;
  text-align: left;
  border-bottom: 1px solid var(--border-color);
}

table th {
  background-color: var(--header-bg);
}

.progress-bar {
  height: 10px;
  background-color: #eee;
  border-radius: 5px;
  overflow: hidden;
  margin-top: 5px;
}

.progress-value {
  height: 100%;
  border-radius: 5px;
}

.covered-color { background-color: var(--covered-color); color: white; }
.executed-color { background-color: var(--executed-color); color: white; }
.not-covered-color { background-color: var(--not-covered-color); color: white; }

.covered-bg { background-color: rgba(76, 175, 80, 0.1); }
.executed-bg { background-color: rgba(255, 152, 0, 0.1); }
.not-covered-bg { background-color: rgba(244, 67, 54, 0.1); }

.file-content {
  margin-top: 20px;
  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
  font-size: 12px;
  white-space: pre;
  overflow-x: auto;
  border: 1px solid var(--border-color);
  border-radius: 5px;
}

.line {
  display: flex;
}

.line-number {
  padding: 0 10px;
  text-align: right;
  border-right: 1px solid var(--border-color);
  user-select: none;
  color: #999;
  background-color: #f9f9f9;
  min-width: 30px;
}

.line-content {
  padding: 0 10px;
  white-space: pre;
}

.legend {
  display: flex;
  margin-bottom: 20px;
}

.legend-item {
  display: flex;
  align-items: center;
  margin-right: 20px;
}

.legend-color {
  width: 20px;
  height: 20px;
  margin-right: 5px;
  border-radius: 3px;
}

footer {
  margin-top: 40px;
  text-align: center;
  font-size: 12px;
  color: #666;
}
]]

-- HTML escape function
local function escape_html(str)
  if not str then return "" end
  return str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

-- Format a percentage
local function format_percent(num)
  return string.format("%.1f%%", num)
end

-- Generate a progress bar
local function progress_bar(percent, class)
  return string.format([[
<div class="progress-bar">
  <div class="progress-value %s" style="width: %s%%"></div>
</div>
]], class, percent)
end

-- Generate HTML for a coverage file
local function generate_file_html(file_data)
  local lines_html = ""
  
  for line_number, line_data in pairs(file_data.lines) do
    local status_class = ""
    if line_data.status == data_store.STATUS.COVERED then
      status_class = "covered-bg"
    elseif line_data.status == data_store.STATUS.EXECUTED then
      status_class = "executed-bg"
    elseif line_data.status == data_store.STATUS.NOT_COVERED and line_data.is_executable then
      status_class = "not-covered-bg"
    end
    
    lines_html = lines_html .. string.format([[
<div class="line %s">
  <div class="line-number">%d</div>
  <div class="line-content">%s</div>
</div>
]], status_class, line_number, escape_html(line_data.content or ""))
  end
  
  local file_html = string.format([[
<div class="file">
  <h3>%s</h3>
  <div>
    <strong>Line Coverage:</strong> %s (%d/%d)
    %s
  </div>
  <div class="file-content">
    %s
  </div>
</div>
]], escape_html(file_data.file_path), 
   format_percent(file_data.summary.line_coverage_percent),
   file_data.summary.covered_lines,
   file_data.summary.executable_lines,
   progress_bar(file_data.summary.line_coverage_percent, "covered-color"),
   lines_html)
  
  return file_html
end

-- Generate an HTML coverage report
---@param data table The coverage data
---@param output_path string The path to write the report to
---@return boolean success Whether the report was successfully generated
---@return string|nil error Error message if generation failed
function M.generate(data, output_path)
  -- Parameter validation
  error_handler.assert(type(data) == "table", "data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(output_path) == "string", "output_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Calculate summary if not already calculated
  if not data.summary or not data.summary.line_coverage_percent then
    data_store.calculate_summary(data)
  end
  
  -- Ensure the output path has the right extension
  if not output_path:match("%.html$") then
    output_path = output_path .. "/coverage-report.html"
  end
  
  -- Ensure the output directory exists
  local dir_path = output_path:match("(.+)/[^/]*$") or output_path
  local mkdir_success, mkdir_err = fs.ensure_directory_exists(dir_path)
  if not mkdir_success then
    logger.error("Failed to create output directory", {
      directory = dir_path,
      error = error_handler.format_error(mkdir_err)
    })
    return false, "Failed to create output directory: " .. tostring(mkdir_err)
  end
  
  -- Generate summary HTML
  local summary_html = string.format([[
<div class="summary">
  <h2>Coverage Summary</h2>
  <table>
    <tr>
      <th>Files</th>
      <th>Executable Lines</th>
      <th>Covered Lines</th>
      <th>Line Coverage</th>
    </tr>
    <tr>
      <td>%d</td>
      <td>%d</td>
      <td>%d</td>
      <td>
        %s
        %s
      </td>
    </tr>
  </table>
</div>
]], data.summary.total_files,
   data.summary.executable_lines,
   data.summary.covered_lines,
   format_percent(data.summary.line_coverage_percent),
   progress_bar(data.summary.line_coverage_percent, "covered-color"))
  
  -- Generate file list HTML
  local file_list_html = [[<div class="file-list"><h2>Files</h2><table><tr><th>File</th><th>Line Coverage</th></tr>]]
  
  -- Get all file IDs
  local file_ids = {}
  for file_id, _ in pairs(data.execution_data or {}) do
    file_ids[file_id] = true
  end
  for file_id, _ in pairs(data.coverage_data or {}) do
    file_ids[file_id] = true
  end
  
  -- Convert to a sorted list
  local file_id_list = {}
  for file_id, _ in pairs(file_ids) do
    table.insert(file_id_list, file_id)
  end
  table.sort(file_id_list)
  
  -- Generate file list
  for _, file_id in ipairs(file_id_list) do
    local file_data = data_store.get_file_data(data, file_id)
    if file_data then
      local file_path = file_data.file_path or file_id
      local line_coverage = file_data.summary.line_coverage_percent
      
      file_list_html = file_list_html .. string.format([[
<tr>
  <td><a href="#file-%s">%s</a></td>
  <td>
    %s
    %s
  </td>
</tr>
]], file_id, escape_html(file_path), format_percent(line_coverage), progress_bar(line_coverage, "covered-color"))
    end
  end
  
  file_list_html = file_list_html .. [[</table></div>]]
  
  -- Generate files HTML
  local files_html = ""
  
  for _, file_id in ipairs(file_id_list) do
    local file_data = data_store.get_file_data(data, file_id)
    if file_data then
      files_html = files_html .. string.format([[
<div id="file-%s" class="file-section">
  %s
</div>
]], file_id, generate_file_html(file_data))
    end
  end
  
  -- Generate the complete HTML
  local html = string.format([[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Coverage Report</title>
  <style>%s</style>
</head>
<body>
  <header>
    <div class="container">
      <h1>Coverage Report</h1>
      <div>Generated on %s</div>
    </div>
  </header>
  
  <div class="container">
    <div class="legend">
      <div class="legend-item">
        <div class="legend-color covered-color"></div>
        <div>Covered (executed and verified by assertions)</div>
      </div>
      <div class="legend-item">
        <div class="legend-color executed-color"></div>
        <div>Executed (but not verified)</div>
      </div>
      <div class="legend-item">
        <div class="legend-color not-covered-color"></div>
        <div>Not Covered</div>
      </div>
    </div>
    
    %s
    
    %s
    
    %s
  </div>
  
  <footer>
    <div class="container">
      Coverage report generated by Firmo Coverage v%s
    </div>
  </footer>
</body>
</html>
]], CSS, os.date("%Y-%m-%d %H:%M:%S"), summary_html, file_list_html, files_html, M._VERSION)
  
  -- Write the HTML to the output file
  local write_success, write_err = fs.write_file(output_path, html)
  if not write_success then
    logger.error("Failed to write HTML report", {
      output_path = output_path,
      error = error_handler.format_error(write_err)
    })
    return false, "Failed to write HTML report: " .. tostring(write_err)
  end
  
  logger.info("Generated HTML coverage report", {
    output_path = output_path
  })
  
  return true
end

return M