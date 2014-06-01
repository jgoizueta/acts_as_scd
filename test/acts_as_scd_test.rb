require 'test_helper'
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

  test "Model query methods" do

    de1 = countries(:de1)
    de2 = countries(:de2)
    de3 = countries(:de3)
    ddr = countries(:ddr)
    uk1 = countries(:uk1)
    uk2 = countries(:uk2)
    sco = countries(:scotland)
    cal = countries(:caledonia)

    assert_equal de3, Country.current.where(identity: 'DEU').first
    assert_nil Country.initial.where(identity: 'DDR').first
    assert_equal uk2, Country.current.where(identity: 'GBR').first
    assert_equal sco, Country.current.where(identity: 'SCO').first
    assert_equal 5, Country.current.count

    assert_equal de1, Country.initial.where(identity: 'DEU').first
    assert_nil        Country.initial.where(identity: 'DDR').first
    assert_nil        Country.initial.where(identity: 'SCO').first
    assert_equal uk1, Country.initial.where(identity: 'GBR').first
    assert_equal 4, Country.initial.count

    assert_equal de1, Country.earliest_of('DEU')
    assert_equal uk1, Country.earliest_of('GBR')
    assert_equal ddr, Country.earliest_of('DDR')
    assert_equal sco, Country.earliest_of('SCO')
    assert_equal cal, Country.earliest_of('CL')

    assert_equal de3, Country.at(Date.new(3000,1,1)).where(identity: 'DEU').first
    assert_equal de3, Country.at(Date.new(2000,1,1)).where(identity: 'DEU').first
    assert_equal de3, Country.at(Date.new(1990,10,3)).where(identity: 'DEU').first
    assert_equal de2, Country.at(Date.new(1990,10,2)).where(identity: 'DEU').first
    assert_equal de2, Country.at(Date.new(1970,1,1)).where(identity: 'DEU').first
    assert_equal de2, Country.at(Date.new(1949,10,7)).where(identity: 'DEU').first
    assert_equal de1, Country.at(Date.new(1949,10,6)).where(identity: 'DEU').first
    assert_equal de1, Country.at(Date.new(1940,1,1)).where(identity: 'DEU').first
    assert_equal de1, Country.at(Date.new(1000,1,1)).where(identity: 'DEU').first
    assert_equal cal, Country.at(Date.new(3000,1,1)).where(identity: 'CL').first
    assert_equal de3, Country.at(Date.new(2000,1,1)).where(identity: 'DEU').first
    assert_equal de3, Country.at(Date.new(1990,10,3)).where(identity: 'DEU').first
    assert_equal de2, Country.at(Date.new(1990,10,2)).where(identity: 'DEU').first
    assert_equal de2, Country.at(Date.new(1970,1,1)).where(identity: 'DEU').first
    assert_equal de2, Country.at(Date.new(1949,10,7)).where(identity: 'DEU').first
    assert_equal de1, Country.at(Date.new(1949,10,6)).where(identity: 'DEU').first
    assert_equal de1, Country.at(Date.new(1940,1,1)).where(identity: 'DEU').first
    assert_equal de1, Country.at(Date.new(1000,1,1)).where(identity: 'DEU').first
    assert_nil Country.at(Date.new(1940,1,1)).where(identity: 'DDR').first
    assert_nil Country.at(Date.new(1949,10,6)).where(identity: 'DDR').first
    assert_equal ddr, Country.at(Date.new(1949,10,7)).where(identity: 'DDR').first
    assert_equal ddr, Country.at(Date.new(1970,1,1)).where(identity: 'DDR').first
    assert_equal ddr, Country.at(Date.new(1990,10,2)).where(identity: 'DDR').first
    assert_nil        Country.at(Date.new(1990,10,3)).where(identity: 'DDR').first
    assert_nil        Country.at(Date.new(2015,1,1)).where(identity: 'DDR').first
    assert_equal 4, Country.at(Date.new(1940,1,1)).count
    assert_equal 4, Country.at(Date.new(1949,10,6)).count
    assert_equal 5, Country.at(Date.new(1949,10,7)).count
    assert_equal 5, Country.at(Date.new(1970,1,1)).count
    assert_equal 5, Country.at(Date.new(1990,10,2)).count
    assert_equal 4, Country.at(Date.new(1990,10,3)).count
    assert_equal 4, Country.at(Date.new(2000,1,1)).count
    assert_equal 4, Country.at(Date.new(2000,1,1)).count
    assert_equal 4, Country.at(Date.new(2014,3,1)).count
    assert_equal 4, Country.at(Date.new(2014,3,2)).count
    assert_equal 4, Country.at(Date.new(2014,9,17)).count
    assert_equal 5, Country.at(Date.new(2014,9,18)).count
    assert_equal 5, Country.at(Date.new(2015,1,1)).count

    assert_equal 6, Country.ended.count
    # assert_equal 1, Country.ended.latest.count
    assert_equal ddr, Country.ended.where(identity: 'DDR').first

