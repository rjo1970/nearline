module Nearline
  module Models
                
    # Used for mass block entry and sequencing
    class FileSequencer      
      attr_reader :file_size
    
      # Number of blocks to serialize in a batch
      MAX_BLOCKS = 1600;
      
      def initialize(io, file_content)
        @io = io
        @file_content = file_content
        if (@file_content.id.nil?)
          @file_content.save!
        end
        @s = []
        @b = []
        @file_size = 0
        @offset = 0
        @whole_file_hash = Digest::SHA1.new
      end
      
      def fingerprint
        @whole_file_hash.hexdigest
      end
      
      def persist_segment
        pull_blocks
        sequence_known_blocks      
        attempt_compression_of_remaining_blocks
        insert_new_blocks
        sequence_known_blocks
        insert_sequences
        clear_for_next_persist
      end
      
      private
      
      def clear_for_next_persist
        @s = []
        @b = []
        @offset += MAX_BLOCKS
      end
    
      def sequence_known_blocks
        f = found_fingerprint_map
        add_sequence_entries_clearing_blocks(f)
      end
      
      def found_fingerprint_map
        f = {}
        fp_raw = []
        @b.each {|a| fp_raw << a.fingerprint unless a.nil?}
        return f if fp_raw.size == 0
        fingerprints = fp_raw.collect {|fp| "'#{fp}'"}.join(', ')
        query = "select distinct id, fingerprint from blocks "+
          "where fingerprint in (#{fingerprints})"
        r = Nearline::Models::Block.connection.select_all(query)
        r.each { |e| f[e["fingerprint"]] = e["id"] }
        f
      end
      
      def add_sequence_entries_clearing_blocks(f)
        @b.size.times do |i|
          block = @b[i]
          unless block.nil?
            if f[block.fingerprint]
              @s.push(Sequence.new(
                :sequence => i + @offset + 1,
                :block_id => f[block.fingerprint],
                :file_content_id => @file_content.id
              ))
              @b[i] = nil
            end
          end
        end
      end
      
      def insert_sequences
        @s.each do |s|
          s.save!
        end
      end
      
      def attempt_compression_of_remaining_blocks
        f = {}
        @b.each do |block|
          unless block.nil? or f[block.fingerprint]
            block.attempt_compression
            f[block.fingerprint] = true
          end
        end
      end
      
      def insert_new_blocks
        f = {}
        @b.each do |b|
          unless b.nil? || f[b.fingerprint]
            b.save!
            f[b.fingerprint] = true
          end
        end
      end
                  
      def pull_blocks
        count = 0
        while (!@io.eof && count < MAX_BLOCKS)
          count += 1
          buffer = @io.read(Block::MAX_SIZE)
          @file_size += buffer.size
          blk = Block.new(:bulk_content => buffer)
          @whole_file_hash.update(buffer)
          blk.calculate_fingerprint
          @b << blk          
        end
      end
          
    end
    
  end
end