task :rcov => [:clean] do
  begin
    require 'rcov/rcovtask'
  
    Rcov::RcovTask.new do |t|
      t.libs << "test"
      t.rcov_opts = ['--text-report']
      t.test_files = FileList['test/nearline_test.rb']
      t.verbose = true
    end
  rescue LoadError => no_rcov
  end
end
