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
        if !@content.nil?
          return @content
        end
        if (self.is_compressed)
          return @content = Zlib::Inflate.inflate(self.bulk_content)
        end
        @content = self.bulk_content
      end
      
      def self.id_for_content(x)
        block = Block.new(:bulk_content => x)
        block.calculate_fingerprint
        hit = Block.connection.select_one(
          "select id from blocks where fingerprint='#{block.fingerprint}'"
        )
        unless hit.nil?
          return hit['id']
        end
        block.attempt_compression
        block.save!
        block.id
      end

      def self.for_content(x)
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