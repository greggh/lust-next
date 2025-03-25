# Firmo Coverage Module Complete Rebuild Plan

## Decision to Rebuild

After extensive troubleshooting and multiple attempts to fix the current coverage system, we've determined that the fundamental architectural issues cannot be resolved through incremental changes. The current debug hook implementation has proven unreliable, with inconsistent data structures, path normalization problems, and report generation issues that persist despite our best efforts.

## Permission to Rebuild

We have received explicit permission to completely discard the current coverage implementation and rebuild it from scratch. This gives us the opportunity to design a clean, consistent system that will reliably track code execution and generate accurate reports.

## Architectural Principles for the New System

1. **Consistent Data Structure**: A single, unified data format will be used throughout the system.

2. **Clear Component Boundaries**: Each module will have well-defined interfaces and responsibilities.

3. **Path Normalization**: File paths will be normalized only at system boundaries, maintaining consistency throughout the system.

4. **Simplified Approach**: We will focus on perfecting one approach (debug hook) before considering alternatives.

5. **Test-Driven Development**: Each component will be built alongside comprehensive tests.

6. **Validation Everywhere**: Input/output validation will be performed at all component boundaries.

## Core Data Structure

The new system will use a single consistent data structure:

```lua
coverage_data = {
  -- Summary statistics
  summary = {
    total_files = 0,
    covered_files = 0,
    total_lines = 0,
    covered_lines = 0,
    executed_lines = 0,
    line_coverage_percent = 0,
    execution_coverage_percent = 0,
  },
  
  -- File data
  files = {
    [normalized_path] = {
      source = "...", -- Original source code
      lines = {
        [line_number] = {
          executable = true|false,  -- Can this line be executed?
          executed = true|false,    -- Was this line executed?
          covered = true|false,     -- Was this line validated?
          execution_count = 0,      -- How many times was it executed?
          line_type = "code|comment|blank|structure" -- Classification
        },
        -- More lines...
      },
      -- File statistics
      total_lines = 0,
      executable_lines = 0,
      executed_lines = 0,
      covered_lines = 0,
      line_coverage_percent = 0,
      execution_coverage_percent = 0
    },
    -- More files...
  }
}
```

This structure will be consistent from initial data collection through reporting, avoiding the multiple transformations that cause issues in the current system.

## Implementation Plan

### Phase 1: Core Tracking System

1. **New Debug Hook Implementation**
   - Create a clean, focused debug hook that only tracks line executions
   - Implement proper path normalization
   - Store all data in the consistent format defined above
   - Add comprehensive logging for diagnostic purposes

2. **Line Classification System**
   - Develop a simple system to identify executable vs. non-executable lines
   - Implement basic comment detection
   - Create a clear difference between executed and covered lines

3. **Validation Tests**
   - Build tests with known execution patterns
   - Verify all executed lines are properly tracked
   - Compare against manually verified results

### Phase 2: Report Generation

1. **Report Data Preparation**
   - Implement functions to calculate coverage statistics
   - Ensure source code is properly associated with files
   - Add validation to catch incomplete/inconsistent data

2. **HTML Formatter**
   - Create a clean implementation based on the new data structure
   - Focus on accurate representation of execution data
   - Include clear visual indicators for different line types

3. **Validation Tests**
   - Verify report data matches execution data
   - Test with different file types and execution patterns
   - Ensure reports are accurate and consistent

### Phase 3: Advanced Features

Once the core system is working perfectly, we'll add:

1. **Function Coverage**
   - Track function executions
   - Report on function coverage percentages
   - Visualize function coverage in reports

2. **Block Relationship Tracking**
   - Identify code blocks and their relationships
   - Track block execution
   - Visualize block coverage in reports

3. **Additional Formatters**
   - Implement LCOV, JSON, and other output formats
   - Ensure all formats work with the same data structure

## Immediate Next Steps

1. **Initial Debug Hook Implementation**
   - Create a minimal debug hook that only tracks line execution
   - Implement the core data structure
   - Develop simple test files with predictable execution

2. **Verification Framework**
   - Build tools to visualize and validate tracking results
   - Create a comparison system for expected vs. actual execution
   - Implement detailed logging for troubleshooting

3. **Minimal Report Generation**
   - Create a simple HTML formatter that works with the new data structure
   - Implement basic report generation
   - Verify report accuracy against known execution patterns

## Timeline

- **Week 1**: Core tracking system implementation and verification
- **Week 2**: Basic report generation and validation
- **Week 3**: Advanced features and refinements
- **Week 4**: Final integration, documentation, and thorough testing

Throughout the process, we will maintain a disciplined approach of building and testing each component before moving to the next, ensuring the reliability and accuracy of the final system.