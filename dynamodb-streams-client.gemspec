# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dynamodb/streams/client/version'

Gem::Specification.new do |spec|
  spec.name          = 'dynamodb-streams-client'
  spec.version       = DynamoDB::Streams::Client::VERSION
  spec.authors       = ['Genki Sugawara']
  spec.email         = ['sgwr_dts@yahoo.co.jp']
  spec.summary       = %q{DynamoDB Streams client.}
  spec.description   = %q{DynamoDB Streams client.}
  spec.homepage      = 'https://github.com/winebarrel/dynamodb-streams-client'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'thor'
  spec.add_dependency 'deep_merge'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
end
