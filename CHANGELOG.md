## [Unreleased]

## [1.0.7] - 2025-09-24

- Add `handle_interactor_failure` DSL and per-call overrides for centralized interactor failure handling
- Raise an internal failure signal so handled responses automatically halt controller actions (with opt-out via `halt_on_handle: false`)
- Provide `InteractorSupport.configuration.default_interactor_error_handler` for global handler registration
- Expose richer failure payloads (context, error, request object, params) to handlers

## [1.0.6] - 2025-09-24

- Wrap request object validation failures from `Organizable#organize` in `InteractorSupport::Errors::InvalidRequestObject` for consistent controller handling
- Honor `configuration.log_unknown_request_object_attributes` when logging ignored request object keys
- Improve request object error messaging for failed casts and unknown attributes

## [1.0.0] - 2025-03-20

- Initial release

## [1.0.1] - 2025-03-26

- Removed runtime requirements for rails and interactor.

## [1.0.2] - 2025-03-28

- Added support for mixing symbols and procs in the transformable concern

## [1.0.3] - 2025-04-02

- Added support for rewriting attribute names in a request object
- Better support for type coersion, using Active model + Array, Hash, and Symbol
- Better support for `AnyClass` type validations

## [1.0.4] - 2025-04-05

- Added the organizable concern

## [1.0.5] - 2025-06-30

- Add support for ignoring unknown attributes in RequestObjects via `ignore_unknown_attributes` class method
- Introduce `InteractorSupport.configuration.log_unknown_request_object_attributes` to optionally log ignored attributes
- Introduce `InteractorSupport.configuration.logger` and `log_level` for customizable logging
- Override `assign_attributes` to integrate attribute ignoring and error-raising behavior
- Improve test coverage for unknown attribute handling and logging
