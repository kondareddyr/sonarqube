#
# Sonar, entreprise quality control tool.
# Copyright (C) 2008-2011 SonarSource
# mailto:contact AT sonarsource DOT com
#
# Sonar is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# Sonar is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with Sonar; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02
#
class Dashboard < ActiveRecord::Base

  DEFAULT_LAYOUT='50%-50%'

  belongs_to :user

  has_many :widgets, :include => 'properties', :dependent => :delete_all
  has_many :active_dashboards, :dependent => :destroy

  validates_length_of :name, :within => 1..256
  validates_length_of :description, :maximum => 1000, :allow_blank => true, :allow_nil => true
  validates_length_of :column_layout, :maximum => 20, :allow_blank => false, :allow_nil => false
  validates_uniqueness_of :name, :scope => :user_id

  before_destroy :check_not_default_before_destroy

  def name(l10n=false)
    n=read_attribute(:name)
    if l10n
      Api::Utils.message("dashboard.#{n}.name", :default => n)
    else
      n
    end
  end

  def description
    Api::Utils.message("dashboard.#{name}.description", :default => read_attribute(:description))
  end

  def shared?
    read_attribute(:shared) || false
  end

  def layout
    column_layout
  end

  def user_name
    user_id ? user.name : nil
  end

  def editable_by?(user)
    (user && self.user_id==user.id) || (user_id.nil? && user.has_role?(:admin))
  end

  def owner?(user)
    self.user_id==user.id
  end

  def number_of_columns
    column_layout.split('-').size
  end

  def column_size(column_index)
    last_widget=widgets.select { |w| w.column_index==column_index }.max { |x, y| x.row_index <=> y.row_index }
    last_widget ? last_widget.row_index : 0
  end

  def deep_copy()
    dashboard=Dashboard.new(attributes)
    dashboard.shared=false
    self.widgets.each do |child|
      new_widget = Widget.create(child.attributes)

      child.properties.each do |prop|
        widget_prop = WidgetProperty.create(prop.attributes)
        new_widget.properties << widget_prop
      end

      new_widget.save
      dashboard.widgets << new_widget
    end
    dashboard.save
    dashboard
  end

  def provided_programmatically?
    shared && user_id.nil?
  end

  protected
  def check_not_default_before_destroy
    if shared?
      default_actives = active_dashboards.select { |ad| ad.default? }
      return default_actives.size==0
    end
    true
  end

  def validate_on_update
    # Check that not used as default dashboard when unsharing
    if shared_was && !shared
      # unsharing
      default_actives = active_dashboards.select { |ad| ad.default? }

      unless default_actives.empty?
        errors.add_to_base(Api::Utils.message('dashboard.error_unshare_default'))
      end
    end
  end
end