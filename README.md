# Vox

[![Maintainability](https://api.codeclimate.com/v1/badges/769cea19478c3d5cdfeb/maintainability)](https://codeclimate.com/github/swarley/vox/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/769cea19478c3d5cdfeb/test_coverage)](https://codeclimate.com/github/swarley/vox/test_coverage)
[![Gem Version](https://badge.fury.io/rb/vox.svg)](https://badge.fury.io/rb/vox)
[![Inline docs](https://inch-ci.org/github/swarley/vox.svg?branch=main)](https://inch-ci.org/github/swarley/vox)

A gem for interacting with the Discord API. Intends to cover the entire API, have high spec coverage, complete documentation coverage, and
be as modular as possible with room for flexibility of use at every level.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vox'
```

And then execute:

<!-- markdownlint-disable MD014 -->
```console
$ bundle install
```

Or install it yourself as:

```console
$ gem install vox
```
<!-- markdownlint-enable MD014 -->

## Usage

Currently only the HTTP API has been implemented, and it does not return abstracted objects. Rather it is simply a client to assist
in making requests and handling rate limiting.

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/swarley/vox>. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/swarley/vox/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Vox project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/swarley/vox/blob/main/CODE_OF_CONDUCT.md).
