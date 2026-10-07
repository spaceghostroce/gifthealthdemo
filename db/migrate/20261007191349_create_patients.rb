class CreatePatients < ActiveRecord::Migration[7.1]
  def change
    create_table :patients do |t|
      t.string :name
      t.date :date_of_birth
      t.string :email
      t.string :insurance_id
      t.string :discount_tier

      t.timestamps
    end
  end
end
