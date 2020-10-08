# frozen_string_literal: true

require_relative 'lib/vox/version'

Gem::Specification.new do |spec|
  spec.name          = 'vox'
  spec.version       = Vox::VERSION
  spec.authors       = ['Matthew Carey']
  spec.email         = ['matthew.b.carey@gmail.com']

  spec.summary       = 'Discord library'
  spec.description   = 'Discord library'
  spec.homepage      = 'http://swarley.github.io/vox/'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.5.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/swarley/vox'
  spec.metadata['changelog_uri'] = 'https://github.com/swarley/vox/blob/master/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'event_emitter', '~> 0.2.6'
  spec.add_runtime_dependency 'faraday', '~> 1.0.1'
  spec.add_runtime_dependency 'logging', '~> 2.3.0'
  spec.add_runtime_dependency 'mime-types', '~> 3.3.1'
  spec.add_runtime_dependency 'multi_json', '~> 1.15.0'
  spec.add_runtime_dependency 'websocket-driver', '~> 0.7.3'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.93.0'
  spec.add_development_dependency 'rubocop-performance', '~> 1.8.0'
  spec.add_development_dependency 'rubocop-rspec', '~> 1.43.0'
  spec.add_development_dependency 'simplecov', '~> 0.17.1' # https://github.com/codeclimate/test-reporter/issues/413
  spec.add_development_dependency 'vox-etf', '~> 0.1.7'
  spec.add_development_dependency 'yard', '~> 0.9.25'
end
