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
  end
    
  def test_handle_file_path_rollover
    old_max_files_cached = Nearline::Models::Manifest.max_files_cached
    Nearline::Models::Manifest.max_files_cached=2
    m1 = Nearline::Models::Manifest.backup(@system, $temp_path, [])    
    Nearline::Models::Manifest.max_files_cached = old_max_files_cached
    assert_equal 4, m1.archived_files.size
  end

end
