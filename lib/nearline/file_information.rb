module Nearline
  module Models
    
    # Handles file paths and metadata for a file in a manifest
    # Acts as a builder for archived_file by providing the construction parameters
    class FileInformation
      attr_reader :path_hash,
        :stat,  # lstat result
        :ftype, # file type, either "link", "directory", or "file"
        :archived_file_parameters, # construction parameters for archived_file
        :manifest, # reference to the associated manifest, so logging can happen
        :file_path, # the full, expanded file path of the file
        :archived_path, # the path as stored to the repository (less drive letter in Windows)
        :link_target
      
      def initialize(file_path, manifest)
        @manifest = manifest
        @file_path = File.expand_path(file_path)
        @archived_path = cleaned_file_path
        @stat = read_stat
        @ftype = ftype_lookup(file_path)
        @path_hash = generate_path_hash
        @archived_file_parameters = build_parameters
      end
      
      def cleaned_file_path
        # TODO:  handle \\system\$x style Windows file references.
        if RUBY_PLATFORM =~/windows/
          return @file_path[2..-1]
        end
        @file_path
      end
      
      def read_stat
        stat = nil
        begin
          stat = File.lstat(@file_path)
        rescue
          @manifest.add_log("File not found on lstat: #{@file_path}")
        end
        stat
      end

      def generate_path_hash
        return nil if @stat.nil?          
        target = [@manifest.system.name, 
          @archived_path,
          @stat.uid,
          @stat.gid,
          @stat.mtime.to_i,
          @stat.mode].join(':')
        Digest::SHA1.hexdigest(target)
      end
        
      def file_content_value
        return FileContent.new unless @ftype == "directory"
        return nil
      end

      def ftype_lookup(file_path)
        if File.symlink?(file_path)
          @link_target = File.readlink file_path
          return "link"
        end
        if File.directory?(file_path)
          return "directory"
        end
        return "file"
      end

      def build_parameters
        return nil if @stat.nil?
        {
          :system => @manifest.system,
          :path => @archived_path,
          :path_hash => @path_hash,
          :file_content => file_content_value,
          :uid => @stat.uid,
          :gid => @stat.gid,
          :mtime => @stat.mtime.to_i,
          :mode => @stat.mode,
          :ftype => @ftype    
        }
      end

    end

  end
end
