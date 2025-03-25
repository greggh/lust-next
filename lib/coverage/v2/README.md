# Firmo Coverage v2

## Overview

The Firmo v2 coverage system is a complete rewrite of the coverage tracking and reporting system, providing more accurate and detailed coverage information with support for various report formats.

## Key Features

- Function-level coverage tracking
- Enhanced line classification
- Multiple report formats (HTML, LCOV, JSON, Cobertura)
- Detailed function analysis (type, execution count)
- Interactive HTML reports with sorting and filtering

## Components

The v2 coverage system consists of the following components:

### Core Components

- **init.lua**: Main API for starting, stopping, and managing coverage
- **debug_hook.lua**: Lua debug hook implementation for runtime tracking
- **data_structure.lua**: Data structure definitions and manipulation
- **line_classifier.lua**: Classifies lines as code, comment, blank, or structure

### Formatters

- **formatters/html.lua**: Interactive HTML report generator
- **formatters/lcov.lua**: LCOV format for integration with coverage tools
- **formatters/json.lua**: JSON format for programmatic access
- **formatters/cobertura.lua**: Cobertura XML format for CI/CD integration

## Usage

```lua
local coverage_v2 = require("lib.coverage.v2")

-- Start coverage tracking
coverage_v2.start()

-- Run your code
-- ...

-- Stop coverage tracking
coverage_v2.stop()

-- Generate reports in multiple formats
coverage_v2.generate_reports("./coverage-reports/", {
  "html", "lcov", "json", "cobertura"
})

-- Get coverage data programmatically
local coverage_data = coverage_v2.get_report_data()
```

## Data Structure

The coverage data structure consists of:

- **Summary Statistics**: Overall coverage metrics
- **File Data**: Per-file coverage information
- **Line Data**: Detailed per-line information
- **Function Data**: Function execution statistics

Each function is identified by a unique ID in the format:
`{function_name}:{start_line}-{end_line}`

Functions are classified as:
- `global`: Functions defined at global scope
- `local`: Local functions
- `method`: Methods (obj:method())
- `anonymous`: Anonymous functions
- `closure`: Functions that close over variables

## HTML Report Features

The HTML reports include:

- Overall coverage summary
- Function type breakdown
- File-by-file coverage
- Line execution counts
- Function coverage details
- Sortable and filterable function tables
- Interactive search and filtering

## Integration with CI/CD

The multiple report formats enable easy integration with CI/CD systems:

- Use LCOV reports with tools like Coveralls or Codecov
- Use Cobertura reports with Jenkins or other CI systems
- Use JSON reports for custom processing and visualization

## License

Part of the Firmo testing framework. See project root for license information.