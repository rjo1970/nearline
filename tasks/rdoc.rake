require 'rake/rdoctask'

RDOC_FILES = FileList[
  'README',
  'LICENSE',
  'lib/**/*.rb',
  'doc/**/*.rdoc',
]

desc "Create rdoc"
Rake::RDocTask.new("rdoc") do |rdoc|
  rdoc.rdoc_dir = 'html'
  rdoc.title    = "Nearline"
  rdoc.options << '--line-numbers' << '--inline-source' << '--main' << 'README'
  rdoc.rdoc_files.include(RDOC_FILES)
end
