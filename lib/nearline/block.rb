require 'active_record'

module Nearline
  module Models

    # Represents a unit of file content which may be
    # freely shared across the repository.
    # Its sole responsibility is to preserve and provide
    # content access.
    class Block < ActiveRecord::Base
      require "zlib"
    
      has_many :sequences
      
      # Maximum block size in bytes
      @@max_block_size = (64 * 1024)-1
      cattr_accessor :max_block_size
      
      # Level of block compression attempted
      # 0 = skip compression entirely
      @@block_compression_level = 5
      cattr_accessor :block_compression_level
      
      def attempt_compression
        return if (self.is_compressed || @@block_compression_level == 0)
        candidate_content = Zlib::Deflate.deflate(
          self.bulk_content,
          @@block_compression_level
        )
        if candidate_content.length < self.bulk_content.length
          self.is_compressed = true
          self.bulk_content = candidate_content
        end
      end
      
      def calculate_fingerprint
        self.fingerprint = Digest::SHA1.hexdigest(content)        
      end
    
      def content
        if !@content.nil?
          return @content
        end
        if (self.is_compressed)
          return @content = Zlib::Inflate.inflate(self.bulk_content)
        end
        @content = self.bulk_content
      end
            
      def orphan_check
        if self.sequences.size == 0
          self.destroy
        end
      end
            
    end
  end
end