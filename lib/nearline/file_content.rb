module Nearline
  module Models

    # Has the responsibility of identifying, restoring and
    # verifying content
    class FileContent < ActiveRecord::Base
      has_many :sequences
      has_many :archived_files
      
      def orphan_check
        if (self.archived_files.size < 2)
          sequences.each do |s|
            s.destroy
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
      
      def restore_to(io)
        sequences.each do |seq|
          block = Block.find(seq.block_id)
          io.write(block.content)
        end
      end
    
      def verified?
        if (!self.verified_at.nil?)
          return true
        end
        whole_file_hash = Digest::SHA1.new
        sequences.each do |seq|
          block = Block.find(seq.block_id)
          whole_file_hash.update(block.content)
        end
        if fingerprint == whole_file_hash.hexdigest
          self.verified_at = Time.now
          self.save!
          return true
        end
        false
      end
      
      
    end
    
    # Has the responsibility of preserving
    # cardinality of stored blocks
    class Sequence < ActiveRecord::Base
      belongs_to :block
      belongs_to :file_content
      
      def after_destroy
        block.orphan_check
      end
    end
    
    class FileSequencer
      def initialize(file_content)
        @inc = 0
        @file_content = file_content
        @file_content.save!
      end
      
      def preserve_content(content)
        @inc += 1
        block_id = Block.id_for_content(content)
        sequence = Sequence.new(
          :sequence => @inc,
          :file_content_id => @file_content.id,
          :block_id => block_id
        )
        sequence.save!
        sequence        
      end
            
    end
      
  end
end