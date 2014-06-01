require 'test_helper'
# require 'models/country'
# require 'models/city'
# require 'models/association'
# require 'models/delegate'
require 'active_record/fixtures'

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false

# Tests data model:
# We'll have two models which represent geographical entities and are subject
# to changes over time such as modified geographical limits, entities may
# disappear or new ones come into existence (as in countries that split, etc.).
# We'll assume to such levels of geographical entities, Country and City for
# which we want to keep the historical state at any time. We'll use a simple
# 'area' field to stand for the various spatial or otherwise properties that
# would typically change between revisions.
ActiveRecord::Schema.define do

  create_table :countries, :force => true do |t|
    t.string  :code, limit: 2
    t.string  :identity, limit: 2
    t.integer :effective_from, default: 0
    t.integer :effective_to, default: 99999999
    t.string  :name
    t.float   :area
    t.integer :commercial_association_id
  end

  add_index :countries, :identity
  add_index :countries, :effective_from
  add_index :countries, :effective_to
  add_index :countries, [:effective_from, :effective_to]

  create_table :cities, :force => true do |t|
    t.string  :code, limit: 5
    t.string  :identity, limit: 5
    t.integer :effective_from, default: 0
    t.integer :effective_to, default: 99999999
    t.string  :name
    t.float   :area
    t.string  :country_identity, limit: 2
  end

  add_index :cities, :identity
  add_index :cities, :effective_from
  add_index :cities, :effective_to
  add_index :cities, [:effective_from, :effective_to]

  create_table :commercial_associations, :force => true do |t|
    t.string  :name
  end

  create_table :commercial_delegates, :force => true do |t|
    t.string   :name
    t.string   :country_identity, limit: 2
  end

end

class ActsAsScdTest < ActiveSupport::TestCase

  fixtures :all

  test "Models can act as SCD" do
    assert_equal countries(:caledonia), Country.find_by_identity('CL', Date.today)
    assert_equal Date.new(2014,3,2), countries(:changedonia_first).effective_to_date
    assert_equal Date.new(2014,3,2), countries(:changedonia_second).effective_from_date
    assert_equal countries(:changedonia_third), countries(:changedonia_first).current
    assert_equal countries(:changedonia_third), countries(:changedonia_second).current
    assert_equal countries(:changedonia_second), countries(:changedonia_first).successor
    assert_equal countries(:changedonia_third), countries(:changedonia_second).successor
  end

  test "Identities have iterations" do
    caledonia = countries(:caledonia)
    assert_equal 99999999, caledonia.effective_to
  end

  test "New records have identity automatically assigned and are not time-limited" do
    country = Country.create!(name: 'Testing 1', code: 'T1')
    assert_equal country.identity, 'T1'
    assert_equal ActsAsScd::START_OF_TIME, country.effective_from
    assert_equal ActsAsScd::END_OF_TIME, country.effective_to
  end

  test "New identities are not time-limited" do
    date = Date.new(2014,03,07)
    country = Country.create_identity(name: 'Testing 2', code: 'T2')
    assert_equal country.identity, 'T2'
    assert_equal ActsAsScd::START_OF_TIME, country.effective_from
    assert_equal ActsAsScd::END_OF_TIME, country.effective_to
  end

end
