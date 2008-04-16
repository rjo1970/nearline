$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

require 'test/unit'
require 'utilities'
require 'fileutils'

class NearlineModuleTest < Test::Unit::TestCase
  
  def setup
    Nearline.connect! 'test'
    Nearline::Models.destroy_schema
    Nearline::Models::Block.clear_active_connections!
    @hash = YAML.load_file("config/database.yml")['test']
  end
    
  def test_soft_connect_from_string
    Nearline::Models::Block.expects(:establish_connection)
    Nearline.connect 'test'
  end
  
  def test_soft_connect_from_hash
    Nearline::Models::Block.expects(:establish_connection)
    Nearline.connect(@hash)
  end
  
  def test_connect_from_hash
    ActiveRecord::Base.expects(:establish_connection)
    Nearline.connect!(@hash)    
  end
  
  def test_bakup_with_no_domain
    begin
      Nearline.backup("foo", $temp_path)
      flunk "Expected SchemaVersionException"
    rescue Nearline::SchemaVersionException
    end
  end
  
  def test_restore_with_no_domain
    begin
      Nearline.restore("foo")
      flunk "Expected SchemaVersionException"
    rescue Nearline::SchemaVersionException
    end    
  end
  
  
  # A single, end-to-end integration test.  The individual
  # pieces are tested elsewhere
  def test_backup_and_restore
    Nearline.connect! 'test'
    files_to_back_up = [$temp_path]
    things_to_skip = ['\\.class$']
    m = Nearline.backup("baz", files_to_back_up, things_to_skip)
    assert_equal 'Nearline::Models::Manifest', m.class.to_s
    
    # ---------------------------------------------
    FileUtils.rm_r $temp_path
    
    Nearline.restore("baz")
    assert File.exists?($readme)
  end
  
  def test_no_dangling_records
    Nearline.connect! 'test'
    files_to_back_up = $temp_path
    m1 = Nearline.backup("baz", files_to_back_up)
    m2 = Nearline.backup("baz", files_to_back_up)
    m2.add_log("Baz log message for m2")
    assert_equal 1, Nearline::Models::Block.count
    assert_equal 1, Nearline::Models::FileContent.count
    assert_equal 1, Nearline::Models::Sequence.count
    assert_equal 1, Nearline::Models::System.count
    assert_equal 5, Nearline::Models::ArchivedFile.count
    assert_equal 1, Nearline::Models::Log.count
    assert_equal 2, Nearline::Models::Manifest.count
    m1.destroy
    assert_equal 1, Nearline::Models::Block.count
    assert_equal 1, Nearline::Models::FileContent.count
    assert_equal 1, Nearline::Models::Sequence.count
    assert_equal 1, Nearline::Models::System.count
    assert_equal 5, Nearline::Models::ArchivedFile.count
    assert_equal 1, Nearline::Models::Log.count
    assert_equal 1, Nearline::Models::Manifest.count
    m2.system.destroy
    assert_equal 0, Nearline::Models::Block.count
    assert_equal 0, Nearline::Models::FileContent.count
    assert_equal 0, Nearline::Models::Sequence.count
    assert_equal 0, Nearline::Models::System.count
    assert_equal 0, Nearline::Models::ArchivedFile.count
    assert_equal 0, Nearline::Models::Log.count
    assert_equal 0, Nearline::Models::Manifest.count
  end
      
end