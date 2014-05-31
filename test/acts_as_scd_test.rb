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
    assert Region.acts_as_scd?
  end

  test "Identities have iterations" do
    caledonia = regions(:caledonia)
    # caledonia = Region.create!(name: 'Testing', code: '000X', identity: '000X')
    assert_equal 99999999, caledonia.effective_to
  end

end

