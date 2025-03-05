# Lust-Next Development Guide

## Useful Commands

### Build and Test
- Run all tests: `lua lust-next.lua --dir ./tests`
- Run specific test: `lua lust-next.lua --file tests/specific_test.lua`
- Run with tags: `lua lust-next.lua --tags unit,fast`
- Run with format: `lua lust-next.lua --format dot`

### Code Style Preferences
- 2-space indentation throughout the codebase
- Local function declarations preferred over table assignments when appropriate
- Comments use --- style for documentation
- Error messages should be consistent and informative
- Tests should follow AAA pattern (Arrange, Act, Assert)
- Example files should be well-commented with clear explanations

### Repository Structure
- Core file: `lust-next.lua` - Main module with all functionality
- Examples: `examples/` - Well-commented examples of features
- Tests: `tests/` - Tests for all framework features
- Docs: `docs/` - Documentation for the framework
  - API reference: `docs/api/` - Detailed API documentation
  - Guides: `docs/guides/` - User guides and tutorials
