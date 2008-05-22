module Nearline
  module Models
    
    # Recuses paths and finds the files to back up
    class FileFinder
      require 'find'
      def self.recurse(paths, exclusions)
        regex_exclusions = exclusion_regexes(exclusions)
        paths.each do |path|
          Find.find(path) do |f|
            regex_exclusions.each do |ex|
              Find.prune if ex.match(f)
            end
            yield f
          end
        end
      end
      
      def self.exclusion_regexes(exclusions)
        regex_exclusions = []
        for exclusion in exclusions
          regex_exclusions << /#{exclusion}/
        end
        regex_exclusions
      end
    end
    
    # Handles file paths and metadata for a file in a manifest
    class FileInformation
      attr_reader :path_hash, :stat, :is_directory,
        :archived_file_parameters, :manifest, :file_path
      
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
          # TODO: change to lstat when we handle links
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
      
      # Maximum number of files to stat and process in a batch
      @@max_files_cached = 10000
      cattr_accessor :max_files_cached
      
      def self.new_for_name(system_name)
        system = System.for_name(system_name)
        system.manifests << m = Nearline::Models::Manifest.new
        system.save!
        m        
      end
      
      def self.backup(system, backup_paths, backup_exclusions)
        manifest = self.new(:system => system)
        manifest.save!
        manifest.backup(backup_paths, backup_exclusions)
      end
      
      def backup(backup_paths, backup_exclusions)
        FileFinder.recurse(backup_paths, backup_exclusions) do |file_path|
          handle_file_path(file_path)
        end
        finish_remaining_file_infos
        
        self.completed_at = Time.now
        self.save!
        self        
      end
      
      def handle_file_path(file_path)
        @file_infos = @file_infos || []
        @file_infos << FileInformation.new(file_path, self)
        
        if @file_infos.size > @@max_files_cached
          process_file_infos
        end
      end
      
      def finish_remaining_file_infos
        process_file_infos
      end
      
      def process_file_infos
        return if @file_infos.size == 0

        lookup = existing_archived_file_lookup        
        @file_infos.each do |file_info|
          $stdout.write file_info.file_path + " "
          if (af = lookup[file_info.path_hash])
            self.archived_files << af
          else
            af = ArchivedFile.create_for(file_info)            
          end
          if (!af.nil?)
            $stdout.write "#{Time.at(af.mtime).asctime}"
            if (!af.file_content.nil?)
              $stdout.write" (#{af.file_content.file_size} bytes)"
            end
            $stdout.write("\n")
          end
        end
        @file_infos = []
      end
      
      def existing_archived_file_lookup
        return {} if @file_infos.size == 0
        path_hashes = @file_infos.collect {|e| "'#{e.path_hash}'"}.join(", ")
        conditions = "path_hash in (#{path_hashes})"
        hits = ArchivedFile.find(:all, :conditions => conditions)
        existing_files = {}
        hits.each { |e| existing_files[e.path_hash] = e }
        existing_files
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
        destroy_archived_files_with_content
        destroy_archived_files_without_content
        destroy_archived_files_manifests
        destroy_logs
        self.destroy_without_habtm_shim_for_archived_files
      end
      
      private
      
      def  archived_file_content_query(op)
        <<-END_SQL
select distinct fc.id
 from archived_files af,
 archived_files_manifests afm, file_contents fc
 where
 afm.manifest_id #{op} #{self.id} and
 afm.archived_file_id = af.id and
 af.file_content_id = fc.id      
        END_SQL
      end
      
      def destroy_archived_files_with_content

        fc_in = self.connection.select_all(archived_file_content_query("=")).collect{|e| e["id"]}
        fc_out = self.connection.select_all(archived_file_content_query("!=")).collect{|e| e["id"]}
        fc_to_destroy = (fc_in - fc_out).join ", "

        if (fc_to_destroy.size > 0)
          af_to_destroy = self.connection.select_all(<<-END_QUERY
select af.id from archived_files af, archived_files_manifests afm
where afm.manifest_id=#{self.id} and afm.archived_file_id = af.id and 
af.file_content_id in (#{fc_to_destroy})
            END_QUERY
          ).collect{|e| e["id"]}
        else
          af_to_destroy = []
        end
                
        Nearline::Models::ArchivedFile.find(af_to_destroy).each do |af|
          af.orphan_check
        end 
      end
      
      def archived_files_query(op)
        <<-END_QUERY
select distinct af.id
 from archived_files af,
 archived_files_manifests afm
 where af.file_content_id is null and
 af.id = afm.archived_file_id and
 afm.manifest_id #{op} #{self.id}                  
        END_QUERY
      end
      
      def destroy_archived_files_without_content
        af_in = self.connection.select_all(archived_files_query("=")).collect{|e| e["id"]}        
        af_out = self.connection.select_all(archived_files_query("!=")).collect{|e| e["id"]}

        af_to_destroy = Nearline::Models::ArchivedFile.find(af_in - af_out)
        af_to_destroy.each do |af|
          af.orphan_check
        end
      end
    

      def destroy_archived_files_manifests
        self.connection.delete("delete from archived_files_manifests where manifest_id=#{self.id}")
      end
      
      def destroy_logs
        logs.each do |log|
          log.destroy
        end        
      end
      
      public
      
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