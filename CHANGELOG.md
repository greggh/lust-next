# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Fork from bjornbytes/lust to enhance functionality
- GitHub Actions CI workflow for testing on multiple Lua versions
- GitHub structure with templates and community health files
- Documentation improvements with modern markdown format
- Test directory with initial test suite
- Examples directory with sample usage
- Enhanced README with new feature descriptions

### Planned
- Automatic test discovery for finding and running test files
- Test filtering and tagging for selective test runs
- Enhanced reporting with clearer test summaries
- Async testing support for asynchronous code
- Mocking system for dependencies
- Additional assertion types and utilities

## [0.2.0] - Original lust

This is where the fork begins. Original [lust project](https://github.com/bjornbytes/lust) features:

### Features
- Nested describe/it blocks
- Before/after handlers
- Expect-style assertions
- Function spies
- Support for console and non-console environments

[Unreleased]: https://github.com/greggh/lust/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/bjornbytes/lust/tree/master