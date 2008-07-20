module Nearline
  module Models
    
    # Represents file metadata and possible related FileContent
    # for a single file on a single system
    class ArchivedFile < ActiveRecord::Base
      require 'digest/sha1'
      require 'fileutils'
      
      belongs_to :file_content
      belongs_to :system
      has_and_belongs_to_many :manifests
      
           
      def self.create_for(file_information)
        # The path doesn't actually exist and fails a File.lstat
        return nil if file_information.path_hash.nil?
        
        # We need to create a record for a link, directory or file
        archived_file = ArchivedFile.new(
          file_information.archived_file_parameters
        )
        
        # Find a new link
        if(file_information.ftype == "link")
          archived_file.ftype_data = file_information.link_target
          archived_file.save!
          file_information.manifest.archived_files << archived_file
          return archived_file          
        end

        # Find a new directory
        if (file_information.ftype=="directory")
          archived_file.save!
          file_information.manifest.archived_files << archived_file
          return archived_file
        end
        
        # Find a new file that needs persisted        
        archived_file.file_content.file_size = 
          [file_information.stat.size].pack('Q').unpack('L').first # HACK for Windows
        archived_file = archived_file.persist(file_information.manifest)
        unless archived_file.nil? || archived_file.frozen?
          archived_file.save!
          file_information.manifest.archived_files << archived_file
        end
        archived_file
        
        # TODO: block devices, ...?
      end
            
      def restore(*args)
        @options = args.extract_options!

        if (self.ftype == "link")
          guarantee_path
          File.symlink(self.ftype_data,
            option_override(:path))
          #restore_metadata
          return
        end

        if (self.ftype == "directory")
          FileUtils.mkdir_p option_override(:path)
          restore_metadata
          return
        end
        
        # ftype == "file"
        guarantee_path
        f = File.open(option_override(:path), "wb")
        self.file_content.restore_to(f)
        f.close
        restore_metadata
        return
      end
      
      def guarantee_path
        target_path = File.dirname(option_override(:path))
        if (!File.exist? target_path)
          FileUtils.mkdir_p target_path
        end        
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
      
      # In the special case of an identical sequence existing,
      # we can safely delete all related sequences and then destroy
      # the file content object without the (far slower) orphan checking
      # process
      def clean_up_duplicate_content
        Sequence.delete_all "file_content_id = #{self.file_content.id}"
        self.file_content.destroy
      end

      def replace_content(key)
        self.file_content = FileContent.find_by_fingerprint(key)
        self.save!                
      end
      
    end

  end
end