$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

require 'flexmock/test_unit'
require 'active_record'
require 'utilities'

class ArchivedFileTest < Test::Unit::TestCase
  
  def setup
    Nearline::Models.empty_schema
  end
  
  def manifest(name = 'foo')
    Nearline::Models::Manifest.new_for_name(name)
  end
  
  def create_for(name = 'foo')
    file_information = Nearline::Models::FileInformation.new($readme, manifest(name))
    Nearline::Models::ArchivedFile.create_for(file_information)
  end
    
  def test_missing_file
    file_information = Nearline::Models::FileInformation.new("does_not_exist", manifest)
    af = Nearline::Models::ArchivedFile.create_for(file_information)
    assert_nil(af)
  end
  
  def test_persist_missing_file
    af = Nearline::Models::ArchivedFile.new
    af.path = "does_not_exist"
    af.file_content = Nearline::Models::FileContent.new
    af.persist(manifest)
    assert af.file_content.sequences.size == 0
  end
  
  def test_restore_directory_to_redirected_path
    file_information = Nearline::Models::FileInformation.new($temp_path, manifest)
    af = Nearline::Models::ArchivedFile.create_for(file_information)
    target = $temp_path + "/foo"
    af.restore(:path => target)
    assert File.directory?(target)
    FileUtils.rm_rf target
  end
  
  def test_size_check
    f = flexmock(Nearline::Models::FileContent.new)
    f.should_receive(:file_size).and_return(123)
    f.should_receive(:file_size=).once

    m = flexmock(Nearline::Models::Manifest)
    m.should_receive(:add_log).once
    
    af = Nearline::Models::ArchivedFile.new
    af.file_content = f
    
    af.size_check(456, m)
  end
  
  def test_verify_content
    f = flexmock(Nearline::Models::FileContent.new)
    f.should_receive(:verified?).and_return(false).once
    f.should_receive(:orphan_check)
    
    m = flexmock(Nearline::Models::Manifest)
    m.should_receive(:add_log).once
    
    af = Nearline::Models::ArchivedFile.new
    af.file_content = f
    
    af.verify_content(m)
  end
  
  def test_restore_file_to_redirected_path
    target = $temp_path+"/bar/README"
    af = create_for("bar")
    af.restore(:path => target)
    assert File.directory?($temp_path+"/bar")
    assert File.exist?(target)
  end
  
  def test_achiving_symlink
    unless RUBY_PLATFORM =~ /win/
      link = $temp_path+"/test_link"
      target = "README"
      File.symlink(target, link)
      assert_equal "link", File.ftype(link)
      file_information = Nearline::Models::FileInformation.new(link, manifest)
      af = Nearline::Models::ArchivedFile.create_for(file_information)
      assert_equal target, af.ftype_data
      assert_equal "link", af.ftype
      File.unlink(link)
    end
  end

end