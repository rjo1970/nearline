require 'active_record'

module Nearline
  module Models

    # Represents a unit of file content which may be
    # freely shared across the repository
    # Its sole responsibility is to preserve and provide
    # content access
    class Block < ActiveRecord::Base
      require "zlib"
    
      has_many :sequences
      
      MAX_SIZE = (64 * 1024)-1
      
      def attempt_compression
        return if (self.is_compressed)
        # TODO: Have a bump-the-compression option, here?
        candidate_content = Zlib::Deflate.deflate(self.bulk_content)
        if candidate_content.length < self.bulk_content.length
          self.is_compressed = true
          self.bulk_content = candidate_content
        end
      end
      
      def calculate_fingerprint
        self.fingerprint = Digest::SHA1.hexdigest(content)        
      end
    
      def content
        if (self.is_compressed)
          return Zlib::Inflate.inflate(self.bulk_content)
        end
        self.bulk_content
      end
          
      def self.for_content(x, old_block = nil)
        unless old_block.nil?
          if x == old_block.content
            return old_block
          end
        end
        block = Models::Block.new(:bulk_content => x)
        block.calculate_fingerprint
        found = find_by_fingerprint(block.fingerprint)
        return found if !found.nil?
        block.attempt_compression
        block.save!
        block
      end
      
      def orphan_check
        if self.sequences.size == 0
          self.destroy
        end
      end
            
    end
  end
end