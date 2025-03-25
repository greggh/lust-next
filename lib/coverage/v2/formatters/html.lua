---@class CoverageHtmlFormatter
---@field generate fun(coverage_data: table, output_path: string): boolean, string|nil Generates an HTML coverage report
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")
local data_structure = require("lib.coverage.v2.data_structure")

-- Version
M._VERSION = "0.1.0"

-- CSS styles for the HTML report
local CSS_STYLES = [[
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  line-height: 1.5;
  color: #333;
  margin: 0;
  padding: 20px;
}

h1, h2, h3 {
  margin-top: 0;
}

.summary {
  background-color: #f5f5f5;
  padding: 15px;
  border-radius: 5px;
  margin-bottom: 20px;
}

.summary-row {
  display: flex;
  justify-content: space-between;
  margin-bottom: 10px;
}

.summary-label {
  font-weight: bold;
  flex: 1;
}

.summary-value {
  flex: 1;
  text-align: right;
}

.files {
  margin-bottom: 20px;
}

.file-item {
  display: flex;
  align-items: center;
  padding: 10px;
  border-bottom: 1px solid #eee;
}

.file-name {
  flex: 3;
}

.file-coverage {
  flex: 1;
  text-align: right;
}

.progress {
  background-color: #f5f5f5;
  border-radius: 3px;
  height: 20px;
  margin-left: 10px;
  margin-right: 10px;
  flex: 2;
  overflow: hidden;
}

.progress-bar {
  background-color: #4CAF50;
  height: 100%;
}

.low {
  background-color: #F44336;
}

.medium {
  background-color: #FF9800;
}

.high {
  background-color: #4CAF50;
}

.source-code {
  font-family: monospace;
  white-space: pre;
  margin-top: 20px;
  border: 1px solid #ddd;
  border-radius: 3px;
}

.line {
  display: flex;
}

.line-number {
  width: 50px;
  text-align: right;
  padding-right: 10px;
  border-right: 1px solid #ddd;
  color: #999;
  background-color: #f5f5f5;
}

.line-content {
  padding-left: 10px;
}

.covered {
  background-color: rgba(76, 175, 80, 0.1);
}

.not-covered {
  background-color: rgba(244, 67, 54, 0.1);
}

.not-executable {
  color: #999;
}

.execution-count {
  display: inline-block;
  min-width: 30px;
  text-align: right;
  color: #666;
  padding-right: 10px;
}

.file-summary {
  background-color: #f5f5f5;
  padding: 10px;
  margin-bottom: 20px;
  border-radius: 3px;
}

.function-list {
  margin: 20px 0;
}

.functions {
  width: 100%;
  border-collapse: collapse;
  margin-bottom: 20px;
}

.functions th, .functions td {
  padding: 8px;
  text-align: left;
  border-bottom: 1px solid #ddd;
}

.functions th {
  background-color: #f5f5f5;
  font-weight: bold;
  cursor: pointer;
}

.functions th:hover {
  background-color: #e5e5e5;
}

.functions th::after {
  content: "";
  margin-left: 5px;
}

.functions th.sort-asc::after {
  content: "▲";
}

.functions th.sort-desc::after {
  content: "▼";
}

.functions .executed {
  color: #4CAF50;
}

.functions .not-executed {
  color: #F44336;
}

.functions .covered {
  background-color: rgba(76, 175, 80, 0.1);
}

.functions .not-covered {
  background-color: rgba(244, 67, 54, 0.1);
}

.function-type-badge {
  display: inline-block;
  font-size: 0.8em;
  padding: 2px 6px;
  border-radius: 10px;
  background-color: #e0e0e0;
  color: #333;
  margin-left: 5px;
}

.function-type-global {
  background-color: #bbdefb;
  color: #0d47a1;
}

.function-type-local {
  background-color: #c8e6c9;
  color: #1b5e20;
}

.function-type-method {
  background-color: #d1c4e9;
  color: #4527a0;
}

.function-type-anonymous {
  background-color: #ffe0b2;
  color: #e65100;
}

.function-type-closure {
  background-color: #f8bbd0;
  color: #880e4f;
}

.function-filter {
  margin: 10px 0;
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.function-filter-item {
  display: inline-flex;
  align-items: center;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 4px;
  background-color: #f5f5f5;
}

.function-filter-item.active {
  background-color: #e0e0e0;
  font-weight: bold;
}

.function-filter-item input {
  margin-right: 5px;
}

.function-count {
  background-color: #f5f5f5;
  border-radius: 10px;
  padding: 2px 6px;
  font-size: 0.8em;
  margin-left: 5px;
}

.function-search {
  margin-bottom: 10px;
  width: 100%;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
  box-sizing: border-box;
}

.badge {
  display: inline-block;
  font-size: 0.8em;
  padding: 2px 6px;
  border-radius: 10px;
  margin-left: 5px;
}

.badge-success {
  background-color: #c8e6c9;
  color: #1b5e20;
}

.badge-danger {
  background-color: #ffcdd2;
  color: #b71c1c;
}

.badge-warning {
  background-color: #ffe0b2;
  color: #e65100;
}

.badge-info {
  background-color: #bbdefb;
  color: #0d47a1;
}

/* For JavaScript interaction */
.function-sort-script {
  display: none;
}
]]

