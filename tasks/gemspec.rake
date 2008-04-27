require 'rake'
require 'rake/gempackagetask'

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

SPEC = Gem::Specification.new do |s|
  s.name = "nearline"
  s.version = Nearline::VERSION
  s.author = "Robert J. Osborne"
  s.email = "rjo1970@gmail.com"
  s.homepage = "http://rubyforge.org/projects/nearline"
  s.summary = "Nearline is a near-line backup and recovery solution"
  s.description = %{
    Nearline is a library to make managing near-line file repositories
    simple and elegant in pure Ruby.
  }
  s.rubyforge_project = "nearline"
  s.files = FileList["{tests,lib,doc,tasks}/**/*"].exclude("rdoc").to_a
  s.add_dependency("activerecord", '>= 2.0.2')
  s.require_path = "lib"
  s.test_file = "test/nearline_test.rb"
  s.has_rdoc = true
end

Rake::GemPackageTask.new(SPEC) do |pkg|
  pkg.need_tar = true
end
