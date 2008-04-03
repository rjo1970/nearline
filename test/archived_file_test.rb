$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

require 'test/unit'
require 'active_record'
require 'utilities'

class ArchivedFileTest < Test::Unit::TestCase
  
  def setup
    Nearline::Models.empty_schema
  end
  
  def manifest
    m = Nearline::Models::Manifest.new
    m.save
    m
  end
  
  def create_for(name)
    Nearline::Models::ArchivedFile.create_for(name, $readme, manifest)
  end

  def test_archiving_a_file_creates_archived_file_and_content_records
    archived_files = Nearline::Models::ArchivedFile.count
    file_contents = Nearline::Models::FileContent.count
    af = create_for("foo")
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
  
  def test_identical_files_share_file_content
    archived_file_a = create_for("foo")
    archived_file_a2 = create_for("bar")
    assert_equal archived_file_a.file_content, archived_file_a2.file_content
  end
  
  def test_subsequent_manifests_files_share_file_content
    archived_file_a = create_for("foo")
    archived_file_a2 = create_for("foo")
    assert_equal archived_file_a.file_content, archived_file_a2.file_content
  end
    
  def test_archiving_the_test_directory
    directory = Nearline::Models::ArchivedFile.create_for("foo",$temp_path, manifest)
    assert directory.is_directory?
  end
  
  def test_archived_file_destroy
    blocks = Nearline::Models::Block.count
    sequences = Nearline::Models::Sequence.count
    file_contents = Nearline::Models::FileContent.count
    af = create_for("foo")
    af.destroy
    assert_equal file_contents, Nearline::Models::FileContent.count, "file contents not emptied"
    assert_equal sequences, Nearline::Models::Sequence.count, "sequences not emptied"
    assert_equal blocks, Nearline::Models::Block.count, "blocks not emptied"
  end
  
  def test_missing_file
    af = Nearline::Models::ArchivedFile.create_for("foo", "does_not_exist", manifest)
    assert_nil(af)
  end
  
  def test_persist_missing_file
    af = Nearline::Models::ArchivedFile.new
    af.path = "does_not_exist"
    af.file_content = Nearline::Models::FileContent.fresh_entry
    af.persist(manifest)
    assert af.file_content.sequences.size == 0
  end
  
  def test_restore_directory_to_redirected_path
    af = Nearline::Models::ArchivedFile.create_for("foo", $temp_path, manifest)
    af.restore(:path => $temp_path+"/foo")
    assert File.directory?($temp_path+"/foo")
  end
  
  def test_restore_file_to_redirected_path
    target = $temp_path+"/bar/README"
    af = create_for("bar")
    af.restore(:path => target)
    assert File.directory?($temp_path+"/bar")
    assert File.exist?(target)
  end

end