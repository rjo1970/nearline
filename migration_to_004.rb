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

        # Remove empty archived_file records
        execute "delete from archived_files where path_hash is null"
  
        # Introduce the System table
        create_table :systems do |t|
          t.column :name, :string, :null => false
        end
        
        add_index :systems, [:name], :unique => true  

        # Insert all unique system names existing in the
        # Manifests (which should be the same as existing in ArchivedFiles)
        # into System table
        names = ActiveRecord::Base.connection.select_values(
          "select distinct system_name from manifests"
        )
  
        for name in names do
          Nearline::Models::System.new(:name => name).save!
        end

        # Add sytem_id fields with no constraints to Manifest and ArchivedFile
        add_column :manifests, :system_id, :integer
        add_column :archived_files, :system_id, :integer

        # Update migration records with system_id
        manifests = Nearline::Models::Manifest.find(:all)
        for manifest in manifests
          manifest.system = Nearline::Models::System.find_by_name(manifest.system_name)
          manifest.save!
        end

        # Update archived_file records with system_id
        archived_files = Nearline::Models::ArchivedFile.find(:all)
        for af in archived_files
          af.system = Nearline::Models::System.find_by_name(af.system_name)
          af.save!
        end
  
        # Add not-null constraints
        change_column :manifests, :system_id, :integer, :null => false
        change_column :archived_files, :system_id, :integer, :null => false

        # remove the old system_name fields
        remove_column :manifests, :system_name
        remove_column :archived_files, :system_name
  
        # Mark the version of the library and schema
        create_table :nearline_version, :id => false do |t|
          t.column :version, :string
        end
        
        execute "insert into nearline_version (version) values ('#{Nearline::VERSION}')"        
  
      end
      
    end
  end
end
