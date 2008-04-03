$:.unshift File.join(File.dirname(__FILE__), "..", "test")
# This is the suite of tests to run against Nearline
require 'test/unit'

require 'utilities'

$data_path = File.join(File.dirname(__FILE__), "..", "data")
unless File.exist?($data_path)
  FileUtils.mkdir $data_path 
end

require 'schema_test'
require 'block_test'
require 'nearline_module_test'
require 'file_content_test'
require 'archived_file_test'
require 'manifest_test'