--- Generates the HTML summary section
---@param summary table The coverage summary data
---@return string html The HTML code for the summary section
local function generate_summary_html(summary)
  -- Calculate color classes for summary bars
  local line_coverage_class = "low"
  if summary.line_coverage_percent >= 80 then
    line_coverage_class = "high"
  elseif summary.line_coverage_percent >= 50 then
    line_coverage_class = "medium"
  end
  
  local func_coverage_class = "low"
  if summary.function_coverage_percent >= 80 then
    func_coverage_class = "high"
  elseif summary.function_coverage_percent >= 50 then
    func_coverage_class = "medium"
  end
  
  local html = [[
<div class="summary">
  <h2>Coverage Summary</h2>
  
  <!-- Coverage visualization -->
  <div style="margin-bottom: 20px;">
    <div style="margin-bottom: 10px;">
      <strong>Line Coverage: ]] .. summary.line_coverage_percent .. [[%</strong>
      <div class="progress" style="margin: 5px 0; height: 15px;">
        <div class="progress-bar ]] .. line_coverage_class .. [[" style="width: ]] .. summary.line_coverage_percent .. [[%;"></div>
      </div>
    </div>
    
    <div style="margin-bottom: 10px;">
      <strong>Function Coverage: ]] .. summary.function_coverage_percent .. [[%</strong>
      <div class="progress" style="margin: 5px 0; height: 15px;">
        <div class="progress-bar ]] .. func_coverage_class .. [[" style="width: ]] .. summary.function_coverage_percent .. [[%;"></div>
      </div>
    </div>
  </div>
  
  <div class="summary-row">
    <span class="summary-label">Total Files:</span>
    <span class="summary-value">]] .. summary.total_files .. [[</span>
  </div>
  <div class="summary-row">
    <span class="summary-label">Covered Files:</span>
    <span class="summary-value">]] .. summary.covered_files .. " / " .. summary.total_files .. [[ (]] .. summary.file_coverage_percent .. [[%)</span>
  </div>
  <div class="summary-row">
    <span class="summary-label">Total Lines:</span>
    <span class="summary-value">]] .. summary.total_lines .. [[</span>
  </div>
  <div class="summary-row">
    <span class="summary-label">Executable Lines:</span>
    <span class="summary-value">]] .. summary.executable_lines .. [[</span>
  </div>
  <div class="summary-row">
    <span class="summary-label">Executed Lines:</span>
    <span class="summary-value">]] .. summary.executed_lines .. " / " .. summary.executable_lines .. [[ (]] .. summary.execution_coverage_percent .. [[%)</span>
  </div>
  <div class="summary-row">
    <span class="summary-label">Covered Lines:</span>
    <span class="summary-value">]] .. summary.covered_lines .. " / " .. summary.executable_lines .. [[ (]] .. summary.line_coverage_percent .. [[%)</span>
  </div>
  <div class="summary-row">
    <span class="summary-label">Total Functions:</span>
    <span class="summary-value">]] .. summary.total_functions .. [[</span>
  </div>
  <div class="summary-row">
    <span class="summary-label">Executed Functions:</span>
    <span class="summary-value">]] .. summary.executed_functions .. " / " .. summary.total_functions .. [[ (]] .. (summary.total_functions > 0 and math.floor((summary.executed_functions / summary.total_functions) * 100) or 0) .. [[%)</span>
  </div>
  <div class="summary-row">
    <span class="summary-label">Covered Functions:</span>
    <span class="summary-value">]] .. summary.covered_functions .. " / " .. summary.total_functions .. [[ (]] .. summary.function_coverage_percent .. [[%)</span>
  </div>
  
  <!-- Function type breakdown -->
  <div style="margin-top: 15px;" id="function-type-breakdown">
    <h3>Function Types</h3>
    <div id="function-type-chart" style="display: flex; flex-wrap: wrap; gap: 10px; margin-top: 10px;">
      <!-- This will be populated with JavaScript -->
    </div>
  </div>
</div>

<script>
// Function to collect and display function type statistics
(function() {
  document.addEventListener('DOMContentLoaded', function() {
    // Count types
    const typeCounts = {
      global: 0,
      local: 0,
      method: 0,
      anonymous: 0,
      closure: 0,
      total: 0,
      executed: 0
    };
    
    // Collect stats from all function rows
    document.querySelectorAll('tr[data-function-type]').forEach(row => {
      const type = row.dataset.functionType;
      const executed = row.dataset.executed === 'true';
      
      if (typeCounts[type] !== undefined) {
        typeCounts[type]++;
        typeCounts.total++;
        if (executed) typeCounts.executed++;
      }
    });
    
    // Create chart
    const chart = document.getElementById('function-type-chart');
    if (!chart) return;
    
    const typeColors = {
      global: { bg: '#bbdefb', text: '#0d47a1' },
      local: { bg: '#c8e6c9', text: '#1b5e20' },
      method: { bg: '#d1c4e9', text: '#4527a0' },
      anonymous: { bg: '#ffe0b2', text: '#e65100' },
      closure: { bg: '#f8bbd0', text: '#880e4f' }
    };
    
    // Add a box for each type
    Object.keys(typeColors).forEach(type => {
      if (typeCounts[type] > 0) {
        const box = document.createElement('div');
        const percent = ((typeCounts[type] / typeCounts.total) * 100).toFixed(1);
        box.className = 'function-type-box';
        box.style.padding = '8px 12px';
        box.style.borderRadius = '4px';
        box.style.backgroundColor = typeColors[type].bg;
        box.style.color = typeColors[type].text;
        box.style.fontWeight = 'bold';
        box.style.minWidth = '120px';
        box.innerHTML = `
          ${type}: <strong>${typeCounts[type]}</strong><br>
          <small>${percent}% of functions</small>
        `;
        chart.appendChild(box);
      }
    });
    
    // Add executed count
    if (typeCounts.total > 0) {
      const executedBox = document.createElement('div');
      const percent = ((typeCounts.executed / typeCounts.total) * 100).toFixed(1);
      executedBox.className = 'function-type-box';
      executedBox.style.padding = '8px 12px';
      executedBox.style.borderRadius = '4px';
      executedBox.style.backgroundColor = '#dcedc8';
      executedBox.style.color = '#33691e';
      executedBox.style.fontWeight = 'bold';
      executedBox.style.minWidth = '120px';
      executedBox.innerHTML = `
        Executed: <strong>${typeCounts.executed}</strong><br>
        <small>${percent}% of total</small>
      `;
      chart.appendChild(executedBox);
    }
  });
})();
</script>
]]

  return html
