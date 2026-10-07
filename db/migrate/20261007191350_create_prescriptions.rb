class CreatePrescriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :prescriptions do |t|
      t.references :patient, null: false, foreign_key: true
      t.string :drug_name
      t.string :dosage
      t.text :notes

      t.timestamps
    end
  end
end
