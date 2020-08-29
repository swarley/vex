# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'
require 'yard/rake/yardoc_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = '--format progress'
  t.verbose = false
end

RuboCop::RakeTask.new(:rubocop)

YARD::Rake::YardocTask.new(:yard)

# Run all tests
task test: %i[rubocop yard spec]

task default: :spec
