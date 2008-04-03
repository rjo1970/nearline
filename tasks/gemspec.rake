require 'rake'
require 'rake/gempackagetask'

SPEC = Gem::Specification.new do |s|
  s.name = "nearline"
  s.version = "0.0.1"
  s.author = "Robert J. Osborne"
  s.email = "rjo1970@gmail.com"
  s.summary = "Nearline is a near-line backup and recovery solution"
  s.description = %{
    Nearline is a library to make managing near-line file repositories
    simple and eleant in pure Ruby.
  }
  s.rubyforge_project = "nearline"
  s.files = FileList["{tests,lib,doc,tasks}/**/*"].exclude("rdoc").to_a
  s.add_dependency("activerecord", '>= 2.0.2')
  s.require_path = "lib"
  s.autorequire = "nearline"
  s.test_file = "test/nearline_test.rb"
  s.has_rdoc = true
end

Rake::GemPackageTask.new(SPEC) do |pkg|
  pkg.need_tar = true
end
