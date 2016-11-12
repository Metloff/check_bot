class AddImageToChecks < ActiveRecord::Migration[5.0]
  def change
    add_column :checks, :image, :string
  end
end
