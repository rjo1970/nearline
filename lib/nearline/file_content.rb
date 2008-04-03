module Nearline
  module Models

    # Has the responsibility of identifying and
    # verifying content
    class FileContent < ActiveRecord::Base
      has_many :sequences
      has_many :archived_files

      def self.fresh_entry
        file_content = FileContent.new
        file_content.save!
        file_content
      end
      
      def restore_to(io)
        sequencer = FileSequencer.new(self)
        sequencer.restore_blocks(io)
      end
      
      def verified?
        sequencer = FileSequencer.new(self)
        sequencer.verified?
      end
      
      def orphan_check
        if (self.archived_files.size == 1)
          sequences.each do |s|
            s.destroy
            s.block.orphan_check
          end
          self.destroy
        end
      end
            
      def unique_fingerprint?(key)
        hit = FileContent.connection.select_one(
          "select id from file_contents where fingerprint='#{key}'"
        )
        return hit.nil?
      end
      
    end
    
    # Has the responsibility of preserving
    # cardinality of stored blocks
    class Sequence < ActiveRecord::Base
      belongs_to :block
      belongs_to :file_content
    end
    
    class FileSequencer
      def initialize(file_content)
        @inc = 0
        @file_content = file_content
      end
      
      def preserve_block(block)
        @inc += 1
        sequence = Sequence.new(
          :sequence => @inc,
          :file_content_id => @file_content.id,
          :block_id => block.id
        )
        sequence.save!
        sequence
      end
      
      def restore_blocks(io)
        @file_content.sequences.each do |seq|
          io.write(seq.block.content)
        end
      end
      
      def verified?
        whole_file_hash = Digest::SHA1.new
        @file_content.sequences.each do |seq|
          whole_file_hash.update(seq.block.content)
        end
        @file_content.fingerprint == whole_file_hash.hexdigest
      end
    end

  end
end