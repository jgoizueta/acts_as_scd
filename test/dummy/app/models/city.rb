class City < ActiveRecord::Base

  # Cities will be identified by a 5-character code
  has_identity :string, limit: 5

  belongs_to_identity :country

  def compute_identity
    self.identity = code
  end

  def to_s
    name
  end

  # To complicate things a little for the tests, we setup a default scope
  # default_scope ->{ order('name').select([:name, :code]) }

end
