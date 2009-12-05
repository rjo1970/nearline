$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

require 'flexmock/test_unit'
require 'utilities'
require 'fileutils'

class NearlineModuleTest < Test::Unit::TestCase
  
  def setup
    ActiveRecord::Base.clear_active_connections!
    @hash ||= YAML.load_file("config/database.yml")['test']    
  end
  
  def database_setup
    Nearline.connect! 'test'
    Nearline::Models.destroy_schema
    Nearline::Models::Block.clear_active_connections!
  end
    
  def test_soft_connect_from_string
    flexmock(Nearline::Models::Block).should_receive(:establish_connection).once
    Nearline.connect 'test'
  end
  
  def test_soft_connect_from_hash
    flexmock(Nearline::Models::Block).should_receive(:establish_connection).once
    Nearline.connect(@hash)
  end
  
  def test_connect_from_hash
    flexmock(ActiveRecord::Base).should_receive(:establish_connection).once
    flexmock(Nearline::Models).should_receive(:generate_schema)
    Nearline.connect!(@hash)    
  end
  
  def test_bakup_with_no_domain
    database_setup
    begin
      Nearline.backup("foo", $temp_path)
      flunk "Expected SchemaVersionException"
    rescue Nearline::SchemaVersionException
    end
  end
  
  def test_restore_with_no_domain
    database_setup
    begin
      Nearline.restore("foo")
      flunk "Expected SchemaVersionException"
    rescue Nearline::SchemaVersionException
    end    
  end
  
  
  # A single, end-to-end integration test.  The individual
  # pieces are tested elsewhere
  def test_full_integration
    database_setup
    Nearline.connect! 'test'
    files_to_back_up = [$temp_path]
    things_to_skip = ['\\.class$']
    m = Nearline.backup("baz", files_to_back_up, things_to_skip)
    assert_equal 'Nearline::Models::Manifest', m.class.to_s
    
    # ---------------------------------------------
    FileUtils.rm_r $temp_path
    
    stuff = Nearline.what_would_restore("baz")
    assert stuff.find {|e| e =~ /README$/}
    
    Nearline.restore("baz")
    assert File.exists?($readme)
  end
  
  def test_symlink_integration
    unless RUBY_PLATFORM =~/windows/
      database_setup
      link = $temp_path + '/test_link'
      Nearline.connect! 'test'
      File.symlink("README", link)
      Nearline.backup("baz", $temp_path)
      # --------------------------
      FileUtils.rm_r $temp_path
      assert !File.exists?(link)
      
      stuff = Nearline.what_would_restore("baz")
      assert stuff.find {|e| e =~ /test_link$/}
      
      Nearline.restore("baz")
      assert File.exists?(link)
      assert_equal "link", File.ftype(link)
    end
  end
  
#  def test_binary_storage_torture_test
#    database_setup
#    Nearline.connect! 'test'
#    3.times do
#      File.open($temp_path+"/binary_content","wb") do |f|
#        65535000.times do
#          f << (rand(256)).chr
#        end      
#      end
#      m = Nearline.backup("baz", $temp_path)
#      assert_equal 0, m.logs.size
#      File.unlink($temp_path+"/binary_content")
#    end
#  end
  
  def test_no_dangling_records
    database_setup
    Nearline.connect! 'test'
    files_to_back_up = $temp_path
    m1 = Nearline.backup("baz", files_to_back_up)
    m2 = Nearline.backup("baz", files_to_back_up)
    m2.add_log("Baz log message for m2")
    assert_equal 1, Nearline::Models::Block.count
    assert_equal 1, Nearline::Models::FileContent.count
    assert_equal 1, Nearline::Models::Sequence.count
    assert_equal 1, Nearline::Models::System.count
    assert_equal 4, Nearline::Models::ArchivedFile.count
    assert_equal 1, Nearline::Models::Log.count
    assert_equal 2, Nearline::Models::Manifest.count
    m1.destroy
    assert_equal 1, Nearline::Models::Block.count
    assert_equal 1, Nearline::Models::FileContent.count
    assert_equal 1, Nearline::Models::Sequence.count
    assert_equal 1, Nearline::Models::System.count
    assert_equal 4, Nearline::Models::ArchivedFile.count
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