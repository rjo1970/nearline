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
    files_to_back_up = [$readme]
    m1 = Nearline.backup("baz", files_to_back_up)
    m2 = Nearline.backup("baz", files_to_back_up)
    m2.add_log("Baz log message for m2")
    assert 1, Nearline::Models::Block.count
    assert 1, Nearline::Models::FileContent.count
    assert 1, Nearline::Models::Sequence.count
    assert 1, Nearline::Models::ArchivedFile.count
    assert 1, Nearline::Models::Log.count
    assert 2, Nearline::Models::Manifest.count
    m1.destroy
    assert 1, Nearline::Models::Block.count
    assert 1, Nearline::Models::FileContent.count
    assert 1, Nearline::Models::Sequence.count
    assert 1, Nearline::Models::ArchivedFile.count
    assert 1, Nearline::Models::Log.count
    assert 1, Nearline::Models::Manifest.count
    m2.destroy
    assert 0, Nearline::Models::Block.count
    assert 0, Nearline::Models::FileContent.count
    assert 0, Nearline::Models::Sequence.count
    assert 0, Nearline::Models::ArchivedFile.count
    assert 0, Nearline::Models::Log.count
    assert 0, Nearline::Models::Manifest.count
  end
      
end