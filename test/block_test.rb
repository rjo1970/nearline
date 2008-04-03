$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

require 'test/unit'
require 'active_record'

class BlockTest < Test::Unit::TestCase

  Nearline.connect! 'test'
  
  def setup
    Nearline::Models::Block.destroy_all    
  end
  
  def test_adding_a_block_should_increase_the_total_count
    Nearline::Models::Block.for_content("abc123")
    assert_equal(1, Nearline::Models::Block.count)
  end
  
  def test_adding_a_block_twice_results_in_one_block
    Nearline::Models::Block.for_content("abc123")
    Nearline::Models::Block.for_content("abc123")
    assert_equal(1, Nearline::Models::Block.count)    
  end
  
  def test_adding_a_block_with_compressing_content
    block = Nearline::Models::Block.for_content("a"*4000)
    assert block.bulk_content.size < 4000
    assert_equal block.content, "a"*4000
  end

  def test_adding_a_block_should_define_its_fingerprint
    block = Nearline::Models::Block.for_content("a"*4000)
    assert_equal("38e4f3c0c14b64b1e112b7f4dc370fd962ad31de", block.fingerprint)
  end
  
end