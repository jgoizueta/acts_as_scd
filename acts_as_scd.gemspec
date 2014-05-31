$:.push File.expand_path("../lib", __FILE__)

require "acts_as_scd/version"

Gem::Specification.new do |s|
  s.name        = "acts_as_scd"
  s.version     = ActsAsScd::VERSION
  s.authors     = ["Javier Goizueta"]
  s.email       = ["jgoizueta@gmail.com"]
  s.homepage    = "https://github.com/jgoizueta/acts_as_scd"
  s.summary     = "Support for models that act as Slowly Changing Dimensions"
  s.description = "SCD models have identities and multiple time-limited iterations (revisions) per identity"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.1.1"
  # we will make it work first with rails 3, then support Rails 4
  # s.add_dependency "rails", "~> 3.2.13"

  s.add_dependency 'modalsupport', "~> 0.9.2"

  s.add_development_dependency "sqlite3"
end