end

--- Generates the HTML file list section
---@param coverage_data table The coverage data
---@return string html The HTML code for the file list section
local function generate_file_list_html(coverage_data)
  local html = [[
<div class="files">
  <h2>Covered Files</h2>
]]

  -- Sort files by path
  local files = {}
  for path, file_data in pairs(coverage_data.files) do
    table.insert(files, { path = path, data = file_data })
  end
  
  table.sort(files, function(a, b) return a.path < b.path end)
  
  -- Generate file items
  for _, file in ipairs(files) do
    local file_data = file.data
    local path = file.path
    local coverage_percent = file_data.line_coverage_percent
    
    local coverage_class = "low"
    if coverage_percent >= 80 then
      coverage_class = "high"
    elseif coverage_percent >= 50 then
      coverage_class = "medium"
    end
    
    html = html .. [[
  <div class="file-item">
    <div class="file-name"><a href="#file-]] .. path:gsub("[^%w]", "-") .. [[">]] .. path .. [[</a></div>
    <div class="progress">
      <div class="progress-bar ]] .. coverage_class .. [[" style="width: ]] .. coverage_percent .. [[%;"></div>
    </div>
    <div class="file-coverage">]] .. coverage_percent .. [[%</div>
  </div>
]]
  end
  
  html = html .. [[
</div>
]]

  return html
