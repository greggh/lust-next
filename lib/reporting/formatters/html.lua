-- HTML formatter for reports
local M = {}

-- Helper function to escape HTML special characters
local function escape_html(str)
  if type(str) ~= "string" then
    return tostring(str or "")
  end
  
  return str:gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub("\"", "&quot;")
            :gsub("'", "&apos;")
end

-- Format a single line of source code with coverage highlighting
local function format_source_line(line_num, content, is_covered)
  local class = is_covered and "covered" or "uncovered"
  local html = string.format(
    '<div class="line %s">' ..
    '<span class="line-number">%d</span>' ..
    '<span class="line-content">%s</span>' ..
    '</div>',
    class, line_num, escape_html(content)
  )
  return html
end

-- Generate HTML coverage report
function M.format_coverage(coverage_data)
  -- Get summary data first
  local summary_fn = require("lib.reporting.formatters.summary").format_coverage
  local report = summary_fn(coverage_data)
  
  -- Start building HTML report
  local html = [[
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>lust-next Coverage Report</title>
  <style>
    body { font-family: sans-serif; margin: 0; padding: 0; }
    .container { max-width: 960px; margin: 0 auto; padding: 20px; }
    h1 { color: #333; }
    .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
    .summary-row { display: flex; justify-content: space-between; margin-bottom: 5px; }
    .summary-label { font-weight: bold; }
    .progress-bar { height: 20px; background: #eee; border-radius: 10px; overflow: hidden; margin-top: 5px; }
    .progress-fill { height: 100%; background: linear-gradient(to right, #ff9999 0%, #ffff99 60%, #99ff99 80%); }
    .file-list { margin-top: 20px; border: 1px solid #ddd; border-radius: 5px; overflow: hidden; }
    .file-header { background: #f0f0f0; padding: 10px; font-weight: bold; display: flex; }
    .file-name { flex: 2; }
    .file-metric { flex: 1; text-align: center; }
    .file-item { padding: 10px; display: flex; border-top: 1px solid #ddd; }
    .covered { background-color: rgba(144, 238, 144, 0.2); }
    .uncovered { background-color: rgba(255, 182, 193, 0.2); }
    .source-code { font-family: monospace; border: 1px solid #ddd; margin: 10px 0; }
    .line { display: flex; line-height: 1.4; }
    .line-number { background: #f0f0f0; text-align: right; padding: 0 8px; border-right: 1px solid #ddd; min-width: 30px; }
    .line-content { padding: 0 8px; white-space: pre; }
  </style>
</head>
<body>
  <div class="container">
    <h1>lust-next Coverage Report</h1>
    
    <div class="summary">
      <h2>Summary</h2>
      
      <div class="summary-row">
        <span class="summary-label">Files:</span>
        <span>]].. report.covered_files .. "/" .. report.total_files .. " (" .. string.format("%.1f", report.files_pct) .. "%)</span>
      </div>
      <div class="progress-bar">
        <div class="progress-fill" style="width: ]] .. report.files_pct .. [[%;"></div>
      </div>
      
      <div class="summary-row">
        <span class="summary-label">Lines:</span>
        <span>]] .. report.covered_lines .. "/" .. report.total_lines .. " (" .. string.format("%.1f", report.lines_pct) .. "%)</span>
      </div>
      <div class="progress-bar">
        <div class="progress-fill" style="width: ]] .. report.lines_pct .. [[%;"></div>
      </div>
      
      <div class="summary-row">
        <span class="summary-label">Functions:</span>
        <span>]] .. report.covered_functions .. "/" .. report.total_functions .. " (" .. string.format("%.1f", report.functions_pct) .. "%)</span>
      </div>
      <div class="progress-bar">
        <div class="progress-fill" style="width: ]] .. report.functions_pct .. [[%;"></div>
      </div>
      
      <div class="summary-row">
        <span class="summary-label">Overall:</span>
        <span>]] .. string.format("%.1f", report.overall_pct) .. [[%</span>
      </div>
      <div class="progress-bar">
        <div class="progress-fill" style="width: ]] .. report.overall_pct .. [[%;"></div>
      </div>
    </div>
    
    <!-- File list and details -->
    <div class="file-list">
      <div class="file-header">
        <div class="file-name">File</div>
        <div class="file-metric">Lines</div>
        <div class="file-metric">Functions</div>
        <div class="file-metric">Coverage</div>
      </div>
  ]]
  
  -- Add file details (if available)
  if report.files then
    for filename, file_data in pairs(report.files) do
      -- Calculate file-specific metrics
      local line_count = file_data.line_count or 0
      local covered_lines = 0
      for _, covered in pairs(file_data.lines or {}) do
        if covered then covered_lines = covered_lines + 1 end
      end
      
      local line_percent = line_count > 0 and (covered_lines / line_count * 100) or 0
      
      -- Add file entry
      html = html .. string.format(
        [[
        <div class="file-item">
          <div class="file-name">%s</div>
          <div class="file-metric">%d/%d</div>
          <div class="file-metric">N/A</div>
          <div class="file-metric">%.1f%%</div>
        </div>
        ]],
        escape_html(filename),
        covered_lines, line_count,
        line_percent
      )
      
      -- Add source code container (if source is available)
      if file_data.source then
        html = html .. '<div class="source-code">'
        
        for i, line in ipairs(file_data.source) do
          local is_covered = file_data.lines and file_data.lines[i] or false
          html = html .. format_source_line(i, line, is_covered)
        end
        
        html = html .. '</div>'
      end
    end
  end
  
  -- Close HTML
  html = html .. [[
    </div>
  </div>
</body>
</html>
  ]]
  
  return html
end

-- Generate HTML quality report
function M.format_quality(quality_data)
  -- Get summary data first
  local summary_fn = require("lib.reporting.formatters.summary").format_quality
  local report = summary_fn(quality_data)
  
  -- Start building HTML report
  local html = [[
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>lust-next Quality Report</title>
  <style>
    body { font-family: sans-serif; margin: 0; padding: 0; }
    .container { max-width: 960px; margin: 0 auto; padding: 20px; }
    h1 { color: #333; }
    .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
    .summary-row { display: flex; justify-content: space-between; margin-bottom: 5px; }
    .summary-label { font-weight: bold; }
    .progress-bar { height: 20px; background: #eee; border-radius: 10px; overflow: hidden; margin-top: 5px; }
    .progress-fill { height: 100%; background: linear-gradient(to right, #ff9999 0%, #ffff99 60%, #99ff99 80%); }
    .issues-list { margin-top: 20px; }
    .issue-item { padding: 10px; margin-bottom: 5px; border-left: 4px solid #ff9999; background: #fff; }
  </style>
</head>
<body>
  <div class="container">
    <h1>lust-next Quality Report</h1>
    
    <div class="summary">
      <h2>Summary</h2>
      
      <div class="summary-row">
        <span class="summary-label">Quality Level:</span>
        <span>]] .. report.level .. " - " .. report.level_name .. [[</span>
      </div>
      
      <div class="summary-row">
        <span class="summary-label">Tests Analyzed:</span>
        <span>]] .. report.tests_analyzed .. [[</span>
      </div>
      
      <div class="summary-row">
        <span class="summary-label">Tests Passing Quality:</span>
        <span>]] .. report.tests_passing .. "/" .. report.tests_analyzed .. 
        " (" .. string.format("%.1f", report.quality_pct) .. "%)</span>
      </div>
      <div class="progress-bar">
        <div class="progress-fill" style="width: ]] .. report.quality_pct .. [[%;"></div>
      </div>
    </div>
    
    <!-- Issues list -->
    <div class="issues-list">
      <h2>Issues</h2>
  ]]
  
  -- Add issues
  if #report.issues > 0 then
    for _, issue in ipairs(report.issues) do
      html = html .. string.format(
        [[<div class="issue-item">%s</div>]],
        escape_html(issue)
      )
    end
  else
    html = html .. [[<p>No quality issues found.</p>]]
  end
  
  -- Close HTML
  html = html .. [[
    </div>
  </div>
</body>
</html>
  ]]
  
  return html
end

-- Register formatters
return function(formatters)
  formatters.coverage.html = M.format_coverage
  formatters.quality.html = M.format_quality
end