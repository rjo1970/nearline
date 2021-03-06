module Nearline
  module Models
    
    # The System has the responsibility of identifying
    # what the target was for a backup and relating all
    # Manifests and ArchivedFiles associated with the
    # target system.
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
      
      def self.what_would_restore(system_name, latest_date_time)
        system = self.for_name(system_name)
        system.what_would_restore(latest_date_time)
      end
      
      def what_would_restore(latest_date_time = Time.now)
        Manifest.what_would_restore(self, latest_date_time)
      end
            
      def before_destroy
        for manifest in self.manifests
          manifest.destroy
        end
      end
      
    end
    
  end
end