# Static Analyzer Improvement Plan

## Overview

This document outlines the plan for Phase 2 of the coverage repair project, focusing on enhancing the static analyzer module. The improvements aim to make the line classification more accurate, enhance function detection, perfect block boundary identification, and finalize condition expression tracking.

## Current State

The static analyzer module currently:
- Parses Lua code using the parser module
- Identifies some executable and non-executable lines
- Provides basic function detection
- Has limited block boundary identification
- Has preliminary condition expression tracking

However, several limitations have been identified:
- Line classification has inconsistencies with certain code constructs
- Function detection doesn't correctly identify all function types and names
- Block boundary identification is incomplete
- Condition expression tracking isn't fully implemented

## Improvement Areas

### 1. Line Classification System

**Current Issues:**
- Control flow keywords (end, else, until) classification is inconsistent
- Empty lines and whitespace handling needs improvement
- Comments and code on the same line aren't always handled correctly
- Some executable constructs aren't properly identified

**Improvement Tasks:**
- [ ] Refine the `is_line_executable` function to better distinguish code types
- [ ] Enhance multiline comment detection and integration with line classification
- [ ] Improve handling of mixed code and comments on the same line
- [ ] Add support for correctly classifying additional Lua constructs
- [ ] Create comprehensive tests for line classification

### 2. Function Detection

**Current Issues:**
- Function name extraction is incomplete, particularly for nested or complex structures
- Anonymous functions aren't consistently tracked
- Method definitions in tables aren't properly identified
- Function scope boundaries aren't always accurate

**Improvement Tasks:**
- [ ] Enhance the function detection algorithm to extract more accurate names
- [ ] Improve tracking of anonymous functions with meaningful identifiers
- [ ] Better handle methods in table definitions
- [ ] Create proper function scope boundaries
- [ ] Add more comprehensive function attributes (parameters, return types if possible)

### 3. Block Boundary Identification

**Current Issues:**
- Block nesting isn't properly tracked
- Start/end relationships aren't always accurate
- Some block types aren't identified correctly
- Parent-child relationships between blocks are incomplete

**Improvement Tasks:**
- [ ] Implement a stack-based block tracking system
- [ ] Accurately identify start and end positions for all block types
- [ ] Create proper parent-child relationships for nested blocks
- [ ] Handle complex nested structures with better context tracking
- [ ] Add comprehensive block metadata for reporting

### 4. Condition Expression Tracking

**Current Issues:**
- Compound conditions (and/or) aren't properly decomposed
- Condition outcome tracking is incomplete
- Expressions in conditions aren't fully analyzed
- Integration with block tracking is incomplete

**Improvement Tasks:**
- [ ] Enhance condition expression detection and tracking
- [ ] Properly decompose compound conditions into individual components
- [ ] Track condition outcomes (true/false) for branch coverage
- [ ] Connect conditions to their containing blocks
- [ ] Add metadata for condition complexity analysis

## Implementation Plan

### Phase 1: Line Classification Enhancement

1. Refine the line parsing algorithm
2. Improve integration with multiline comment detection
3. Create a more accurate line type classification system
4. Add tests for various line classification scenarios
5. Benchmark and optimize the classification process

### Phase 2: Function Detection Improvements

1. Enhance the function name extraction logic
2. Improve tracking of anonymous functions
3. Better handle methods and nested function definitions
4. Add function metadata collection
5. Create tests for function detection scenarios

### Phase 3: Block Boundary Perfection

1. Implement stack-based block tracking
2. Enhance the block identification algorithm
3. Create proper parent-child relationships
4. Add block metadata for reporting
5. Test with complex nested structures

### Phase 4: Condition Expression Tracking

1. Enhance condition expression detection
2. Implement decomposition of compound conditions
3. Add tracking for condition outcomes
4. Connect conditions to blocks
5. Add tests for condition tracking

## Testing Strategy

For each improvement area, comprehensive tests will be created:

1. **Unit Tests**:
   - Test individual components like `is_line_executable`, function detection, etc.
   - Test edge cases and special code constructs

2. **Integration Tests**:
   - Test the interaction between components
   - Verify that line classification, function detection, and block tracking work together

3. **Benchmark Tests**:
   - Measure performance impacts of improvements
   - Ensure optimizations don't compromise accuracy

4. **Regression Tests**:
   - Ensure new changes don't break existing functionality
   - Verify compatibility with other modules

## Success Criteria

The static analyzer improvements will be considered successful when:

1. Line classification accurately identifies executable and non-executable lines
2. Function detection correctly identifies all function types and extracts meaningful names
3. Block boundaries are accurately identified with proper nesting relationships
4. Condition expressions are properly tracked with outcome information
5. All tests pass with high coverage
6. Performance remains acceptable for large codebases

## Timeline

Given the complexity of these improvements, the work will be divided into manageable chunks:

1. Line Classification Enhancement: 1-2 sessions
2. Function Detection Improvements: 1-2 sessions
3. Block Boundary Perfection: 2-3 sessions
4. Condition Expression Tracking: 1-2 sessions

The entire static analyzer improvement phase is expected to take 5-9 working sessions to complete.