end

  test "Model query methods that return objects" do

    de1 = countries(:de1)
    de2 = countries(:de2)
    de3 = countries(:de3)
    ddr = countries(:ddr)
    uk1 = countries(:uk1)
    uk2 = countries(:uk2)
    sco = countries(:scotland)
    cal = countries(:caledonia)

    assert_equal de3, Country.latest_of('DEU')
    assert_equal ddr, Country.latest_of('DDR')
    assert_equal uk2, Country.latest_of('GBR')
    assert_equal sco, Country.latest_of('SCO')

    assert_equal de1, Country.earliest_of('DEU')
    assert_equal ddr, Country.earliest_of('DDR')
    assert_equal uk1, Country.earliest_of('GBR')
    assert_equal sco, Country.earliest_of('SCO')

    c = Country.scoped

    assert_equal %w(CG CL DDR DEU GBR SCO), Country.ordered_identities
    assert_equal %w(CG CL DEU GBR SCO), Country.current.ordered_identities
    assert_equal %w(CG CL DEU GBR SCO), Country.at(Date.new(2015,1,1)).ordered_identities
    assert_equal %w(CG CL DEU GBR SCO), Country.at(Date.new(2014,9,18)).ordered_identities
    assert_equal %w(CG CL DEU GBR), Country.at(Date.new(2014,9,17)).ordered_identities
    assert_equal %w(CG CL DEU GBR), Country.at(Date.new(2014,3,2)).ordered_identities
    assert_equal %w(CG CL DEU GBR), Country.at(Date.new(2014,3,1)).ordered_identities
    assert_equal %w(CG CL DEU GBR), Country.at(Date.new(1990,10,3)).ordered_identities
    assert_equal %w(CG CL DDR DEU GBR), Country.at(Date.new(1990,10,2)).ordered_identities
    assert_equal %w(CG CL DDR DEU GBR), Country.at(Date.new(1970,1,1)).ordered_identities
    assert_equal %w(CG CL DDR DEU GBR), Country.at(Date.new(1949,10,7)).ordered_identities
    assert_equal %w(CG CL DEU GBR), Country.at(Date.new(1949,10,6)).ordered_identities
    assert_equal %w(CG CL DEU GBR), Country.at(Date.new(1940,1,1)).ordered_identities

    assert_equal %w(CG CL DDR DEU GBR SCO), Country.ordered_identities
    assert_equal %w(CG CL DEU GBR SCO), Country.current.ordered_identities
    assert_equal %w(CG CL DEU GBR SCO), Country.identities_at(Date.new(2015,1,1)).sort
    assert_equal %w(CG CL DEU GBR SCO), Country.identities_at(Date.new(2014,9,18)).sort
    assert_equal %w(CG CL DEU GBR), Country.identities_at(Date.new(2014,9,17)).sort
    assert_equal %w(CG CL DEU GBR), Country.identities_at(Date.new(2014,3,2)).sort
    assert_equal %w(CG CL DEU GBR), Country.identities_at(Date.new(2014,3,1)).sort
    assert_equal %w(CG CL DEU GBR), Country.identities_at(Date.new(1990,10,3)).sort
    assert_equal %w(CG CL DDR DEU GBR), Country.identities_at(Date.new(1990,10,2)).sort
    assert_equal %w(CG CL DDR DEU GBR), Country.identities_at(Date.new(1970,1,1)).sort
    assert_equal %w(CG CL DDR DEU GBR), Country.identities_at(Date.new(1949,10,7)).sort
    assert_equal %w(CG CL DEU GBR), Country.identities_at(Date.new(1949,10,6)).sort
    assert_equal %w(CG CL DEU GBR), Country.identities_at(Date.new(1940,1,1)).sort

    assert_equal %w(CG CL DEU GBR SCO), Country.current_identities.sort

    assert_equal [ActsAsScd::Period[0, 99999999]],
                 Country.where(identity: 'CL').effective_periods
    assert_equal [ActsAsScd::Period[19491007, 19901003]],
                 Country.where(identity: 'DDR').effective_periods
    assert_equal [ActsAsScd::Period[20140918, 99999999]],
                 Country.where(identity: 'SCO').effective_periods
    assert_equal [ActsAsScd::Period[0, 20140918], ActsAsScd::Period[20140918, 99999999]],
                 Country.where(identity: 'GBR').effective_periods
    assert_equal [ActsAsScd::Period[0, 19491007], ActsAsScd::Period[19491007, 19901003], ActsAsScd::Period[19901003, 99999999]],
                 Country.where(identity: 'DEU').effective_periods
    assert_equal [[0,19491007], [0, 20140302], [0, 20140918], [0, 99999999], [19491007, 19901003], [19901003, 99999999],
                  [20140302, 20140507], [20140507, 99999999], [20140918, 99999999]].map{|p| ActsAsScd::Period[*p]},
                 Country.effective_periods

  end

end
