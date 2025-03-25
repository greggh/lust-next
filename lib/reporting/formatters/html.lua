---@class HTMLFormatter
---@field generate fun(coverage_data: table, output_path: string): boolean, string|nil
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local data_structure = require("lib.coverage.data_structure")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")

-- Version
M._VERSION = "2.0.0"

-- Include Tailwind CSS via CDN for styling
local TAILWIND_CSS_CDN = "https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css"

-- Include Alpine.js via CDN for interactivity
local ALPINE_JS_CDN = "https://cdn.jsdelivr.net/npm/alpinejs@3.13.0/dist/cdn.min.js"

-- Include Heroicons via CDN for icons
local HEROICONS_CDN = "https://cdn.jsdelivr.net/npm/@heroicons/vue@2.0.18/dist/outline.min.js"

-- Additional custom CSS for specific features
local CUSTOM_CSS = [[
/* Coverage specific styles */
.covered {
  background-color: #dcfce7; /* bg-green-100 */
}

.not-covered {
  background-color: #fee2e2; /* bg-red-100 */
}

.not-executable {
  color: #6b7280; /* text-gray-500 */
  background-color: #f9fafb; /* bg-gray-50 */
}

.execution-count {
  display: inline-block;
  width: 3rem; /* w-12 */
  text-align: right;
  padding-right: 0.5rem; /* pr-2 */
  color: #4b5563; /* text-gray-600 */
}

/* Syntax highlighting */
.keyword {
  color: #7e22ce; /* text-purple-700 */
  font-weight: 500; /* font-medium */
}

.string {
  color: #16a34a; /* text-green-600 */
}

.comment {
  color: #6b7280; /* text-gray-500 */
  font-style: italic;
}

.number {
  color: #2563eb; /* text-blue-600 */
}

.function {
  color: #ca8a04; /* text-yellow-600 */
  font-weight: 500; /* font-medium */
}

/* Function table */
.function-row {
  transition-property: background-color;
  transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
  transition-duration: 100ms;
}

.function-row:hover {
  background-color: #f9fafb; /* hover:bg-gray-50 */
}

.function-row.executed {
  background-color: #f0fdf4; /* bg-green-50 */
}

.function-row.not-executed {
  background-color: #fef2f2; /* bg-red-50 */
}

/* Custom scrollbar for code blocks */
.source-code pre::-webkit-scrollbar {
  width: 0.5rem; /* w-2 */
  height: 0.5rem; /* h-2 */
}

.source-code pre::-webkit-scrollbar-track {
  background-color: #f3f4f6; /* bg-gray-100 */
  border-radius: 0.25rem; /* rounded */
}

.source-code pre::-webkit-scrollbar-thumb {
  background-color: #9ca3af; /* bg-gray-400 */
  border-radius: 0.25rem; /* rounded */
}

.source-code pre::-webkit-scrollbar-thumb:hover {
  background-color: #6b7280; /* hover:bg-gray-500 */
}

/* Print specific styles */
@media print {
  .no-print {
    display: none !important;
  }
  
  .print-break-inside-avoid {
    break-inside: avoid;
  }
  
  .print-break-before {
    break-before: page;
  }
}
]]

