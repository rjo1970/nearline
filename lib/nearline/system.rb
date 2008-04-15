module Nearline
  module Models
    
    class System < ActiveRecord::Base

      has_many :manifests
      has_many :archived_files
      
      
      def self.for_name(system_name)
        system = self.find_by_name(system_name)
        return system unless system.nil?
        system = self.new(:name => system_name)
        system.save!
        system
      end
            
      # Find the latest Manifest for a system
      # given the latest_date_time as an upper limit
      def latest_manifest_as_of(latest_date_time = Time.now)
        m_result = Manifest.find(:first,
          :conditions => 
            ["system_id = ? and created_at <= ?",
            self.id, latest_date_time],
          :order => "created_at desc"
        )
        raise "No manifest found" if m_result.nil?
        m_result        
      end
      
      # Method used by the Nearline module to backup the system
      def self.backup(system_name, backup_paths, backup_exclusions)
        system = self.for_name(system_name)
        system.backup(backup_paths, backup_exclusions)
      end
      
      def backup(backup_paths, backup_exclusions)
        Manifest.backup(self, backup_paths, backup_exclusions)
      end
      
      # Method used by the Nearline module to restore the system
      def self.restore_all_missing(system_name, latest_date_time)
        system = self.for_name(system_name)
        system.restore_all_missing(latest_date_time)
      end
      
      def restore_all_missing(latest_date_time)
        Manifest.restore_all_missing(self, latest_date_time)
      end
      
      def archived_file_lookup_hash
        return @lookup_hash if !@lookup_hash.nil?
        @lookup_hash = {}
        for af in self.archived_files
          @lookup_hash[af.path_hash] = af.id
        end
        @lookup_hash
      end
      
      def before_destroy
        for manifest in self.manifests
          manifest.destroy
        end
      end
      
    end
    
  end
end