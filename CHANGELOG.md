# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0]

### Added

- Added `label_error` option to `return/3` for better error debugging and identification
- Added extensive test coverage for `label_error` functionality

### Changed

- Improved `run/2` documentation with clearer explanations of:
  - Function return values and their effects
  - Error message labeling for named vs anonymous functions
  - Pipeline behavior and when functions execute
- Improved `run/3` documentation with detailed explanations of:
  - Parameter requirements and usage
  - Context mutation behavior
  - Error scenarios with step-by-step breakdowns
  - Halt scenarios and pipeline flow control
- Enhanced `return/3` documentation with comprehensive examples covering:
  - Successful pipeline scenarios
  - Error handling with and without labels
  - Halt message handling
  - Different error labeling behaviors
- Improved README.md API documentation with `label_error` usage examples

## [0.1.0] - Previous Release

### Added

- Initial implementation of Extep pipeline runner
- Core functions: `new/0`, `new/1`, `run/2`, `run/3`, `return/2`
- Basic error handling and pipeline flow control
- Railway-oriented programming pattern implementation
