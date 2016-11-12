class CreatePays < ActiveRecord::Migration[5.0]
  def change
    create_table :pays do |t|
      t.references :user, foreign_key: true
      t.references :check, foreign_key: true
      t.decimal :debt
      t.boolean :is_complete, dafault: false

      t.timestamps
    end
  end
end
