require 'nearline'

module Nearline
  module Models
    module_function
    
    
    # use thusly:
    # require 'migration_xxx'
    # Nearline.connect! 'database'
    # Nearline.migrate
    def migrate
      ActiveRecord::Schema.define do
        remove_index :sequences, :name => 'sequence_jn_index'
        
        remove_index :sequences, :column => :block_id
        
        add_column :archived_files, :ftype, :string, :null => false
        add_column :archived_files, :ftype_data, :text
        
        archived_files = Nearline::Models::ArchivedFile.find(:all)
        for af in archived_files
          if af.is_directory
            af.ftype = "directory"
          else
            af.ftype = "file"
          end
          af.save!
        end
        
        remove_column :archived_files, :is_directory
        
        remove_index :archived_files_manifests, :name => 'manifest_jn_index'
        
        execute "update nearline_version set version='0.0.6'"
      end
      
    end
    
  end
end
