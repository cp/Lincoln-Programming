class CreateMembers < ActiveRecord::Migration
  def up
    create_table :members do |m|
      m.string :name
      m.string :phone
      m.string :email
      m.integer :age
      m.timestamps
    end
  end

  def down
    drop_table :members
  end
end
