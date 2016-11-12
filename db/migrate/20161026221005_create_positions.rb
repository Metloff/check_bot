class CreatePositions < ActiveRecord::Migration[5.0]
  def change
    create_table :positions do |t|
      t.string  :title
      t.integer :number_of_people, :default => 1
      t.decimal :price
      t.integer :custom_id
      t.integer :check_id

      t.timestamps
    end
  end
end
