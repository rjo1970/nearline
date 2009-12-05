$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

require 'test/unit'
require 'active_record'

class BlockTest < Test::Unit::TestCase

  Nearline.connect! 'test'
  
  CONTENT = "a" * 4000
  
  def setup
    Nearline::Models::Block.destroy_all
  end
  
  def block_for_content(x)
    block = Nearline::Models::Block.new
    block.content = CONTENT
    found = Nearline::Models::Block.find_by_fingerprint(block.fingerprint)
    return found if !found.nil?
    block.attempt_compression
    block.save!
    block
  end
      
  def test_block_compresses_content
    block = block_for_content(CONTENT)
    assert block.bulk_content.size < CONTENT.size
    assert_equal true, block.is_compressed
    assert_equal CONTENT, block.content
  end
  
end
