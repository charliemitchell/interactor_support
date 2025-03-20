# frozen_string_literal: true

require_relative "lib/interactor_support/version"

Gem::Specification.new do |spec|
  spec.name = "interactor_support"
  spec.version = InteractorSupport::VERSION
  spec.authors = ["Charlie Mitchell"]
  spec.email = ["charliesemailis@gmail.com"]

  spec.summary = "A collection of support classes for Interactor."
  # spec.homepage = "TODO: Put your gem's website or public repo URL here."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.com"
  spec.metadata["homepage_uri"] = "https://github.com/charliemitchell/interactor_support"
  spec.metadata["source_code_uri"] = "https://github.com/charliemitchell/interactor_support.git"
  spec.metadata["changelog_uri"] = "https://github.com/charliemitchell/interactor_support/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    %x(git ls-files -z).split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?("bin/", "test/", "spec/", "features/", ".git", ".circleci", "appveyor", "Gemfile")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_runtime_dependency("interactor")
  spec.add_runtime_dependency("rails")

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
