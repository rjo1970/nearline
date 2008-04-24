module Nearline
  module Models
    
    # Represents file metadata and possible related FileContent
    # for a single file on a single system
    class ArchivedFile < ActiveRecord::Base
      require 'fileutils'
      
      belongs_to :file_content
      belongs_to :system
      has_and_belongs_to_many :manifests
      
            
      def self.create_for(file_path, manifest)        
        file_information = FileInformation.new(file_path, manifest)

        # The path doesn't actually exist and fails a File.stat
        return nil if file_information.path_hash.nil?

        # If we find an exising entry, use it
        hash = manifest.system.archived_file_lookup_hash
        hit = hash[file_information.path_hash]

        unless hit.nil?
          af = ArchivedFile.find(hit)
          manifest.archived_files << af
          return af
        end
        
        # We need to create a record for either a directory or file
        archived_file = ArchivedFile.new(
          file_information.archived_file_parameters
        )
        
        # Find a new directory
        if (file_information.is_directory)
          archived_file.save!
          manifest.archived_files << archived_file
          return archived_file
        end
        
        # Find a new file that needs persisted
        archived_file.file_content.file_size = 
          [file_information.stat.size].pack('Q').unpack('L').first # HACK for Windows
        archived_file = archived_file.persist(manifest)
        unless archived_file.nil? || archived_file.frozen?
          archived_file.save!
          manifest.archived_files << archived_file
        end
        archived_file
        
        # TODO: Symbolic links, block devices, ...?
      end
      
      class FileInformation
        attr_reader :path_hash, :stat, :is_directory, :archived_file_parameters
        def initialize(file_path, manifest)
          @manifest = manifest
          @file_path = file_path
          @stat = read_stat
          @is_directory = File.directory?(file_path)
          @path_hash = generate_path_hash
          @archived_file_parameters = build_parameters
        end

        def read_stat
          stat = nil
          begin
            stat = File.stat(@file_path)
          rescue
            @manifest.add_log("File not found on stat: #{@file_path}")
          end
          stat
        end

        def generate_path_hash
          return nil if @stat.nil?          
          target = [@manifest.system.name, 
            @file_path,
            @stat.uid,
            @stat.gid,
            @stat.mtime.to_i,
            @stat.mode].join(':')
          Digest::SHA1.hexdigest(target)
        end
        
        def file_content_entry_for_files_only
          return FileContent.new unless @is_directory
          return nil
        end

        def build_parameters
          return nil if @stat.nil?
          {
            :system => @manifest.system,
            :path => @file_path,
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
        seq = nil
        begin
          seq = read_file
        rescue
          error = "Got error '#{$!}' on path: #{self.path}"
          manifest.add_log error
          self.orphan_check
          return nil
        end
               
        size_check(seq.file_size, manifest)
        
        # Do we have a unique sequence?
        key = seq.fingerprint
        return self if unique_sequence_processed?(key, manifest)
                
        # Handle the case where the sequence is not unique...
        clean_up_duplicate_content
        replace_content(key)
        self
      end
      
      def read_file
        File.open(self.path, "rb") do |io|
          seq = FileSequencer.new(io, self.file_content)
          while (!io.eof)
            seq.persist_segment
          end
          return seq
        end
      end
            
      def size_check(file_size, manifest)
        if file_size != self.file_content.file_size
          manifest.add_log "recorded file length #{file_size} " +
            "does not match #{self.file_content.file_size} " +
            "reported by the file system on path: #{self.path}"
          self.file_content.file_size = file_size
        end        
      end
      
      def verify_content(manifest)
        unless (self.file_content.verified?)
          manifest.add_log "file dropped on failed verification on path: #{self.path}"
          self.file_content.orphan_check
          self.destroy
        end        
      end
      
      def unique_sequence_processed?(key,manifest)
        if self.file_content.unique_fingerprint?(key)
          self.file_content.fingerprint = key
          self.save!
          verify_content(manifest)
          return true
        end
        false
      end
      
      def clean_up_duplicate_content
        self.file_content.orphan_check
      end
      
      def replace_content(key)
        self.file_content = FileContent.find_by_fingerprint(key)
        self.save!                
      end
      
    end

  end
end