-- Alpine.js components for interactive features
local ALPINE_COMPONENTS = [[
// File list filtering component
window.fileListFilter = function() {
  return {
    searchQuery: '',
    selectedCoverage: 'all',
    showArchived: false,
    
    get filteredFiles() {
      let files = this.files;
      
      // Filter by search query
      if (this.searchQuery.trim() !== '') {
        const query = this.searchQuery.toLowerCase();
        files = files.filter(file => 
          file.path.toLowerCase().includes(query)
        );
      }
      
      // Filter by coverage level
      if (this.selectedCoverage !== 'all') {
        files = files.filter(file => {
          const coverage = parseFloat(file.coverage);
          if (this.selectedCoverage === 'high') return coverage >= 80;
          if (this.selectedCoverage === 'medium') return coverage >= 50 && coverage < 80;
          if (this.selectedCoverage === 'low') return coverage < 50;
          return true;
        });
      }
      
      return files;
    }
  };
}

// Function list filtering and sorting component
window.functionList = function() {
  return {
    searchQuery: '',
    typeFilters: [],
    statusFilter: 'all',
    sortColumn: 'lines',
    sortDirection: 'asc',
    
    toggleSort(column) {
      if (this.sortColumn === column) {
        this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
      } else {
        this.sortColumn = column;
        this.sortDirection = 'asc';
      }
    },
    
    getSortedFunctions() {
      let functions = [...this.functions];
      
      // Apply sorting
      functions.sort((a, b) => {
        let aValue = a[this.sortColumn];
        let bValue = b[this.sortColumn];
        
        if (this.sortColumn === 'lines') {
          aValue = parseInt(a.startLine);
          bValue = parseInt(b.startLine);
        } else if (this.sortColumn === 'count') {
          aValue = parseInt(a.executionCount);
          bValue = parseInt(b.executionCount);
        }
        
        if (aValue < bValue) return this.sortDirection === 'asc' ? -1 : 1;
        if (aValue > bValue) return this.sortDirection === 'asc' ? 1 : -1;
        return 0;
      });
      
      return functions;
    },
    
    get filteredFunctions() {
      let functions = this.getSortedFunctions();
      
      // Filter by search query
      if (this.searchQuery.trim() !== '') {
        const query = this.searchQuery.toLowerCase();
        functions = functions.filter(func => 
          func.name.toLowerCase().includes(query)
        );
      }
      
      // Filter by type
      if (this.typeFilters.length > 0) {
        functions = functions.filter(func => 
          this.typeFilters.includes(func.type)
        );
      }
      
      // Filter by execution status
      if (this.statusFilter !== 'all') {
        functions = functions.filter(func => {
          if (this.statusFilter === 'executed') return func.executed;
          if (this.statusFilter === 'not-executed') return !func.executed;
          return true;
        });
      }
      
      return functions;
    },
    
    getSortIcon(column) {
      if (this.sortColumn !== column) return 'none';
      return this.sortDirection === 'asc' ? 'asc' : 'desc';
    }
  };
}

// Line highlighting component
window.lineHighlighting = function() {
  return {
    init() {
      // Set up line highlighting
      const hashId = window.location.hash;
      if (hashId && hashId.startsWith('#L')) {
        const lineElem = document.querySelector(hashId);
        if (lineElem) {
          lineElem.classList.add('bg-yellow-100');
          lineElem.scrollIntoView({behavior: 'smooth', block: 'center'});
        }
      }
      
      // Set up line linking
      document.querySelectorAll('.line-number a').forEach(link => {
        link.addEventListener('click', (e) => {
          // Remove existing highlights
          document.querySelectorAll('.bg-yellow-100').forEach(el => {
            if (el.classList.contains('line')) {
              el.classList.remove('bg-yellow-100');
            }
          });
          
          // Add highlight to clicked line
          const lineId = link.getAttribute('href');
          const lineElem = document.querySelector(lineId);
          if (lineElem) {
            lineElem.classList.add('bg-yellow-100');
          }
        });
      });
    }
  };
}

// Source code syntax highlighting component
window.syntaxHighlighting = function() {
  return {
    highlightSyntax(code) {
      // Simple Lua syntax highlighting
      return code
        .replace(/\\b(function|local|end|if|then|else|elseif|for|in|do|while|repeat|until|return|break|nil|true|false|and|or|not)\\b/g, '<span class="keyword">$1</span>')
        .replace(/("[^"]*")/g, '<span class="string">$1</span>')
        .replace(/(--[^\\n]*)/g, '<span class="comment">$1</span>')
        .replace(/\\b(\\d+)\\b/g, '<span class="number">$1</span>');
    }
  };
}
]]

--- Escapes HTML special characters
---@param text string The text to escape
---@return string escaped_text The escaped text
local function escape_html(text)
  return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

--- Generates the HTML overview section
---@param coverage_data table The coverage data
---@return string html The HTML code for the overview section
local function generate_overview_html(coverage_data)
  local summary = coverage_data.summary
  local file_count = summary.total_files
  local line_coverage = math.floor(summary.line_coverage_percent + 0.5)
  local function_coverage = math.floor(summary.function_coverage_percent + 0.5)
  local executed_files = summary.executed_files
  local executed_lines = summary.executed_lines
  local total_lines = summary.total_lines
  local executable_lines = summary.executable_lines
  local executed_functions = summary.executed_functions
  local total_functions = summary.total_functions
  
  -- Calculate coverage grade
  local coverage_grade = "F"
  local coverage_color = "bg-red-500"
  
  if line_coverage >= 90 then
    coverage_grade = "A"
    coverage_color = "bg-green-500"
  elseif line_coverage >= 80 then
    coverage_grade = "B"
    coverage_color = "bg-green-400"
  elseif line_coverage >= 70 then
    coverage_grade = "C"
    coverage_color = "bg-yellow-400"
  elseif line_coverage >= 60 then
    coverage_grade = "D"
    coverage_color = "bg-yellow-500"
  elseif line_coverage >= 50 then
    coverage_grade = "E"
    coverage_color = "bg-orange-500"
  end
  
  local html = [[
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="flex items-center justify-between mb-8">
      <h1 class="text-3xl font-bold text-gray-900">Coverage Report</h1>
      <div class="flex space-x-2">
        <button onclick="window.print()" class="no-print inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
          </svg>
          Print
        </button>
        <div class="relative" x-data="{ open: false }">
          <button @click="open = !open" class="no-print inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
            </svg>
            Export
          </button>
          <div x-show="open" @click.away="open = false" class="origin-top-right absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5">
            <div class="py-1">
              <a href="#" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">Export as JSON</a>
              <a href="#" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">Export as LCOV</a>
              <a href="#" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">Export as XML</a>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <div class="bg-white shadow overflow-hidden sm:rounded-lg mb-8">
      <div class="border-b border-gray-200 px-4 py-5 sm:px-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900">Coverage Summary</h3>
        <p class="mt-1 max-w-2xl text-sm text-gray-500">Coverage information for ]] .. file_count .. [[ files.</p>
      </div>
      
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 p-6">
        <!-- Overall Coverage Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
          <div class="px-6 py-5 flex items-center justify-between">
            <span class="text-lg font-medium text-gray-900">Overall Coverage</span>
            <span class="inline-flex items-center px-3 py-0.5 rounded-full text-sm font-medium ]] .. coverage_color .. [[ text-white">
              Grade ]] .. coverage_grade .. [[
            </span>
          </div>
          <div class="px-6 py-5">
            <div class="flex items-end">
              <h3 class="text-5xl font-extrabold text-gray-900">]] .. line_coverage .. [[%</h3>
              <p class="ml-2 text-sm text-gray-500">line coverage</p>
            </div>
            <div class="mt-4 w-full bg-gray-200 rounded-full h-2.5">
              <div class="]] .. coverage_color .. [[ h-2.5 rounded-full" style="width: ]] .. line_coverage .. [[%"></div>
            </div>
            <div class="mt-4 grid grid-cols-2 gap-4">
              <div>
                <dt class="text-sm font-medium text-gray-500 truncate">Lines Covered</dt>
                <dd class="mt-1 text-xl font-semibold text-gray-900">]] .. executed_lines .. [[ / ]] .. executable_lines .. [[</dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500 truncate">Functions Covered</dt>
                <dd class="mt-1 text-xl font-semibold text-gray-900">]] .. executed_functions .. [[ / ]] .. total_functions .. [[</dd>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Line Coverage Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="px-6 py-5">
            <h3 class="text-lg font-medium text-gray-900">Line Coverage</h3>
            <div class="mt-2 flex items-center">
              <div class="flex-1">
                <div class="flex items-end">
                  <h4 class="text-4xl font-extrabold text-gray-900">]] .. line_coverage .. [[%</h4>
                  <p class="ml-2 text-sm text-gray-500">]] .. executed_lines .. [[ / ]] .. executable_lines .. [[ lines</p>
                </div>
                <div class="mt-4 w-full bg-gray-200 rounded-full h-2.5">
                  <div class="bg-blue-500 h-2.5 rounded-full" style="width: ]] .. line_coverage .. [[%"></div>
                </div>
              </div>
            </div>
            <div class="mt-4">
              <div class="grid grid-cols-2 gap-2">
                <div class="text-sm">
                  <span class="text-gray-500">Total:</span>
                  <span class="font-medium text-gray-900">]] .. total_lines .. [[ lines</span>
                </div>
                <div class="text-sm">
                  <span class="text-gray-500">Executable:</span>
                  <span class="font-medium text-gray-900">]] .. executable_lines .. [[ lines</span>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Function Coverage Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="px-6 py-5">
            <h3 class="text-lg font-medium text-gray-900">Function Coverage</h3>
            <div class="mt-2 flex items-center">
              <div class="flex-1">
                <div class="flex items-end">
                  <h4 class="text-4xl font-extrabold text-gray-900">]] .. function_coverage .. [[%</h4>
                  <p class="ml-2 text-sm text-gray-500">]] .. executed_functions .. [[ / ]] .. total_functions .. [[ functions</p>
                </div>
                <div class="mt-4 w-full bg-gray-200 rounded-full h-2.5">
                  <div class="bg-indigo-500 h-2.5 rounded-full" style="width: ]] .. function_coverage .. [[%"></div>
                </div>
              </div>
            </div>
            <div class="mt-4">
              <div class="grid grid-cols-2 gap-2">
                <div class="text-sm">
                  <span class="text-gray-500">Global:</span>
                  <span class="font-medium text-gray-900">]] .. (summary.global_functions or 0) .. [[ functions</span>
                </div>
                <div class="text-sm">
                  <span class="text-gray-500">Local:</span>
                  <span class="font-medium text-gray-900">]] .. (summary.local_functions or 0) .. [[ functions</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
  ]]

  return html
end

--- Generates the HTML file list section
---@param coverage_data table The coverage data
---@return string html The HTML code for the file list section
---@return string file_data_json JSON data for the file list
local function generate_file_list_html(coverage_data)
  -- Prepare file data
  local files = {}
  local file_data_array = {}
  
  for path, file_data in pairs(coverage_data.files) do
    table.insert(files, { 
      path = path, 
      data = file_data,
      coverage = file_data.line_coverage_percent,
      coverage_class = file_data.line_coverage_percent >= 80 and "high" or (file_data.line_coverage_percent >= 50 and "medium" or "low")
    })
    
    -- Build file data array for Alpine.js
    table.insert(file_data_array, {
      path = path,
      coverage = tostring(file_data.line_coverage_percent),
      executable_lines = file_data.executable_lines,
      executed_lines = file_data.executed_lines,
      total_functions = file_data.total_functions
    })
  end
  
  -- Sort files by path
  table.sort(files, function(a, b) return a.path < b.path end)
  
  -- Convert file data to JSON for Alpine.js
  local file_data_json = "["
  for i, file in ipairs(file_data_array) do
    file_data_json = file_data_json .. [[
      {
        "path": "]] .. file.path .. [[",
        "coverage": "]] .. file.coverage .. [[",
        "executable_lines": ]] .. file.executable_lines .. [[,
        "executed_lines": ]] .. file.executed_lines .. [[,
        "total_functions": ]] .. file.total_functions .. [[
      }]] .. (i < #file_data_array and "," or "")
  end
  file_data_json = file_data_json .. "]"
  
  local html = [[
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6" x-data="fileListFilter()" x-init="files = JSON.parse(']] .. file_data_json:gsub("'", "\\'") .. [[')">
    <div class="bg-white shadow overflow-hidden sm:rounded-lg">
      <div class="border-b border-gray-200 px-4 py-5 sm:px-6">
        <div class="flex flex-col md:flex-row md:items-center md:justify-between">
          <div>
            <h3 class="text-lg leading-6 font-medium text-gray-900">Covered Files</h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">]] .. #files .. [[ files tracked for coverage</p>
          </div>
          <div class="mt-4 md:mt-0 flex flex-wrap items-center gap-2">
            <div class="relative rounded-md shadow-sm">
              <input
                type="text"
                x-model="searchQuery"
                placeholder="Search files..."
                class="focus:ring-indigo-500 focus:border-indigo-500 block w-full pr-10 sm:text-sm border-gray-300 rounded-md"
              />
              <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
                <svg class="h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fill-rule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd" />
                </svg>
              </div>
            </div>

            <div class="flex space-x-1">
              <button 
                @click="selectedCoverage = 'all'" 
                :class="{'bg-indigo-100 text-indigo-800': selectedCoverage === 'all', 'bg-white text-gray-600': selectedCoverage !== 'all'}"
                class="inline-flex items-center px-2.5 py-1.5 border border-gray-300 text-xs font-medium rounded hover:bg-gray-50 focus:outline-none"
              >
                All
              </button>
              <button 
                @click="selectedCoverage = 'high'" 
                :class="{'bg-green-100 text-green-800': selectedCoverage === 'high', 'bg-white text-gray-600': selectedCoverage !== 'high'}"
                class="inline-flex items-center px-2.5 py-1.5 border border-gray-300 text-xs font-medium rounded hover:bg-gray-50 focus:outline-none"
              >
                High
              </button>
              <button 
                @click="selectedCoverage = 'medium'" 
                :class="{'bg-yellow-100 text-yellow-800': selectedCoverage === 'medium', 'bg-white text-gray-600': selectedCoverage !== 'medium'}"
                class="inline-flex items-center px-2.5 py-1.5 border border-gray-300 text-xs font-medium rounded hover:bg-gray-50 focus:outline-none"
              >
                Medium
              </button>
              <button 
                @click="selectedCoverage = 'low'" 
                :class="{'bg-red-100 text-red-800': selectedCoverage === 'low', 'bg-white text-gray-600': selectedCoverage !== 'low'}"
                class="inline-flex items-center px-2.5 py-1.5 border border-gray-300 text-xs font-medium rounded hover:bg-gray-50 focus:outline-none"
              >
                Low
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                File
              </th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Coverage
              </th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Lines
              </th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Functions
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <template x-for="file in filteredFiles" :key="file.path">
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <div class="flex-shrink-0 h-10 w-10 flex items-center justify-center bg-gray-100 rounded">
                      <svg class="h-6 w-6 text-gray-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                      </svg>
                    </div>
                    <div class="ml-4">
                      <a :href="'#file-' + file.path.replace(/[^\\w]/g, '-')" class="text-sm font-medium text-indigo-600 hover:text-indigo-900 hover:underline">
                        <span x-text="file.path"></span>
                      </a>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <div>
                      <div class="text-sm font-medium text-gray-900" x-text="file.coverage + '%'"></div>
                      <div class="w-full bg-gray-200 rounded-full h-2.5">
                        <div 
                          :class="{
                            'bg-green-500': parseFloat(file.coverage) >= 80,
                            'bg-yellow-500': parseFloat(file.coverage) >= 50 && parseFloat(file.coverage) < 80,
                            'bg-red-500': parseFloat(file.coverage) < 50
                          }"
                          class="h-2.5 rounded-full" 
                          :style="'width: ' + file.coverage + '%'"
                        ></div>
                      </div>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm text-gray-900">
                    <span x-text="file.executed_lines"></span> / <span x-text="file.executable_lines"></span>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <span x-text="file.total_functions"></span>
                </td>
              </tr>
            </template>
            <tr x-show="filteredFiles.length === 0">
              <td colspan="4" class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 text-center">
                No matching files found.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
  ]]

  return html, file_data_json
end

--- Generates the function list for a file
---@param file_data table The file data
---@param file_id string The file ID for DOM references
---@return string html The HTML code for the function list
---@return string functions_json JSON data for the functions
local function generate_function_list(file_data, file_id)
  if not file_data.functions or file_data.total_functions == 0 then
    return "", "[]"
  end
  
  -- Prepare function data for Alpine.js
  local functions_array = {}
  local functions_by_type = {
    global = 0,
    local_func = 0, -- Changed 'local' to 'local_func' to avoid Lua keyword conflict
    method = 0,
    anonymous = 0,
    closure = 0
  }
  
  for func_id, func_data in pairs(file_data.functions) do
    if func_data then
      local func_entry = {
        id = func_id,
        name = func_data.name or "anonymous",
        type = func_data.type or "anonymous",
        startLine = func_data.start_line or 0,
        endLine = func_data.end_line or 0,
        executed = func_data.executed and "true" or "false",
        executionCount = func_data.execution_count or 0
      }
      
      table.insert(functions_array, func_entry)
      
      -- Count by type
      local type_key = func_data.type
      if type_key == "local" then
        type_key = "local_func" -- Convert "local" type to "local_func" key
      end
      
      if functions_by_type[type_key] ~= nil then
        functions_by_type[type_key] = functions_by_type[type_key] + 1
      end
    end
  end
  
  -- Convert to JSON for Alpine.js
  local functions_json = "["
  for i, func in ipairs(functions_array) do
    functions_json = functions_json .. [[
      {
        "id": "]] .. func.id .. [[",
        "name": "]] .. func.name .. [[",
        "type": "]] .. func.type .. [[",
        "startLine": ]] .. func.startLine .. [[,
        "endLine": ]] .. func.endLine .. [[,
        "executed": ]] .. func.executed .. [[,
        "executionCount": ]] .. func.executionCount .. [[
      }]] .. (i < #functions_array and "," or "")
  end
  functions_json = functions_json .. "]"
  
  -- Create the HTML
  local html = [[
  <div x-data="functionList()" x-init="functions = JSON.parse(']] .. functions_json:gsub("'", "\\'") .. [[')">
    <h4 class="text-base font-medium text-gray-900 mt-8 mb-4">Functions (]] .. file_data.total_functions .. [[)</h4>
    
    <div class="mb-4 flex flex-col sm:flex-row sm:items-center space-y-2 sm:space-y-0 sm:space-x-2">
      <div class="relative rounded-md shadow-sm flex-grow">
        <input
          type="text"
          x-model="searchQuery"
          placeholder="Search functions..."
          class="focus:ring-indigo-500 focus:border-indigo-500 block w-full pr-10 sm:text-sm border-gray-300 rounded-md"
          id="func-search-]] .. file_id .. [["
        />
        <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
          <svg class="h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path fill-rule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd" />
          </svg>
        </div>
      </div>
      
      <div class="flex space-x-1">
        <button 
          @click="statusFilter = 'all'" 
          :class="{'bg-indigo-100 text-indigo-800': statusFilter === 'all', 'bg-white text-gray-600': statusFilter !== 'all'}"
          class="inline-flex items-center px-2.5 py-1.5 border border-gray-300 text-xs font-medium rounded hover:bg-gray-50 focus:outline-none"
        >
          All
        </button>
        <button 
          @click="statusFilter = 'executed'" 
          :class="{'bg-green-100 text-green-800': statusFilter === 'executed', 'bg-white text-gray-600': statusFilter !== 'executed'}"
          class="inline-flex items-center px-2.5 py-1.5 border border-gray-300 text-xs font-medium rounded hover:bg-gray-50 focus:outline-none"
        >
          Executed
        </button>
        <button 
          @click="statusFilter = 'not-executed'" 
          :class="{'bg-red-100 text-red-800': statusFilter === 'not-executed', 'bg-white text-gray-600': statusFilter !== 'not-executed'}"
          class="inline-flex items-center px-2.5 py-1.5 border border-gray-300 text-xs font-medium rounded hover:bg-gray-50 focus:outline-none"
        >
          Not Executed
        </button>
      </div>
    </div>
    
    <div class="flex flex-wrap mb-4 gap-2">
      <template x-for="(count, type) in {
        global: ]] .. functions_by_type.global .. [[,
        local: ]] .. functions_by_type.local_func .. [[,
        method: ]] .. functions_by_type.method .. [[,
        anonymous: ]] .. functions_by_type.anonymous .. [[,
        closure: ]] .. functions_by_type.closure .. [[
      }" :key="type">
        <label 
          class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium cursor-pointer"
          :class="{
            'bg-gray-100 text-gray-800': !typeFilters.includes(type),
            'bg-indigo-100 text-indigo-800': typeFilters.includes(type)
          }"
        >
          <input 
            type="checkbox" 
            class="form-checkbox h-3 w-3 text-indigo-600 mr-1.5" 
            :value="type" 
            x-model="typeFilters"
          />
          <span x-text="type.charAt(0).toUpperCase() + type.slice(1)"></span>
          <span class="ml-1 text-gray-500" x-text="count"></span>
        </label>
      </template>
    </div>

    <div class="overflow-x-auto shadow border-b border-gray-200 sm:rounded-lg">
      <table class="min-w-full divide-y divide-gray-200" id="functions-]] .. file_id .. [[">
        <thead class="bg-gray-50">
          <tr>
            <th scope="col" class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer" @click="toggleSort('name')">
              <div class="flex items-center">
                Name
                <svg x-show="getSortIcon('name') === 'asc'" class="ml-1 h-3 w-3" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z" clip-rule="evenodd" />
                </svg>
                <svg x-show="getSortIcon('name') === 'desc'" class="ml-1 h-3 w-3" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </div>
            </th>
            <th scope="col" class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer" @click="toggleSort('type')">
              <div class="flex items-center">
                Type
                <svg x-show="getSortIcon('type') === 'asc'" class="ml-1 h-3 w-3" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z" clip-rule="evenodd" />
                </svg>
                <svg x-show="getSortIcon('type') === 'desc'" class="ml-1 h-3 w-3" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </div>
            </th>
            <th scope="col" class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer" @click="toggleSort('lines')">
              <div class="flex items-center">
                Lines
                <svg x-show="getSortIcon('lines') === 'asc'" class="ml-1 h-3 w-3" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z" clip-rule="evenodd" />
                </svg>
                <svg x-show="getSortIcon('lines') === 'desc'" class="ml-1 h-3 w-3" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </div>
            </th>
            <th scope="col" class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer" @click="toggleSort('executed')">
              <div class="flex items-center">
                Status
                <svg x-show="getSortIcon('executed') === 'asc'" class="ml-1 h-3 w-3" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z" clip-rule="evenodd" />
                </svg>
                <svg x-show="getSortIcon('executed') === 'desc'" class="ml-1 h-3 w-3" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </div>
            </th>
            <th scope="col" class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer" @click="toggleSort('count')">
              <div class="flex items-center">
                Count
                <svg x-show="getSortIcon('count') === 'asc'" class="ml-1 h-3 w-3" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z" clip-rule="evenodd" />
                </svg>
                <svg x-show="getSortIcon('count') === 'desc'" class="ml-1 h-3 w-3" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </div>
            </th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <template x-for="func in filteredFunctions" :key="func.id">
            <tr 
              class="function-row"
              :class="{
                'executed': func.executed === 'true',
                'not-executed': func.executed === 'false'
              }"
            >
              <td class="px-4 py-3 whitespace-nowrap text-sm">
                <div class="flex items-center">
                  <span class="font-medium text-gray-900" x-text="func.name"></span>
                </div>
              </td>
              <td class="px-4 py-3 whitespace-nowrap text-sm">
                <span 
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                  :class="{
                    'bg-blue-100 text-blue-800': func.type === 'global',
                    'bg-green-100 text-green-800': func.type === 'local',
                    'bg-purple-100 text-purple-800': func.type === 'method',
                    'bg-yellow-100 text-yellow-800': func.type === 'anonymous',
                    'bg-pink-100 text-pink-800': func.type === 'closure'
                  }"
                >
                  <span x-text="func.type"></span>
                </span>
              </td>
              <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-700">
                <a 
                  :href="'#L' + func.startLine" 
                  class="text-indigo-600 hover:text-indigo-900 hover:underline"
                  x-text="func.startLine === func.endLine ? func.startLine : func.startLine + '-' + func.endLine"
                ></a>
              </td>
              <td class="px-4 py-3 whitespace-nowrap text-sm">
                <span 
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                  :class="{
                    'bg-green-100 text-green-800': func.executed === 'true',
                    'bg-red-100 text-red-800': func.executed === 'false'
                  }"
                >
                  <span x-text="func.executed === 'true' ? 'Executed' : 'Not Executed'"></span>
                </span>
              </td>
              <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                <span x-text="func.executionCount"></span>
              </td>
            </tr>
          </template>
          <tr x-show="filteredFunctions.length === 0">
            <td colspan="5" class="px-4 py-4 whitespace-nowrap text-sm text-gray-500 text-center">
              No matching functions found.
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  ]]
  
  return html, functions_json
