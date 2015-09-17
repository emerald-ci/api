class CreateProjects < ActiveRecord::Migration
  def change
    create_table :projects do |t|
      t.string :git_url, null: false
    end
  end
end

