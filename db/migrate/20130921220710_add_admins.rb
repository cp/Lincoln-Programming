class AddAdmins < ActiveRecord::Migration
  def up
    add_column :members, :is_admin, :boolean, default: false
  end

  def down
    destroy_column :members, :is_admin
  end
end
