require File.expand_path("../lib/non-haml/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "non-haml"
  s.version = NonHaml::VERSION

  s.author = "Jacob Mattingley"
  s.email = "jem@ieee.org"
  s.homepage = "https://github.com/jem/non-haml/"
  s.date = Date.today.to_s
  s.description = "HAML-like syntax for non-HTML"
  s.summary = s.description

  s.files = Dir["lib/**/*.rb"]

  s.required_ruby_version = '~> 1.9.2'
end

