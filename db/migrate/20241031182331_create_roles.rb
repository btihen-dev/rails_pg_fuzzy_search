class CreateRoles < ActiveRecord::Migration[7.2]
  def change
    create_table :roles do |t|
      t.string :job_title, null: false
      t.string :department, null: false
      t.references :person, null: false, foreign_key: true

      t.timestamps
    end

    add_index :roles, [:person_id, :job_title, :department], unique: true
  end
end
