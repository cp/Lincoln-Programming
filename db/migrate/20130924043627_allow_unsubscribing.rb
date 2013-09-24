class AllowUnsubscribing < ActiveRecord::Migration
  def up
    add_column :members, :unsubscribed, :boolean, default: false
  end

  def down
    destroy_column :members, :unsubscribed
  end
end