end

--- Generates the HTML source code section for a file
---@param file_data table The file data
---@param file_id string The file ID for anchor links
---@return string html The HTML code for the source code section
local function generate_file_source_html(file_data, file_id)
  -- Get all line numbers and sort them
  local line_numbers = {}
  for line_num, _ in pairs(file_data.lines) do
    table.insert(line_numbers, line_num)
  end
  table.sort(line_numbers)
  
  -- Create function list
  local function_list_html, functions_json = generate_function_list(file_data, file_id)
  
  local html = [[
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 print-break-before">
    <div class="bg-white shadow overflow-hidden sm:rounded-lg mb-8" id="file-]] .. file_id .. [[">
      <div class="border-b border-gray-200 px-6 py-5">
        <div class="flex flex-col md:flex-row md:items-center md:justify-between">
          <div>
            <h3 class="text-lg leading-6 font-medium text-gray-900">]] .. file_data.path .. [[</h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">]] .. file_data.total_lines .. [[ lines (]] .. file_data.executable_lines .. [[ executable)</p>
          </div>
          <div class="mt-4 md:mt-0 inline-flex rounded-md shadow-sm no-print">
            <button 
              onclick="document.querySelectorAll('#file-]] .. file_id .. [[ pre').forEach(el => el.classList.toggle('whitespace-pre-wrap'))"
              class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16m-7 6h7" />
              </svg>
              Toggle Wrap
            </button>
          </div>
        </div>
      </div>
      
      <div class="px-6 py-5 flex flex-col md:flex-row">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 flex-grow">
          <!-- Coverage Summary -->
          <div class="bg-white overflow-hidden border border-gray-200 rounded-lg">
            <div class="border-b border-gray-200 px-4 py-3">
              <h4 class="text-sm font-medium text-gray-900">Line Coverage</h4>
            </div>
            <div class="px-4 py-3">
              <div class="flex items-center">
                <div class="flex-1 flex items-center">
                  <div class="text-3xl font-bold text-gray-900">]] .. math.floor(file_data.line_coverage_percent + 0.5) .. [[%</div>
                  <div class="ml-3 flex-1">
                    <div class="text-sm text-gray-500">
                      ]] .. file_data.covered_lines .. [[ / ]] .. file_data.executable_lines .. [[ lines
                    </div>
                    <div class="w-full bg-gray-200 rounded-full h-2 mt-1">
                      <div class="]] .. (file_data.line_coverage_percent >= 80 and "bg-green-500" or (file_data.line_coverage_percent >= 50 and "bg-yellow-500" or "bg-red-500")) .. [[ h-2 rounded-full" style="width: ]] .. file_data.line_coverage_percent .. [[%"></div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          
          <!-- Function Coverage -->
          <div class="bg-white overflow-hidden border border-gray-200 rounded-lg">
            <div class="border-b border-gray-200 px-4 py-3">
              <h4 class="text-sm font-medium text-gray-900">Function Coverage</h4>
            </div>
            <div class="px-4 py-3">
              <div class="flex items-center">
                <div class="flex-1 flex items-center">
                  <div class="text-3xl font-bold text-gray-900">]] .. file_data.function_coverage_percent .. [[%</div>
                  <div class="ml-3 flex-1">
                    <div class="text-sm text-gray-500">
                      ]] .. file_data.executed_functions .. [[ / ]] .. file_data.total_functions .. [[ functions
                    </div>
                    <div class="w-full bg-gray-200 rounded-full h-2 mt-1">
                      <div class="]] .. (file_data.function_coverage_percent >= 80 and "bg-green-500" or (file_data.function_coverage_percent >= 50 and "bg-yellow-500" or "bg-red-500")) .. [[ h-2 rounded-full" style="width: ]] .. file_data.function_coverage_percent .. [[%"></div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          
          <!-- Line Classification -->
          <div class="bg-white overflow-hidden border border-gray-200 rounded-lg">
            <div class="border-b border-gray-200 px-4 py-3">
              <h4 class="text-sm font-medium text-gray-900">Line Classification</h4>
            </div>
            <div class="px-4 py-3">
              <div class="flex items-center justify-between mb-2">
                <div class="text-sm font-medium text-gray-900">Code</div>
                <div class="text-sm text-gray-500">]] .. file_data.executable_lines .. [[ lines</div>
              </div>
              <div class="flex items-center justify-between mb-2">
                <div class="text-sm font-medium text-gray-900">Comment</div>
                <div class="text-sm text-gray-500">]] .. (file_data.comment_lines or 0) .. [[ lines</div>
              </div>
              <div class="flex items-center justify-between">
                <div class="text-sm font-medium text-gray-900">Blank</div>
                <div class="text-sm text-gray-500">]] .. (file_data.blank_lines or 0) .. [[ lines</div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      ]] .. function_list_html .. [[
      
      <div class="px-6 py-5">
        <div class="source-code" x-data="lineHighlighting()" x-init="init()">
          <div x-data="syntaxHighlighting()">
            <div class="bg-gray-50 border border-gray-200 rounded-lg overflow-hidden print-break-inside-avoid">
              <div class="flex">
                <div class="bg-gray-100 text-right border-r border-gray-200 px-3 py-2 select-none">
                  <pre class="font-mono text-xs text-gray-600">
  ]]

  -- Generate line numbers
  for i, line_num in ipairs(line_numbers) do
    html = html .. line_num .. "\n"
  end

  html = html .. [[
                  </pre>
                </div>
                <div class="flex-1 overflow-x-auto">
                  <pre class="font-mono text-xs whitespace-pre pl-2 py-2">
  ]]
  
  -- Generate execution count column
  for i, line_num in ipairs(line_numbers) do
    local line_data = file_data.lines[line_num]
    local count = ""
    
    if line_data.executable then
      count = tostring(line_data.execution_count)
    end
    
    html = html .. count .. "\n"
  end
  
  html = html .. [[
                  </pre>
                </div>
                <div class="flex-1 overflow-x-auto flex-grow">
                  <pre class="font-mono text-xs whitespace-pre pl-2 py-2">
  ]]
  
  -- Generate source code lines with syntax highlighting
  for i, line_num in ipairs(line_numbers) do
    local line_data = file_data.lines[line_num]
    local line_content = line_data.content or ""
    local line_class = ""
    
    if line_data.line_type == "comment" or line_data.line_type == "blank" then
      line_class = "not-executable"
    else
      -- Check execution count for executability and coverage
      if line_data.execution_count > 0 then
        line_class = "covered"
      else
        line_class = "not-covered"
      end
    end
    
    html = html .. '<span id="L' .. line_num .. '" class="' .. line_class .. '">' .. 
           '<span x-html="highlightSyntax(\'' .. escape_html(line_content):gsub("'", "\\'") .. '\')"></span>' .. 
           '</span>\n'
  end
  
  html = html .. [[
                  </pre>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
  ]]
  
  return html
