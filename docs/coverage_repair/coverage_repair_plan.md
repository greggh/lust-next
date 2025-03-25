# Firmo Coverage Module Complete Rebuild Plan

## Complete Redesign Approach

After extensive troubleshooting and evaluation, we've determined that the current coverage implementation has fundamental architectural issues that cannot be fixed with incremental changes. We need a complete rebuild of the coverage system from the ground up.

## Key Issues with Current Implementation

1. **Inconsistent Data Structures**: Multiple incompatible ways of tracking coverage (booleans vs tables vs line counts)
2. **Path Normalization Problems**: File paths handled inconsistently between modules
3. **Source Tracking Issues**: Difficulty matching execution data with source code
4. **Execution Counting Flaws**: Debug hook doesn't reliably count executions or track function coverage
5. **Report Processing Discrepancies**: Coverage data doesn't align with formatter expectations
6. **Architectural Complexity**: Trying to support both debug hook and instrumentation approaches simultaneously

## Complete Rebuild Strategy

### Phase 1: Core Coverage Architecture (Week 1)

1. **Design a Clean, Consistent Data Structure**
   - Create a single, unified data format for all coverage information
   - Standardize on tables with consistent keys for all line data
   - Define clear interfaces between components

2. **Build a New Debug Hook Implementation**
   - Start from scratch with a clean debug hook implementation
   - Focus on reliable line execution tracking first
   - Implement proper path normalization at system boundaries only
   - Add comprehensive logging for diagnostic purposes

3. **Create Minimal Tracking System**
   - Develop a simplified line tracking system focused on reliability
   - Avoid premature optimization or complex features
   - Ensure source code content is consistently stored

### Phase 2: Coverage Processing (Week 2)

1. **Build Line Classification System**
   - Create a clean implementation for identifying executable lines
   - Separate structural analysis from execution tracking
   - Implement simple, reliable comment detection

2. **Implement Coverage Calculations**
   - Create straightforward coverage percentage calculations
   - Focus on line coverage as the fundamental metric
   - Ensure calculations match industry standards

3. **Develop Data Preprocessing**
   - Create a clean process for preparing data for reports
   - Ensure source content is properly associated with files
   - Implement validation to catch incomplete/inconsistent data

### Phase 3: Reporting System (Week 3)

1. **Create a New HTML Formatter**
   - Build a clean implementation that works with our new data structure
   - Focus on accuracy first, then visual enhancements
   - Include validation checks before generating reports

2. **Implement Basic Report Types**
   - Focus on HTML and console reporting first
   - Ensure they work perfectly with the new data structure
   - Add proper error handling for report generation

3. **Build Diagnostic Tools**
   - Create tools to inspect and validate coverage data
   - Add self-diagnostic capabilities to the coverage system
   - Include detailed logging for troubleshooting

### Phase 4: Extended Features (Week 4+)

1. **Function Coverage Tracking**
   - Add function-level coverage tracking
   - Ensure it integrates cleanly with the core system
   - Maintain data structure consistency

2. **Block Relationship Tracking**
   - Implement clean block detection and relationship tracking
   - Focus on correct parent-child relationships
   - Ensure visual representation in reports

3. **Additional Report Formats**
   - Implement LCOV, JSON, and other formats once core is solid
   - Maintain strict data structure validation

## Implementation Principles

1. **Simplicity Over Complexity**: Choose simpler approaches that work reliably
2. **Consistency Is Critical**: Maintain the same data format throughout the system
3. **Validation Everywhere**: Add validations at component boundaries
4. **Focus on One Approach**: Perfect the debug hook approach before considering instrumentation
5. **Test-Driven Development**: Build tests alongside each component
6. **Clean Architecture**: Maintain clear separation between components

## Immediate Next Steps

1. **Design the Core Data Structure**
   - Define exactly what coverage data should look like
   - Document the interfaces between components
   - Create validation functions for the data structure

2. **Build Minimal Debug Hook**
   - Create a completely new debug hook implementation
   - Focus solely on capturing executed lines correctly
   - Include comprehensive logging

3. **Create Test Framework**
   - Develop test cases with predictable execution patterns
   - Build tooling to compare actual vs expected coverage
   - Implement visualization of test results

The coverage system will be built incrementally, ensuring each component works perfectly before moving to the next. We will not try to maintain compatibility with the old system - this is a clean break and complete rebuild.