end

--- Escapes HTML special characters
---@param text string The text to escape
---@return string escaped_text The escaped text
local function escape_html(text)
  return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

--- Generates the HTML source code section for a file
---@param file_data table The file data
---@param file_id string The file ID for anchor links
---@return string html The HTML code for the source code section
local function generate_file_source_html(file_data, file_id)
  local html = [[
<div class="source-code" id="file-]] .. file_id .. [[">
  <h3>]] .. file_data.path .. [[</h3>
  <div class="file-summary">
    <!-- Line Coverage -->
    <div class="summary-row">
      <span class="summary-label">Line Coverage:</span>
      <span class="summary-value">]] .. file_data.covered_lines .. " / " .. file_data.executable_lines .. [[ (]] .. file_data.line_coverage_percent .. [[%)</span>
    </div>
    <div class="progress" style="margin: 5px 0; height: 10px;">
      <div class="progress-bar ]] .. (file_data.line_coverage_percent >= 80 and "high" or (file_data.line_coverage_percent >= 50 and "medium" or "low")) .. [[" style="width: ]] .. file_data.line_coverage_percent .. [[%;"></div>
    </div>
    
    <!-- Function Coverage -->
    <div class="summary-row" style="margin-top: 10px;">
      <span class="summary-label">Function Coverage:</span>
      <span class="summary-value">]] .. file_data.covered_functions .. " / " .. file_data.total_functions .. [[ (]] .. (file_data.total_functions > 0 and file_data.function_coverage_percent or 0) .. [[%)</span>
    </div>
    <div class="progress" style="margin: 5px 0; height: 10px;">
      <div class="progress-bar ]] .. (file_data.function_coverage_percent >= 80 and "high" or (file_data.function_coverage_percent >= 50 and "medium" or "low")) .. [[" style="width: ]] .. file_data.function_coverage_percent .. [[%;"></div>
    </div>
    
    <!-- Summary counts -->
    <div style="display: flex; flex-wrap: wrap; gap: 10px; margin-top: 10px;">
      <div style="background-color: #f5f5f5; padding: 5px 10px; border-radius: 4px;">
        <strong>Lines:</strong> ]] .. file_data.total_lines .. [[
      </div>
      <div style="background-color: #f5f5f5; padding: 5px 10px; border-radius: 4px;">
        <strong>Executable:</strong> ]] .. file_data.executable_lines .. [[
      </div>
      <div style="background-color: #f5f5f5; padding: 5px 10px; border-radius: 4px;">
        <strong>Functions:</strong> ]] .. file_data.total_functions .. [[
      </div>
      <div style="background-color: ]] .. (file_data.executed_functions > 0 and "#c8e6c9" or "#ffccbc") .. [[; padding: 5px 10px; border-radius: 4px;">
        <strong>Executed Functions:</strong> ]] .. file_data.executed_functions .. [[
      </div>
    </div>
  </div>
]]

  -- Generate function list if there are any
  if file_data.total_functions > 0 then
    -- Count function types for filter badges
    local type_counts = {
      total = file_data.total_functions,
      executed = file_data.executed_functions,
      not_executed = file_data.total_functions - file_data.executed_functions,
      global = 0,
      ["local"] = 0,
      method = 0,
      anonymous = 0,
      closure = 0
    }
    
    -- Count functions by type
    for _, func_data in pairs(file_data.functions) do
      if type_counts[func_data.type] then
        type_counts[func_data.type] = type_counts[func_data.type] + 1
      end
    end
    
    -- Add function search and filters
    html = html .. [[
  <div class="function-list">
    <h4>Functions</h4>
    <input type="text" class="function-search" placeholder="Search functions..." id="func-search-]] .. file_id .. [[">
    
    <div class="function-filter">
      <label class="function-filter-item active" data-filter="all">
        <input type="radio" name="func-filter-]] .. file_id .. [[" value="all" checked>
        All <span class="function-count">]] .. type_counts.total .. [[</span>
      </label>
      <label class="function-filter-item" data-filter="executed">
        <input type="radio" name="func-filter-]] .. file_id .. [[" value="executed">
        Executed <span class="function-count badge-success">]] .. type_counts.executed .. [[</span>
      </label>
      <label class="function-filter-item" data-filter="not-executed">
        <input type="radio" name="func-filter-]] .. file_id .. [[" value="not-executed">
        Not Executed <span class="function-count badge-danger">]] .. (type_counts.not_executed) .. [[</span>
      </label>
    </div>
    
    <div class="function-filter">
      <label class="function-filter-item" data-type="global">
        <input type="checkbox" name="func-type-]] .. file_id .. [[" value="global">
        Global <span class="function-count function-type-global">]] .. type_counts.global .. [[</span>
      </label>
      <label class="function-filter-item" data-type="local">
        <input type="checkbox" name="func-type-]] .. file_id .. [[" value="local">
        Local <span class="function-count function-type-local">]] .. type_counts["local"] .. [[</span>
      </label>
      <label class="function-filter-item" data-type="method">
        <input type="checkbox" name="func-type-]] .. file_id .. [[" value="method">
        Method <span class="function-count function-type-method">]] .. type_counts.method .. [[</span>
      </label>
      <label class="function-filter-item" data-type="anonymous">
        <input type="checkbox" name="func-type-]] .. file_id .. [[" value="anonymous">
        Anonymous <span class="function-count function-type-anonymous">]] .. type_counts.anonymous .. [[</span>
      </label>
      <label class="function-filter-item" data-type="closure">
        <input type="checkbox" name="func-type-]] .. file_id .. [[" value="closure">
        Closure <span class="function-count function-type-closure">]] .. type_counts.closure .. [[</span>
      </label>
    </div>
    
    <table class="functions" id="functions-]] .. file_id .. [[">
      <thead>
        <tr>
          <th data-sort="name">Name</th>
          <th data-sort="type">Type</th>
          <th data-sort="lines">Lines</th>
          <th data-sort="executed">Status</th>
          <th data-sort="count">Execution Count</th>
        </tr>
      </thead>
      <tbody>
]]

    -- Sort functions by start line
    local functions = {}
    for func_id, func_data in pairs(file_data.functions) do
      table.insert(functions, {id = func_id, data = func_data})
    end
    
    table.sort(functions, function(a, b) return a.data.start_line < b.data.start_line end)
    
    -- Add each function row
    for _, func in ipairs(functions) do
      local func_data = func.data
      local executed_class = func_data.executed and "executed" or "not-executed"
      local covered_class = func_data.covered and "covered" or "not-covered"
      local type_class = "function-type-" .. func_data.type
      local status_badge_class = func_data.executed and "badge-success" or "badge-danger"
      
      html = html .. [[
        <tr class="]] .. executed_class .. " " .. covered_class .. [[" data-function-type="]] .. func_data.type .. [[" data-executed="]] .. tostring(func_data.executed) .. [[">
          <td>]] .. escape_html(func_data.name) .. [[ <span class="function-type-badge ]] .. type_class .. [[">]] .. func_data.type .. [[</span></td>
          <td>]] .. func_data.type .. [[</td>
          <td><a href="#L]] .. func_data.start_line .. [[">]] .. func_data.start_line .. [[-]] .. func_data.end_line .. [[</a></td>
          <td class="]] .. executed_class .. [[">
            <span class="badge ]] .. (func_data.executed and "badge-success" or "badge-danger") .. [[">]] 
              .. (func_data.executed and "Executed" or "Not Executed") .. 
            [[</span>
          </td>
          <td>]] .. func_data.execution_count .. [[</td>
        </tr>
]]
    end
    
    html = html .. [[
      </tbody>
    </table>
  </div>
  
  <script class="function-sort-script">
  (function() {
    // Function table sorting and filtering for ]] .. escape_html(file_data.name) .. [[
    const tableId = 'functions-]] .. file_id .. [[';
    const searchId = 'func-search-]] .. file_id .. [[';
    const table = document.getElementById(tableId);
    const search = document.getElementById(searchId);
    
    if (!table || !search) return;
    
    // Sort direction state
    let sortColumn = 'lines';
    let sortDirection = 'asc';
    
    // Initial sort by line number
    sortTable('lines', 'asc');
    
    // Add click handlers to table headers
    const headers = table.querySelectorAll('th');
    headers.forEach(header => {
      if (header.dataset.sort) {
        header.addEventListener('click', () => {
          const column = header.dataset.sort;
          // Toggle direction if same column
          const direction = (column === sortColumn) 
            ? (sortDirection === 'asc' ? 'desc' : 'asc')
            : 'asc';
          
          sortTable(column, direction);
        });
      }
    });
    
    // Search input handler
    search.addEventListener('input', filterTable);
    
    // Filter radio buttons
    const filterRadios = document.querySelectorAll('[name="func-filter-]] .. file_id .. [["]');
    filterRadios.forEach(radio => {
      radio.addEventListener('change', filterTable);
    });
    
    // Type checkboxes
    const typeCheckboxes = document.querySelectorAll('[name="func-type-]] .. file_id .. [["]');
    typeCheckboxes.forEach(checkbox => {
      checkbox.addEventListener('change', filterTable);
    });
    
    // Filter the table based on search text and filters
    function filterTable() {
      const searchText = search.value.toLowerCase();
      const rows = table.querySelectorAll('tbody tr');
      
      // Get active execution filter
      const activeFilter = document.querySelector('[name="func-filter-]] .. file_id .. [["]:checked').value;
      
      // Get active type filters
      const activeTypes = Array.from(document.querySelectorAll('[name="func-type-]] .. file_id .. [["]:checked'))
        .map(cb => cb.value);
      
      // Show/hide rows based on filters
      rows.forEach(row => {
        const name = row.cells[0].textContent.toLowerCase();
        const type = row.dataset.functionType;
        const executed = row.dataset.executed === 'true';
        
        // Check search text
        const matchesSearch = searchText === '' || name.includes(searchText);
        
        // Check execution filter
        const matchesExecution = 
          activeFilter === 'all' || 
          (activeFilter === 'executed' && executed) ||
          (activeFilter === 'not-executed' && !executed);
        
        // Check type filter (if any are checked)
        const matchesType = activeTypes.length === 0 || activeTypes.includes(type);
        
        // Show/hide row
        row.style.display = (matchesSearch && matchesExecution && matchesType) ? '' : 'none';
      });
    }
    
    // Sort the table by column
    function sortTable(column, direction) {
      // Update state
      sortColumn = column;
      sortDirection = direction;
      
      // Update header classes
      headers.forEach(header => {
        header.classList.remove('sort-asc', 'sort-desc');
        if (header.dataset.sort === column) {
          header.classList.add(direction === 'asc' ? 'sort-asc' : 'sort-desc');
        }
      });
      
      // Get table body and rows
      const tbody = table.querySelector('tbody');
      const rows = Array.from(tbody.querySelectorAll('tr'));
      
      // Sort rows
      rows.sort((a, b) => {
        let valueA, valueB;
        
        // Extract values based on column
        switch(column) {
          case 'name':
            valueA = a.cells[0].textContent.toLowerCase();
            valueB = b.cells[0].textContent.toLowerCase();
            break;
          case 'type':
            valueA = a.cells[1].textContent.toLowerCase();
            valueB = b.cells[1].textContent.toLowerCase();
            break;
          case 'lines':
            valueA = parseInt(a.cells[2].textContent.split('-')[0]);
            valueB = parseInt(b.cells[2].textContent.split('-')[0]);
            break;
          case 'executed':
            valueA = a.dataset.executed === 'true' ? 1 : 0;
            valueB = b.dataset.executed === 'true' ? 1 : 0;
            break;
          case 'count':
            valueA = parseInt(a.cells[4].textContent);
            valueB = parseInt(b.cells[4].textContent);
            break;
          default:
            valueA = a.cells[0].textContent.toLowerCase();
            valueB = b.cells[0].textContent.toLowerCase();
        }
        
        // Compare values
        if (valueA === valueB) return 0;
        
        let result = typeof valueA === 'string' 
          ? valueA.localeCompare(valueB) 
          : valueA - valueB;
          
        // Reverse for descending
        return direction === 'asc' ? result : -result;
      });
      
      // Reorder DOM
      rows.forEach(row => tbody.appendChild(row));
    }
  })();
  </script>
]]
  end

  -- Get all line numbers and sort them
  local line_numbers = {}
  for line_num, _ in pairs(file_data.lines) do
    table.insert(line_numbers, line_num)
  end
  table.sort(line_numbers)
  
  -- Generate source lines
  for _, line_num in ipairs(line_numbers) do
    local line_data = file_data.lines[line_num]
    local line_class = ""
    
    -- Debug tracking
    local debug_file = io.open("html_line_debug.log", "a")
    if debug_file then
      debug_file:write(string.format("HTML: %s:%d [executable=%s, executed=%s, line_type=%s, count=%d]\n", 
        file_data.path, 
        line_num,
        tostring(line_data.executable),
        tostring(line_data.executed),
        line_data.line_type,
        line_data.execution_count
      ))
      debug_file:close()
    end
    
    -- If the line has an execution count, ensure it's properly marked
    if line_data.execution_count > 0 then
      line_data.executed = true
      if line_data.line_type ~= "comment" and line_data.line_type ~= "blank" then
        line_data.executable = true
        line_data.covered = true
      end
    end
    
    -- Determine the correct line display class
    if line_data.line_type == "comment" or 
       line_data.line_type == "blank" then
      line_class = "not-executable"
    else
      if line_data.executed or line_data.execution_count > 0 then
        line_class = "covered"
      else
        line_class = "not-covered"
      end
    end
    
    html = html .. [[
  <div class="line ]] .. line_class .. [[" id="L]] .. line_num .. [[">
    <div class="line-number"><a href="#L]] .. line_num .. [[">]] .. line_num .. [[</a></div>
]]

    -- Add execution count for executable lines
    if line_data.executable then
      html = html .. [[    <div class="execution-count">]] .. line_data.execution_count .. [[</div>]]
    else
      html = html .. [[    <div class="execution-count"></div>]]
    end

    html = html .. [[
    <div class="line-content">]] .. escape_html(line_data.content) .. [[</div>
  </div>
]]
  end
  
  html = html .. [[
</div>
]]

  return html
