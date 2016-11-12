class CreateChecks < ActiveRecord::Migration[5.0]
  def change
    create_table :checks do |t|
      t.string  :title
      t.integer :user_id
      t.boolean :is_complete, default: false
      
      t.timestamps
    end
  end
end
