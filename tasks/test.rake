desc "Test nearline"
task :test => [:clean] do
  require 'test/nearline_test'
end
