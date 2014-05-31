require 'test_helper'
require 'models/region'
require 'active_record/fixtures'

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false

ActiveRecord::Schema.define do

  create_table :regions, :force => true do |t|
    t.string  :name
    t.string  :code
    t.string  :identity
    t.integer :effective_from, default: 0
    t.integer :effective_to, default: 99999999
  end

end

class ActsAsScdTest < ActiveSupport::TestCase

  # self.fixture_path = File.expand_path("../fixtures", __FILE__)
  # fixtures :all
  fixtures :regions


  test "truth" do
    assert_kind_of Module, ActsAsScd
  end

  test "Models can act as SCD" do
    assert_equal regions(:caledonia), Region.find_by_identity('0001', Date.today)
    assert_equal Date.new(2014,3,2), regions(:changedonia_first).effective_to_date
    assert_equal Date.new(2014,3,2), regions(:changedonia_second).effective_from_date
    assert_equal regions(:changedonia_third), regions(:changedonia_first).current
    assert_equal regions(:changedonia_third), regions(:changedonia_second).current
    assert_equal regions(:changedonia_second), regions(:changedonia_first).successor
    assert_equal regions(:changedonia_third), regions(:changedonia_second).successor
  end

  test "Identities have iterations" do
    caledonia = regions(:caledonia)
    # caledonia = Region.create!(name: 'Testing', code: '000X', identity: '000X')
    assert_equal 99999999, caledonia.effective_to
  end

  test "New records have identity automatically assigned and are not time-limited" do
    region = Region.create!(name: 'Testing 1', code: '000X')
    assert_equal region.identity, '000X'
    assert_equal ActsAsScd::START_OF_TIME, region.effective_from
    assert_equal ActsAsScd::END_OF_TIME, region.effective_to
  end

  test "New identities are not time-limited" do
    date = Date.new(2014,03,07)
    region = Region.create_identity(name: 'Testing 2', code: '000Y')
    assert_equal region.identity, '000Y'
    assert_equal ActsAsScd::START_OF_TIME, region.effective_from
    assert_equal ActsAsScd::END_OF_TIME, region.effective_to
  end

end
