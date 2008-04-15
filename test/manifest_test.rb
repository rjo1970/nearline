$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

require 'test/unit'
require 'active_record'
require 'utilities'

class ManifestTest < Test::Unit::TestCase
  
  def setup
    Nearline::Models.destroy_schema
    Nearline::Models.generate_schema
    @system = Nearline::Models::System.for_name("foo")
  end
   
  def test_manifest
    manifest = Nearline::Models::Manifest.backup(@system,[$readme],["won't match anything"])
    assert_equal 1, manifest.archived_files.size
    stat = File.stat($readme)
    FileUtils.rm($readme)    
    result = Nearline::Models::Manifest.restore_all_missing(@system)
    assert_equal 1, result.size
    stat2 = File.stat($readme)
    assert_equal(stat.mtime.to_i, stat2.mtime.to_i)
    
    manifest.destroy
    assert_equal 0, Nearline::Models::ArchivedFile.count
  end

  def test_incomplete_manifests
    2.times do 
      m = Nearline::Models::Manifest.new_for_name('foo')
      m.save!
    end
    assert_equal 2, Nearline::Models::Manifest.incomplete_manifests.size
  end

  def test_total_size
    m = Nearline::Models::Manifest.backup(@system,[$readme],[])
    assert m.total_size > 0
  end

  def test_summary
    m = Nearline::Models::Manifest.backup(@system,[$readme],[])
    assert m.summary.size > 0
    puts m.summary
  end
  
  def test_manifest_with_date_limiting
    manifests = []
    2.times do 
      m = Nearline::Models::Manifest.new_for_name('foo')
      m.save!
      manifests << m
      sleep 1
    end
    assert_equal 1, @system.latest_manifest_as_of(manifests[0].created_at).id
    assert_equal 2, @system.latest_manifest_as_of(manifests[1].created_at).id
  end
  
end
