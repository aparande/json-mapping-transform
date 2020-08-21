lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'json-mapping-transform'
  spec.version       = '0.1.0'
  spec.authors       = ['Anmol Parande']
  spec.email         = ['parande.anmol@gmail.com']

  spec.summary       = 'Map one JSON format into another JSON format'
  spec.description   = 'When building data pipelines, it is often useful to extract and transfrom data from an input JSON and output it in a different format. The standard process for doing this in Ruby is to write a series of if-else logic coupled with for-loops. This code ends up being largely redundant, confusing, and difficult to maintain or change. This Gem provides an easy and extensible solution to this problem by allowing you to define your mapping in YAML and apply it to any JSON object in a single line of code.'
  spec.homepage      = 'https://github.com/aparande/json-mapping-transform'
  spec.license       = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/aparande/json-mapping-transform'
  # spec.metadata['changelog_uri'] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'redcarpet'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'yard'
end
