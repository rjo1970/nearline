$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

require 'test/unit'
require 'active_record'

class BlockTest < Test::Unit::TestCase

  Nearline.connect! 'test'
  
  SHORT_CONTENT = "abc123"
  CONTENT = "a" * 4000
  
  def setup
    Nearline::Models::Block.destroy_all
  end
  
  def block_for_content(x)
    block = Nearline::Models::Block.new(:bulk_content => x)
    block.calculate_fingerprint
    found = Nearline::Models::Block.find_by_fingerprint(block.fingerprint)
    return found if !found.nil?
    block.attempt_compression
    block.save!
    block
  end
  
  def test_adding_a_block_should_increase_the_total_count
    block_for_content(SHORT_CONTENT)
    assert_equal(1, Nearline::Models::Block.count)
  end
  
  def test_adding_a_block_twice_results_in_one_block
    block_for_content(SHORT_CONTENT)
    block_for_content(SHORT_CONTENT)
    assert_equal(1, Nearline::Models::Block.count)    
  end
  
  def test_adding_a_block_with_compressing_content
    block = block_for_content(CONTENT)
    assert block.bulk_content.size < 4000
    assert_equal block.content, CONTENT
  end

  def test_adding_a_block_should_define_its_fingerprint
    block = block_for_content(CONTENT)
    assert_equal("38e4f3c0c14b64b1e112b7f4dc370fd962ad31de", block.fingerprint)
  end
  
end