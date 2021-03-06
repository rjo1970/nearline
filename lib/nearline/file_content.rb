module Nearline
  module Models

    # Has the responsibility of identifying, restoring and
    # verifying content
    class FileContent < ActiveRecord::Base
      has_many :sequences, :order => "sequence"
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
      
      private
      
      def each_sequence
        sequences.each do |seq|
          block = Block.find(seq.block_id)
          yield block
        end
      end
      
      public
      
      def restore_to(io)
        each_sequence { |block| io.write(block.content) }
      end
    
      def verified?
        return true if (!self.verified_at.nil?)
        whole_file_hash = Digest::SHA1.new
        each_sequence { |block| whole_file_hash.update(block.content) }
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
    
  end
end