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

  test "create identities and iterations" do
    t3 = Country.create_identity(name: 'Testing 3', code: 'T3', area: 1000)
    assert_equal t3.identity, 'T3'
    assert_equal ActsAsScd::START_OF_TIME, t3.effective_from
    assert_equal ActsAsScd::END_OF_TIME, t3.effective_to
    assert_equal 'T3', t3.code
    assert_equal 'Testing 3', t3.name
    assert_equal 1000, t3.area

    date1 = Date.new(2014,02,02)
    t3_2 = Country.create_iteration('T3', { area: 2000 }, date1)
    t3.reload
    assert_equal 2000, t3_2.area
    assert_equal t3.code, t3_2.code
    assert_equal t3.name, t3_2.name
    assert_equal ActsAsScd::START_OF_TIME, t3.effective_from
    assert_equal date1, t3.effective_to_date
    assert_equal date1, t3_2.effective_from_date
    assert_equal ActsAsScd::END_OF_TIME, t3_2.effective_to

    date2 = Date.new(2014,03,02)
    t3_3 = Country.create_iteration('T3', { area: 3000 }, date2)
    t3.reload
    t3_2.reload
    assert_equal 3000, t3_3.area
    assert_equal t3.code, t3_3.code
    assert_equal t3.name, t3_3.name
    assert_equal ActsAsScd::START_OF_TIME, t3.effective_from
    assert_equal date1, t3.effective_to_date
    assert_equal date1, t3_2.effective_from_date
    assert_equal date2, t3_2.effective_to_date
    assert_equal date2, t3_3.effective_from_date
    assert_equal ActsAsScd::END_OF_TIME, t3_3.effective_to

    assert_equal t3_3, Country.find_by_identity('T3')

    assert_equal t3_3, t3.current
    assert_equal t3_3, t3.at(date2)
    assert_equal t3_3, t3.at(date2+10)
    assert_equal t3_2, t3.at(date2-1)
    assert_equal t3_2, t3.at(date1)
    assert_equal t3_2, t3.at(date1+10)
    assert_equal t3,   t3.at(date1-1)

    assert_equal t3_3, t3_2.current
    assert_equal t3_3, t3_2.at(date2)
    assert_equal t3_3, t3_2.at(date2+10)
    assert_equal t3_2, t3_2.at(date2-1)

    assert_equal t3, t3.initial
    assert_equal t3, t3_2.initial
    assert_equal t3, t3_3.initial

    assert_equal t3_2, t3.successor
    assert_equal t3_3, t3_2.successor
    assert_nil         t3_3.successor
    assert_equal t3_2, t3_3.antecessor
    assert_equal t3,   t3_2.antecessor
    assert_nil         t3.antecessor
    assert_equal [t3, t3_2], t3_3.antecessors
    assert_equal [t3], t3_2.antecessors
    assert_equal [], t3.antecessors
    assert_equal [t3_2, t3_3], t3.successors
    assert_equal [t3_3], t3_2.successors
    assert_equal [], t3_3.successors
    assert_equal [t3, t3_2, t3_3], t3.history
    assert_equal [t3, t3_2, t3_3], t3_2.history
    assert_equal [t3, t3_2, t3_3], t3_3.history

    assert_equal t3_3, t3.latest
    assert_equal t3_3, t3_2.latest
    assert_equal t3_3, t3_3.latest

    assert_equal t3, t3_3.earliest
    assert_equal t3, t3_2.earliest
    assert_equal t3, t3.earliest

    assert t3.ended?
    assert t3_2.ended?
    assert !t3_3.ended?

    assert !t3.ended_at?(date1-1)
    assert t3.ended_at?(date1)
    assert t3.ended_at?(date1+1)
    assert t3.ended_at?(date2-1)
    assert t3.ended_at?(date2)
    assert t3.ended_at?(date2+1)

    assert !t3_2.ended_at?(date1-1)
    assert !t3_2.ended_at?(date1)
    assert !t3_2.ended_at?(date1+1)
    assert !t3_2.ended_at?(date2-1)
    assert t3_2.ended_at?(date2)
    assert t3_2.ended_at?(date2+1)

    assert !t3_3.ended_at?(date1-1)
    assert !t3_3.ended_at?(date1)
    assert !t3_3.ended_at?(date1+1)
    assert !t3_3.ended_at?(date2-1)
    assert !t3_3.ended_at?(date2)
    assert !t3_3.ended_at?(date2+1)

    assert t3.initial?
    assert !t3_2.initial?
    assert !t3_3.initial?

    assert !t3.current?
    assert !t3_2.current?
    assert t3_3.current?

    assert !t3.past_limited?
    assert t3.future_limited?
    assert t3_2.past_limited?
    assert t3_2.future_limited?
    assert t3_3.past_limited?
    assert !t3_3.future_limited?

    date3 = Date.new(2014,04,02)
    # t3_2.terminate_identity(date3)
    Country.terminate_identity 'T3', date3
    t3.reload
    t3_2.reload
    t3_3.reload
    assert_nil t3.current
    assert_nil t3_2.current
    assert_nil t3_3.current
    assert_nil Country.find_by_identity('T3')

    assert_nil         t3.at(date3+1)
    assert_nil         t3.at(date3)
    assert_equal t3_3, t3.at(date3-1)
    assert_equal t3_3, t3.at(date2)
    assert_equal t3_3, t3.at(date2+10)
    assert_equal t3_2, t3.at(date2-1)
    assert_equal t3_2, t3.at(date1)
    assert_equal t3_2, t3.at(date1+10)
    assert_equal t3,   t3.at(date1-1)

    assert_equal t3_3, t3_2.at(date2)
    assert_equal t3_3, t3_2.at(date2)
    assert_equal t3_2, t3_2.at(date2-1)

    assert_equal t3, t3.initial
    assert_equal t3, t3_2.initial
    assert_equal t3, t3_3.initial

    assert_equal t3_2, t3.successor
    assert_equal t3_3, t3_2.successor
    assert_nil         t3_3.successor
    assert_equal t3_2, t3_3.antecessor
    assert_equal t3,   t3_2.antecessor
    assert_nil         t3.antecessor
    assert_equal [t3, t3_2], t3_3.antecessors
    assert_equal [t3], t3_2.antecessors
    assert_equal [], t3.antecessors
    assert_equal [t3_2, t3_3], t3.successors
    assert_equal [t3_3], t3_2.successors
    assert_equal [], t3_3.successors
    assert_equal [t3, t3_2, t3_3], t3.history
    assert_equal [t3, t3_2, t3_3], t3_2.history
    assert_equal [t3, t3_2, t3_3], t3_3.history

    assert_equal t3_3, t3.latest
    assert_equal t3_3, t3_2.latest
    assert_equal t3_3, t3_3.latest

    assert_equal t3, t3_3.earliest
    assert_equal t3, t3_2.earliest
    assert_equal t3, t3.earliest

    assert t3.ended?
    assert t3_2.ended?
    assert t3_3.ended?

    assert !t3.ended_at?(date1-1)
    assert t3.ended_at?(date1)
    assert t3.ended_at?(date1+1)
    assert t3.ended_at?(date2-1)
    assert t3.ended_at?(date2)
    assert t3.ended_at?(date2+1)

    assert !t3_2.ended_at?(date1-1)
    assert !t3_2.ended_at?(date1)
    assert !t3_2.ended_at?(date1+1)
    assert !t3_2.ended_at?(date2-1)
    assert t3_2.ended_at?(date2)
    assert t3_2.ended_at?(date2+1)

    assert !t3_3.ended_at?(date1-1)
    assert !t3_3.ended_at?(date1)
    assert !t3_3.ended_at?(date1+1)
    assert !t3_3.ended_at?(date2-1)
    assert !t3_3.ended_at?(date2)
    assert !t3_3.ended_at?(date2+1)
    assert !t3_3.ended_at?(date3-1)
    assert  t3_3.ended_at?(date3)
    assert  t3_3.ended_at?(date3+1)

    assert t3.initial?
    assert !t3_2.initial?
    assert !t3_3.initial?

    assert !t3.current?
    assert !t3_2.current?
    assert !t3_3.current?

    assert !t3.past_limited?
    assert t3.future_limited?
    assert t3_2.past_limited?
    assert t3_2.future_limited?
    assert t3_3.past_limited?
    assert t3_3.future_limited?

  end

  test "find_by_identity" do

    de1 = countries(:de1)
    de2 = countries(:de2)
    de3 = countries(:de3)
    ddr = countries(:ddr)
    uk1 = countries(:uk1)
    uk2 = countries(:uk2)
    sco = countries(:scotland)
    cal = countries(:caledonia)

    assert_equal de3, Country.find_by_identity('DEU')
    assert_nil Country.find_by_identity('DDR')
    assert_equal uk2, Country.find_by_identity('GBR')
    assert_equal sco, Country.find_by_identity('SCO')

    assert_equal de3, Country.find_by_identity('DEU', Date.new(3000,1,1))
    assert_equal de3, Country.find_by_identity('DEU', Date.new(2000,1,1))
    assert_equal de3, Country.find_by_identity('DEU', Date.new(1990,10,3))
    assert_equal de2, Country.find_by_identity('DEU', Date.new(1990,10,2))
    assert_equal de2, Country.find_by_identity('DEU', Date.new(1970,1,1))
    assert_equal de2, Country.find_by_identity('DEU', Date.new(1949,10,7))
    assert_equal de1, Country.find_by_identity('DEU', Date.new(1949,10,6))
    assert_equal de1, Country.find_by_identity('DEU', Date.new(1940,1,1))
    assert_equal de1, Country.find_by_identity('DEU', Date.new(1000,1,1))
    assert_equal cal, Country.find_by_identity('CL',  Date.new(3000,1,1))
    assert_equal de3, Country.find_by_identity('DEU', Date.new(2000,1,1))
    assert_equal de3, Country.find_by_identity('DEU', Date.new(1990,10,3))
    assert_equal de2, Country.find_by_identity('DEU', Date.new(1990,10,2))
    assert_equal de2, Country.find_by_identity('DEU', Date.new(1970,1,1))
    assert_equal de2, Country.find_by_identity('DEU', Date.new(1949,10,7))
    assert_equal de1, Country.find_by_identity('DEU', Date.new(1949,10,6))
    assert_equal de1, Country.find_by_identity('DEU', Date.new(1940,1,1))
    assert_equal de1, Country.find_by_identity('DEU', Date.new(1000,1,1))
    assert_nil        Country.find_by_identity('DDR', Date.new(1940,1,1))
    assert_nil        Country.find_by_identity('DDR', Date.new(1949,10,6))
    assert_equal ddr, Country.find_by_identity('DDR', Date.new(1949,10,7))
    assert_equal ddr, Country.find_by_identity('DDR', Date.new(1970,1,1))
    assert_equal ddr, Country.find_by_identity('DDR', Date.new(1990,10,2))
    assert_nil        Country.find_by_identity('DDR', Date.new(1990,10,3))
    assert_nil        Country.find_by_identity('DDR', Date.new(2015,1,1))

  end

  test "identity_exists?" do

    de1 = countries(:de1)
    de2 = countries(:de2)
    de3 = countries(:de3)
    ddr = countries(:ddr)
    uk1 = countries(:uk1)
    uk2 = countries(:uk2)
    sco = countries(:scotland)
    cal = countries(:caledonia)

    assert  Country.identity_exists?('DEU')
    assert  Country.identity_exists?('DDR')
    assert  Country.identity_exists?('GBR')
    assert  Country.identity_exists?('SCO')

    assert  Country.identity_exists?('DEU', Date.new(3000,1,1))
    assert  Country.identity_exists?('DEU', Date.new(2000,1,1))
    assert  Country.identity_exists?('DEU', Date.new(1990,10,3))
    assert  Country.identity_exists?('DEU', Date.new(1990,10,2))
    assert  Country.identity_exists?('DEU', Date.new(1970,1,1))
    assert  Country.identity_exists?('DEU', Date.new(1949,10,7))
    assert  Country.identity_exists?('DEU', Date.new(1949,10,6))
    assert  Country.identity_exists?('DEU', Date.new(1940,1,1))
    assert  Country.identity_exists?('DEU', Date.new(1000,1,1))
    assert  Country.identity_exists?('CL',  Date.new(3000,1,1))
    assert  Country.identity_exists?('DEU', Date.new(2000,1,1))
    assert  Country.identity_exists?('DEU', Date.new(1990,10,3))
    assert  Country.identity_exists?('DEU', Date.new(1990,10,2))
    assert  Country.identity_exists?('DEU', Date.new(1970,1,1))
    assert  Country.identity_exists?('DEU', Date.new(1949,10,7))
    assert  Country.identity_exists?('DEU', Date.new(1949,10,6))
    assert  Country.identity_exists?('DEU', Date.new(1940,1,1))
    assert  Country.identity_exists?('DEU', Date.new(1000,1,1))
    assert !Country.identity_exists?('DDR', Date.new(1940,1,1))
    assert !Country.identity_exists?('DDR', Date.new(1949,10,6))
    assert  Country.identity_exists?('DDR', Date.new(1949,10,7))
    assert  Country.identity_exists?('DDR', Date.new(1970,1,1))
    assert  Country.identity_exists?('DDR', Date.new(1990,10,2))
    assert !Country.identity_exists?('DDR', Date.new(1990,10,3))
    assert !Country.identity_exists?('DDR', Date.new(2015,1,1))

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
    assert_nil Country.current.where(identity: 'DDR').first
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
    assert_equal ddr, Country.ended.where(identity: 'DDR').first

    assert_equal [de1, de2, de3], Country.all_of('DEU')

    # These generate queries that are valid for PostgreSQL but not for SQLite3
    #   (v1, v2) IN SELECT ...
    # assert_equal 1, Country.ended.latest.count
    # assert_equal 1, Country.terminated.count
    # assert_equal 1, Country.superseded.count
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
