$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

require 'flexmock/test_unit'
require 'active_record'

class SchemaTest < Test::Unit::TestCase
  def test_schema_generated
    flexmock(ActiveRecord::Schema).should_receive(:define).once
    Nearline::Models.generate_schema
  end
  
  def test_schema_destroyed
    flexmock(ActiveRecord::Schema).should_receive(:define).at_least.twice
    Nearline::Models.generate_schema
    Nearline::Models.destroy_schema
  end
end