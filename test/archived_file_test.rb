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

  def test_archiving_a_file_creates_archived_file_and_content_records
    archived_files = Nearline::Models::ArchivedFile.count
    file_contents = Nearline::Models::FileContent.count
    af = create_for
    assert_equal(archived_files+1, Nearline::Models::ArchivedFile.count)
    assert_equal(file_contents+1, Nearline::Models::FileContent.count)
    archived_file = Nearline::Models::ArchivedFile.find(af.id)
    assert archived_file.id > 0
    assert archived_file.file_content_id > 0
    assert_equal archived_file.uid.class, Fixnum 
    assert_equal archived_file.gid.class, Fixnum
    assert archived_file.mtime > 1200000000
    assert_equal archived_file.mode.class, Fixnum 
    assert_equal 40, archived_file.file_content.fingerprint.length
  end
   
  def test_archiving_the_test_directory
    file_information = Nearline::Models::FileInformation.new($temp_path, manifest)
    directory = Nearline::Models::ArchivedFile.create_for(file_information)
    assert directory.is_directory?
  end
  
  def test_archived_file_destroy
    blocks = Nearline::Models::Block.count
    sequences = Nearline::Models::Sequence.count
    file_contents = Nearline::Models::FileContent.count
    af = create_for
    af.destroy
    assert_equal file_contents, Nearline::Models::FileContent.count, "file contents not emptied"
    assert_equal sequences, Nearline::Models::Sequence.count, "sequences not emptied"
    assert_equal blocks, Nearline::Models::Block.count, "blocks not emptied"
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
    af.restore(:path => $temp_path+"/foo")
    assert File.directory?($temp_path+"/foo")
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

end