end

--- Generates a complete HTML coverage report
---@param coverage_data table The coverage data
---@param output_path string The path where the report should be saved
---@return boolean success Whether report generation succeeded
---@return string|nil error_message Error message if generation failed
-- Format coverage data into HTML (this is the function expected by the formatters module)
---@param coverage_data table The coverage data
---@return string html_output The HTML report content
function M.format_coverage(coverage_data)
  -- Parameter validation
  error_handler.assert(type(coverage_data) == "table", "coverage_data must be a table", error_handler.CATEGORY.VALIDATION)
  
  -- Get formatter config
  local formatter_config = {}
  local central_config_module = require("lib.core.central_config")
  if central_config_module then
    formatter_config = central_config_module.get("reporting.formatters.html") or {}
  end
  
  -- Generate HTML components
  local overview_html = generate_overview_html(coverage_data)
  local file_list_html = generate_file_list_html(coverage_data)
  
  -- Generate source code sections for each file
  local source_sections = ""
  for path, file_data in pairs(coverage_data.files) do
    local file_id = path:gsub("[^%w]", "-")
    source_sections = source_sections .. generate_file_source_html(file_data, file_id)
  end
  
  -- Generate full HTML document
  local html = [[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Coverage Report</title>
  <link rel="stylesheet" href="]] .. TAILWIND_CSS_CDN .. [[">
  <style>
]] .. CUSTOM_CSS .. [[
  </style>
  <script defer src="]] .. ALPINE_JS_CDN .. [["></script>
  <script>
    document.addEventListener('alpine:init', function() {
      // Initialize Alpine components
]] .. ALPINE_COMPONENTS .. [[
    });
  </script>
</head>
<body class="bg-gray-100 min-h-screen">
  <!-- Report Header -->
  <header class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Coverage Report</h1>
          <p class="mt-2 text-sm text-gray-500">Coverage v2.0 - Generated ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[</p>
        </div>
        <div class="flex space-x-2 no-print">
          <a href="#overview" class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
            Overview
          </a>
          <a href="#files" class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
            Files
          </a>
        </div>
      </div>
    </div>
  </header>

  <!-- Report Body -->
  <main>
    <div id="overview">
      ]] .. overview_html .. [[
    </div>
    
    <div id="files">
      ]] .. file_list_html .. [[
    </div>
    
    <div id="source-sections">
      ]] .. source_sections .. [[
    </div>
  </main>
  
  <!-- Report Footer -->
  <footer class="bg-white mt-12 no-print">
    <div class="max-w-7xl mx-auto py-12 px-4 overflow-hidden sm:px-6 lg:px-8">
      <p class="mt-8 text-center text-base text-gray-400">
        Coverage report generated by Firmo Coverage v2.0
      </p>
    </div>
  </footer>
</body>
</html>]]
  
  return html
end

-- Original generate function used by the coverage module directly
function M.generate(coverage_data, output_path)
  -- Parameter validation
  error_handler.assert(type(coverage_data) == "table", "coverage_data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(output_path) == "string", "output_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- If output_path is a directory, add a filename
  if output_path:sub(-1) == "/" then
    output_path = output_path .. "coverage-report.html"
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
  
  -- Generate report sections
  local overview_html = generate_overview_html(coverage_data)
  local file_list_html, file_data_json = generate_file_list_html(coverage_data)
  
  -- Generate source code sections for each file
  local source_sections = ""
  for path, file_data in pairs(coverage_data.files) do
    local file_id = path:gsub("[^%w]", "-")
    source_sections = source_sections .. generate_file_source_html(file_data, file_id)
  end
  
  -- Generate HTML content
  local html = [[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Coverage Report</title>
  <link rel="stylesheet" href="]] .. TAILWIND_CSS_CDN .. [[">
  <style>
]] .. CUSTOM_CSS .. [[
  </style>
  <script defer src="]] .. ALPINE_JS_CDN .. [["></script>
  <script>
]] .. ALPINE_COMPONENTS .. [[
  </script>
</head>
<body class="bg-gray-100 min-h-screen">
  <!-- Report Header -->
  <header class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Coverage Report</h1>
          <p class="mt-2 text-sm text-gray-500">Coverage v2.0 - Generated ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[</p>
        </div>
        <div class="flex space-x-2 no-print">
          <a href="#overview" class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
            Overview
          </a>
          <a href="#files" class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
            Files
          </a>
        </div>
      </div>
    </div>
  </header>

  <!-- Report Body -->
  <main>
    <div id="overview">
      ]] .. overview_html .. [[
    </div>
    
    <div id="files">
      ]] .. file_list_html .. [[
    </div>
    
    <div id="source-sections">
      ]] .. source_sections .. [[
    </div>
  </main>
  
  <!-- Report Footer -->
  <footer class="bg-white mt-12 no-print">
    <div class="max-w-7xl mx-auto py-12 px-4 overflow-hidden sm:px-6 lg:px-8">
      <p class="mt-8 text-center text-base text-gray-400">
        Coverage report generated by Firmo Coverage v2.0
      </p>
    </div>
  </footer>
</body>
</html>]]

  -- Generate the HTML content using the format_coverage function
  local html = M.format_coverage(coverage_data)
  
  -- Write the report to the output file
  local success, err = error_handler.safe_io_operation(
    function() 
      return fs.write_file(output_path, html)
    end,
    output_path,
    {operation = "write_coverage_report"}
  )
  
  if not success then
    logger.error("Failed to write HTML coverage report", {
      file_path = output_path,
      error = error_handler.format_error(err)
    })
    return false, err
  end
  
  logger.debug("Successfully wrote HTML coverage report", {
    file_path = output_path,
    report_size = #html
  })
  
  return true
end

return M