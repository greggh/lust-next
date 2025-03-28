-- V3 Coverage HTML Formatter
-- Generates HTML coverage reports

local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.reporting.html")
local fs = require("lib.tools.filesystem")

local M = {}

-- HTML templates
local TEMPLATES = {
  report = [[
<!DOCTYPE html>
<html>
<head>
  <title>Coverage Report</title>
  <style>
    /* Base styles */
    body { font-family: sans-serif; margin: 0; padding: 20px; }
    .header { margin-bottom: 20px; }
    .stats { margin-bottom: 20px; }
    .file-list { margin-bottom: 20px; }
    
    /* Coverage status colors */
    .not-covered { background-color: #ffcccc; }
    .executed { background-color: #ffeecc; }
    .covered { background-color: #ccffcc; }
    
    /* Source code viewer */
    .source { font-family: monospace; white-space: pre; }
    .line-number { color: #666; padding-right: 10px; }
    .assertion-marker { color: #0066cc; cursor: pointer; }
    
    /* Function coverage */
    .function { margin: 5px 0; padding: 5px; border: 1px solid #ccc; }
    .function-covered { border-color: #66cc66; }
    .function-executed { border-color: #ffcc66; }
    .function-not-covered { border-color: #cc6666; }
    
    /* Assertion details */
    .assertion-details { margin-left: 20px; font-size: 0.9em; }
    .async-context { color: #666; }
  </style>
</head>
<body>
  <div class="header">
    <h1>Coverage Report</h1>
    <div>Generated: ${timestamp}</div>
    <div>Version: ${version}</div>
  </div>
  
  <div class="stats">
    <h2>Statistics</h2>
    ${statistics}
  </div>
  
  <div class="file-list">
    <h2>Files</h2>
    ${file_list}
  </div>
  
  <div class="files">
    ${files}
  </div>
</body>
</html>
]],

  statistics = [[
<table>
  <tr><td>Total Lines:</td><td>${total_lines}</td></tr>
  <tr><td>Executed Lines:</td><td>${executed_lines} (${executed_percent}%)</td></tr>
  <tr><td>Covered Lines:</td><td>${covered_lines} (${covered_percent}%)</td></tr>
  <tr><td>Total Functions:</td><td>${total_functions}</td></tr>
  <tr><td>Executed Functions:</td><td>${executed_functions} (${executed_functions_percent}%)</td></tr>
  <tr><td>Covered Functions:</td><td>${covered_functions} (${covered_functions_percent}%)</td></tr>
  <tr><td>Total Assertions:</td><td>${total_assertions}</td></tr>
  <tr><td>Async Assertions:</td><td>${async_assertions}</td></tr>
</table>
]],

  file = [[
<div class="file">
  <h3>${filename}</h3>
  
  <div class="file-stats">
    ${file_statistics}
  </div>
  
  <div class="functions">
    <h4>Functions</h4>
    ${functions}
  </div>
  
  <div class="source">
    ${source}
  </div>
  
  <div class="assertions">
    <h4>Assertions</h4>
    ${assertions}
  </div>
</div>
]]
}

-- Simple template system
local function render_template(template, vars)
  return template:gsub("${([^}]+)}", function(key)
    return tostring(vars[key] or "")
  end)
end

-- Helper functions
local function count_table(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

local function format_percent(value, total)
  if total == 0 then return "0.0" end
  return string.format("%.1f", (value / total) * 100)
end

local function sanitize_filename(filename)
  return filename:gsub("[^%w%-_%.%/]", "_")
end

local function generate_file_statistics(file_report)
  local total_lines = #file_report.source_lines
  local executed_lines = count_table(file_report.executed_lines)
  local covered_lines = count_table(file_report.covered_lines)
  
  local vars = {
    total_lines = total_lines,
    executed_lines = executed_lines,
    executed_percent = format_percent(executed_lines, total_lines),
    covered_lines = covered_lines,
    covered_percent = format_percent(covered_lines, total_lines)
  }
  
  return render_template([[
<table>
  <tr><td>Total Lines:</td><td>${total_lines}</td></tr>
  <tr><td>Executed Lines:</td><td>${executed_lines} (${executed_percent}%)</td></tr>
  <tr><td>Covered Lines:</td><td>${covered_lines} (${covered_percent}%)</td></tr>
</table>
]], vars)
end

local function generate_function_list(functions)
  local lines = {}
  for name, func in pairs(functions) do
    local class = "function"
    if func.covered then
      class = class .. " function-covered"
    elseif func.executed then
      class = class .. " function-executed"
    else
      class = class .. " function-not-covered"
    end
    
    table.insert(lines, string.format(
      '<div class="%s">%s (lines %d-%d)</div>',
      class, name, func.start_line, func.end_line
    ))
  end
  return table.concat(lines, "\n")
end

local function generate_source_view(file_report, assertion_report)
  local lines = {}
  for i, line in ipairs(file_report.source_lines) do
    local class = "not-covered"
    if file_report.covered_lines[i] then
      class = "covered"
    elseif file_report.executed_lines[i] then
      class = "executed"
    end
    
    -- Add assertion markers
    local markers = {}
    if assertion_report then
      for _, assertion in ipairs(assertion_report.assertions) do
        if assertion.line == i then
          table.insert(markers, assertion.async_context and 
            string.format('<span class="assertion-marker async">A[%s]</span>', assertion.async_context) or
            '<span class="assertion-marker">A</span>'
          )
        end
      end
    end
    
    table.insert(lines, string.format(
      '<div class="%s"><span class="line-number">%d</span>%s%s</div>',
      class, i, line, table.concat(markers, " ")
    ))
  end
  return table.concat(lines, "\n")
end

local function generate_assertion_list(assertion_report)
  if not assertion_report then return "" end
  
  local lines = {}
  for _, assertion in ipairs(assertion_report.assertions) do
    local context = assertion.async_context and 
      string.format(' <span class="async-context">[%s]</span>', assertion.async_context) or ""
    
    table.insert(lines, string.format(
      '<div class="assertion">Line %d%s</div>',
      assertion.line, context
    ))
  end
  return table.concat(lines, "\n")
end

local function generate_file_list(files)
  local lines = {}
  for filename, _ in pairs(files) do
    table.insert(lines, string.format('<a href="%s.html">%s</a><br>', 
      sanitize_filename(filename), filename))
  end
  return table.concat(lines, "\n")
end

local function generate_statistics(stats)
  local vars = {
    total_lines = stats.total_lines,
    executed_lines = stats.executed_lines,
    executed_percent = format_percent(stats.executed_lines, stats.total_lines),
    covered_lines = stats.covered_lines,
    covered_percent = format_percent(stats.covered_lines, stats.total_lines),
    total_functions = stats.total_functions,
    executed_functions = stats.executed_functions,
    executed_functions_percent = format_percent(stats.executed_functions, stats.total_functions),
    covered_functions = stats.covered_functions,
    covered_functions_percent = format_percent(stats.covered_functions, stats.total_functions),
    total_assertions = stats.total_assertions,
    async_assertions = stats.async_assertions
  }
  return render_template(TEMPLATES.statistics, vars)
end

local function generate_file_summary(filename, file_report, report)
  local vars = {
    filename = filename,
    file_statistics = generate_file_statistics(file_report),
    functions = generate_function_list(file_report.functions),
    source = generate_source_view(file_report, report.assertions[filename]),
    assertions = generate_assertion_list(report.assertions[filename])
  }
  return render_template(TEMPLATES.file, vars)
end

local function generate_file_summaries(report)
  local lines = {}
  local i = 1
  for filename, file_report in pairs(report.files) do
    table.insert(lines, i, (generate_file_summary(filename, file_report, report)))
    i = i + 1
  end
  return table.concat(lines, "\n")
end

local function generate_report_content(report)
  local vars = {
    timestamp = os.date("%Y-%m-%d %H:%M:%S", report.metadata.timestamp),
    version = report.metadata.version,
    statistics = generate_statistics(report.statistics),
    file_list = generate_file_list(report.files),
    files = generate_file_summaries(report)
  }
  return render_template(TEMPLATES.report, vars)
end

-- Generate HTML report
---@param report CoverageReport Coverage report to format
---@param output_dir string Directory to write HTML files
---@return boolean success Whether report generation succeeded
---@return string? error Error message if generation failed
function M.generate_report(report, output_dir)
  -- Validate report first
  local success, err = require("lib.coverage.v3.reporting").validate_report(report)
  if not success then
    return false, err
  end
  
  -- Create output directory using filesystem module
  success = fs.ensure_directory_exists(output_dir)
  if not success then
    return false, "Failed to create output directory"
  end
  
  -- Generate main report file
  local main_file = fs.join_paths(output_dir, "index.html")
  success = fs.write_file(main_file, generate_report_content(report))
  if not success then
    return false, "Failed to create index.html"
  end
  
  -- Generate individual file reports
  for filename, file_report in pairs(report.files) do
    local file_content = generate_file_summary(filename, file_report, report)
    local file_path = fs.join_paths(output_dir, fs.get_file_name(filename) .. ".html")
    
    success = fs.write_file(file_path, file_content)
    if not success then
      return false, "Failed to create file report: " .. filename
    end
  end
  
  return true
end

return M