end

--- Generates a complete HTML coverage report
---@param coverage_data table The coverage data
---@param output_path string The path where the report should be saved
---@return boolean success Whether report generation succeeded
---@return string|nil error_message Error message if generation failed
function M.generate(coverage_data, output_path)
  -- Parameter validation
  error_handler.assert(type(coverage_data) == "table", "coverage_data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(output_path) == "string", "output_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- If output_path is a directory, add a filename
  if output_path:sub(-1) == "/" then
    output_path = output_path .. "coverage-report-v2.html"
  end
  
  -- Try to ensure the directory exists
  local dir_path = output_path:match("(.+)/[^/]+$")
  if dir_path then
    local mkdir_success, mkdir_err = fs.ensure_directory_exists(dir_path)
    if not mkdir_success then
      logger.warn("Failed to ensure directory exists, but will try to write anyway", {
        directory = dir_path,
        error = mkdir_err and error_handler.format_error(mkdir_err) or "Unknown error"
      })
    end
  end
  
  -- Validate the coverage data structure
  local is_valid, validation_error = data_structure.validate(coverage_data)
  if not is_valid then
    logger.warn("Coverage data validation failed, attempting to generate report anyway", {
      error = validation_error
    })
    -- We continue despite validation errors to maximize usability
  end
  
  -- Generate HTML content
  local html = [[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Coverage Report</title>
  <style>
]] .. CSS_STYLES .. [[
  </style>
</head>
<body>
  <h1>Coverage Report</h1>
]]

  -- Add summary section
  html = html .. generate_summary_html(coverage_data.summary)
  
  -- Add file list section
  html = html .. generate_file_list_html(coverage_data)
  
  -- Add source code sections for each file
  for path, file_data in pairs(coverage_data.files) do
    local file_id = path:gsub("[^%w]", "-")
    html = html .. generate_file_source_html(file_data, file_id)
  end
  
  -- Close HTML document
  html = html .. [[
</body>
</html>
]]

  -- Write the report to the output file
  local success, err = error_handler.safe_io_operation(
    function() 
      return fs.write_file(output_path, html)
    end,
    output_path,
    {operation = "write_html_report"}
  )
  
  if not success then
    return false, "Failed to write HTML report: " .. error_handler.format_error(err)
  end
  
  logger.info("Generated HTML coverage report", {
    output_path = output_path,
    total_files = coverage_data.summary.total_files,
    line_coverage = coverage_data.summary.line_coverage_percent .. "%"
  })
  
  return true
end

return M