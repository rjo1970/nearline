module Nearline
  module Models

    module_function
    
    def destroy_schema
      ActiveRecord::Schema.define do
        drop_table :blocks
        drop_table :file_contents
        drop_table :sequences
        drop_table :archived_files
        drop_table :manifests
        drop_table :archived_files_manifests
        drop_table :logs
        drop_table :systems
        drop_table :nearline_version
      end
    end
    
    def empty_schema
      Nearline::Models::System.destroy_all
    end
    
    def generate_schema
      ActiveRecord::Schema.define do

        create_table :blocks do |t|
          t.column :fingerprint, :string, :length => 40, :null => false
          t.column :bulk_content, :binary
          t.column :is_compressed, :boolean, :default => false
        end
        
        add_index :blocks, [:fingerprint], :unique => true

        create_table :file_contents do |t|
          t.column :fingerprint, :string, :length => 40
          t.column :file_size, :string, :default => 0
          t.column :verified_at, :datetime
        end

        create_table :sequences do |t|
          t.column :sequence, :integer, :null => false
          t.column :block_id, :integer, :null => false
          t.column :file_content_id, :integer, :null => false
        end
        
        create_table :systems do |t|
          t.column :name, :string, :null => false
        end
        
        add_index :systems, [:name], :unique => true

        create_table :archived_files do |t|
          t.column :system_id, :integer, :null => false
          t.column :path, :text, :null => false
          t.column :path_hash, :string, :null => false, :length => 40
          t.column :file_content_id, :integer
          t.column :uid, :integer, :default => -1
          t.column :gid, :integer, :default => -1
          t.column :mtime, :integer, :default => 0
          t.column :mode, :integer, :default => 33206  # "chmod 100666"
          t.column :ftype, :string, :null => false
          t.column :ftype_data, :text
        end
        
        add_index :archived_files, [:path_hash], :unique => true
                        
        # Manifests are the reference to a collection of archived files
        create_table :manifests do |t|
          t.column :system_id, :integer
          t.column :created_at, :datetime
          t.column :completed_at, :datetime
        end
        
        # Joins archived files across manifests so file references may be recycled
        create_table :archived_files_manifests, :id => false do |t|
          t.column :archived_file_id, :integer
          t.column :manifest_id, :integer
        end
        
        # Keeps a record of problems during backup related to a manifest
        create_table :logs do |t|
          t.column :manifest_id, :integer, :null => false
          t.column :message, :text
          t.column :created_at, :datetime
        end
        
        create_table :nearline_version, :id => false do |t|
          t.column :version, :string
        end
        
        execute "insert into nearline_version (version) values ('#{Nearline::DB_VERSION}')"        
      end
    end

  end
end
