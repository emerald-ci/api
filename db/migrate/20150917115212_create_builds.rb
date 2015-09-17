class CreateBuilds < ActiveRecord::Migration
  def change
    create_table :builds do |t|
      t.belongs_to :project
      t.string :commit
      t.text :description
    end
  end
end

