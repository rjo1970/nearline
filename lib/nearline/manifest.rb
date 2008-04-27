module Nearline
  module Models
    
    # Recuses paths and finds the files to back up
    class FileFinder
      require 'find'
      def self.recurse(paths, exclusions)
        regex_exclusions = []
        for exclusion in exclusions
          regex_exclusions << /#{exclusion}/
        end
        paths.each do |path|
          Find.find(path) do |f|
            regex_exclusions.each do |ex|
              Find.prune if ex.match(f)
            end
            yield f
          end
        end
      end
    end
    
    # Handles file paths and metadata for a file in a manifest
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

    
    # A Manifest represents the corpus of ArchivedFiles and
    # set of Log messages resulting from a backup attempt
    class Manifest < ActiveRecord::Base
      
      has_and_belongs_to_many :archived_files
      has_many :logs
      belongs_to :system
      
      # Just needed when you create a manifest
      attr_accessor :backup_paths
      # Just needed when you create a manifest
      attr_accessor :backup_exclusions
            
      def self.new_for_name(system_name)
        system = System.for_name(system_name)
        system.manifests << m = Nearline::Models::Manifest.new
        system.save!
        m        
      end
      
      def self.backup(system, backup_paths, backup_exclusions)
        manifest = self.new(:system => system)
        manifest.save!
        
        FileFinder.recurse(backup_paths, backup_exclusions) do |file_name|
          $stdout.write file_name + " "
          af = ArchivedFile.create_for(file_name, manifest)
          if (!af.nil?)
            $stdout.write "#{Time.at(af.mtime).asctime}"
            if (!af.file_content.nil?)
              $stdout.write" (#{af.file_content.file_size} bytes)"
            end
            $stdout.write("\n")
          end
        end

        manifest.completed_at = Time.now
        manifest.save!
        manifest
      end
      
      
      # Find all Manifest entries (across all Systems) which have never finished.
      # 
      # They are:
      # * Currently under-way
      # * Have failed in some untimely way
      def self.incomplete_manifests
        self.find_all_by_completed_at(nil)
      end
      
      def self.restore_all_missing(system, latest_date_time = Time.now)
        manifest = system.latest_manifest_as_of(latest_date_time)
        manifest.iterate_all_missing do |af|
          af.restore
        end 
      end
      
      def self.what_would_restore(system, latest_date_time = Time.now)
        manifest = system.latest_manifest_as_of(latest_date_time)        
        manifest.iterate_all_missing {}
      end
      
      # Iterate all missing files from this manifest, yielding each
      def iterate_all_missing
        files_restored = []
        self.archived_files.each do |af|
          begin
            File.stat(af.path)
          rescue
            yield af
            files_restored << af.path
          end
        end
        return files_restored
      end
      
      def add_log(message)
        puts message
        log = Nearline::Models::Log.new({:message => message, :manifest_id => self.id})
        log.save!
      end
      
      def before_destroy
        archived_files.each do |af|
          af.orphan_check
        end
        logs.each do |log|
          log.destroy
        end
      end
      
      def total_size
        size = 0
        archived_files.each do |af|
          unless af.file_content.nil?
            size += af.file_content.file_size.to_i
          end
        end
        size
      end

      # A simple string reporting the performance of the manifest
      def summary
        completed = (completed_at.nil?) ? "DNF" : completed_at
        "#{system.name} started: #{created_at}; finished: #{completed}; " +
          "#{archived_files.size} files; #{logs.size} Errors reported"
      end
      
    end
    
  end
end