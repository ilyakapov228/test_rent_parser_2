class CreateAds < ActiveRecord::Migration[7.1]
  def change
    create_table :ads do |t|
      t.string :external_id
      t.string :site
      t.string :url
      t.string :title
      t.decimal :price
      t.text :address
      t.text :description
      t.jsonb :photos
      t.datetime :published_at

      t.timestamps
    end

    add_index :ads, [:site, :external_id], unique: true
  end
end
