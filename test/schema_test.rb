$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

require 'test/unit'
require 'mocha'
require 'active_record'

class SchemaTest < Test::Unit::TestCase
  def test_schema_generated
    ActiveRecord::Schema.expects(:define)
    Nearline::Models.generate_schema
  end
  
  def test_schema_destroyed
    ActiveRecord::Schema.expects(:define).at_least(2)
    Nearline::Models.generate_schema
    Nearline::Models.destroy_schema
  end
end