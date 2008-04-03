$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

require 'test/unit'
require 'active_record'

class FileContentTest < Test::Unit::TestCase
  def test_a_multi_block_set_creates_sequences_with_increasing_size
    iterations = 5 # Keep to a single digit, preferably > 1 to really test
    count = Nearline::Models::Sequence.count

    file_content = Nearline::Models::FileContent.fresh_entry
    sequencer = Nearline::Models::FileSequencer.new(file_content)
 
    iterations.times do |i|
      sequencer.preserve_block(Nearline::Models::Block.for_content(content(i)))
    end
          
    assert_equal(count+iterations, Nearline::Models::Sequence.count)
    assert_equal iterations, file_content.sequences.size
  end

  def content(i)
    "#{i}" * Nearline::Models::Block::MAX_SIZE
  end
  
  def test_file_content_restore
    file_content = Nearline::Models::FileContent.fresh_entry
    sequencer = Nearline::Models::FileSequencer.new(file_content)
    sequencer.preserve_block(Nearline::Models::Block.for_content("abc123"))
    w = Writer.new
    file_content.restore_to(w)
    assert_equal "abc123", w.s
  end
  
  class Writer
    attr_accessor :s
    def write(s)
      @s = s
    end
  end
end  