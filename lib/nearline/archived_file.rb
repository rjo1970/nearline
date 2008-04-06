module Nearline
  module Models
    
    # Represents file metadata and possible related FileContent
    # for a single file on a single system
    class ArchivedFile < ActiveRecord::Base
      require 'fileutils'
      
      belongs_to :file_content
      has_and_belongs_to_many :manifests
            
      def self.create_for(system_name, file_path, manifest)
        
        file_information = FileInformation.new(system_name, file_path, manifest)

        # The path doesn't actually exist and fails a File.stat
        return nil if file_information.path_hash.nil?

        # If we find an exising entry, use it
        hit = self.find_by_path_hash(file_information.path_hash)
        return hit unless hit.nil?
        
        # We need to create a record for either a directory or file
        archived_file = ArchivedFile.new(
          file_information.archived_file_parameters
        )
        
        # Find a new directory
        if (file_information.is_directory)
          archived_file.save!
          return archived_file
        end
        
        # Find a new file that needs persisted
        archived_file.file_content.file_size = 
          [file_information.stat.size].pack('Q').unpack('L').first # HACK for Windows
        archived_file.persist(manifest)
        archived_file.save!
        archived_file
        
        # TODO: Symbolic links, block devices, ...?
      end
      
      class FileInformation
        attr_reader :path_hash, :stat, :is_directory, :archived_file_parameters
        def initialize(system_name, file_path, manifest)
          @manifest = manifest
          @stat = read_stat(file_path)
          @is_directory = File.directory?(file_path)
          @path_hash = generate_path_hash(system_name, file_path)
          @archived_file_parameters = build_parameters(system_name, file_path)
        end

        def read_stat(file_path)
          stat = nil
          begin
            stat = File.stat(file_path)
          rescue
            @manifest.add_log("File not found on stat: #{file_path}")
          end
          stat
        end

        def generate_path_hash(system_name, file_path)
          return nil if @stat.nil?          
          target = [system_name, 
            file_path,
            @stat.uid,
            @stat.gid,
            @stat.mtime.to_i,
            @stat.mode].join(':')
          Digest::SHA1.hexdigest(target)
        end
        
        def file_content_entry_for_files_only
          return FileContent.fresh_entry unless @is_directory
          return nil
        end

        def build_parameters(system_name, file_path)
          return nil if @stat.nil?
          {
            :system_name => system_name,
            :path => file_path,
            :path_hash => @path_hash,
            :file_content => file_content_entry_for_files_only,
            :uid => @stat.uid,
            :gid => @stat.gid,
            :mtime => @stat.mtime.to_i,
            :mode => @stat.mode,
            :is_directory => @is_directory    
          }
        end

      end
      
      def restore(*args)
        @options = args.extract_options!
        if (self.is_directory)
          FileUtils.mkdir_p option_override(:path)
          restore_metadata
          return
        end
        target_path = File.dirname(option_override(:path))
        if (!File.exist? target_path)
          FileUtils.mkdir_p target_path
        end
        f = File.open(option_override(:path), "wb")
        self.file_content.restore_to(f)
        f.close
        restore_metadata
        return
      end
      
      def option_override(key)
        if (@options.has_key?(key))
          return @options[key]
        end
        return self.send(key.to_s)
      end
      
      def restore_metadata
        path = option_override(:path)
        mtime = option_override(:mtime)
        uid = option_override(:uid)
        gid = option_override(:gid)
        mode = option_override(:mode)
        File.utime(0,Time.at(mtime),path)
        File.chown(uid, gid, path)
        File.chmod(mode, path)
      end
      
      def before_destroy
        self.file_content.orphan_check if !self.file_content.nil?
      end
      
      def orphan_check
        if self.manifests.size == 1
          self.destroy
        end
      end
      
      # Actually persist the file to the repository
      # It has already been determined that a new ArchivedFile record is
      # necessary and the file requires persisting
      # 
      # But, the content may be identical to something else, and we
      # won't know that until we complete the process and have to
      # clean up our mess.
      def persist(manifest)
        whole_file_hash = Digest::SHA1.new
        file_size = 0
        begin
          file_size = read_file_counting_bytes(whole_file_hash)
        rescue
          manifest.add_log "Got error '#{$!}' on path: #{self.path}"
          self.orphan_check
          return nil
        end
        
        size_check(file_size, manifest)
        
        # Do we have a unique sequence?
        key = whole_file_hash.hexdigest
        return self if unique_sequence_processed?(key, manifest)
                
        # Handle the case where the sequence is not unique...
        clean_up_duplicate_content
        replace_content(key)
        self
      end
      
      def read_file_counting_bytes(whole_file_hash)
        sequencer = FileSequencer.new(self.file_content)
        file_size = 0
        buffer = ""
        File.open(self.path, "rb") do |io|
          while (!io.eof) do
            io.read(Block::MAX_SIZE, buffer)
            file_size += buffer.size
            whole_file_hash.update(buffer)
            block = Block.for_content(buffer)              
            sequencer.preserve_block(block)
          end
        end
        return file_size
      end
            
      def size_check(file_size, manifest)
        if file_size != self.file_content.file_size
          manifest.add_log "recorded file length #{file_size} " +
            "does not match #{self.file_content.file_size} " +
            "reported by the file system on path: #{self.path}"
        end        
      end
      
      def verify_content(manifest)
        unless (self.file_content.verified?)
          manifest.add_log "failed verification on path: #{self.path}"
        end        
      end
      
      def unique_sequence_processed?(key,manifest)
        if self.file_content.unique_fingerprint?(key)
          self.file_content.fingerprint = key
          self.file_content.save!
          self.save!
          verify_content(manifest)
          return true
        end
        false
      end
      
      def clean_up_duplicate_content
        Sequence.delete_all("file_content_id=#{self.file_content.id}")
        self.file_content.orphan_check
      end
      
      def replace_content(key)
        self.file_content = FileContent.find_by_fingerprint(key)
        self.save!                
      end
      
    end

  end
end