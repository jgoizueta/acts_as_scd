class Country < ActiveRecord::Base

  # Countries will be identified by a 2-character code
  has_identity :string, limit: 2

  # Countries have cities wich also go through iterations
  has_many_iterations_through_identity :cities

  # Countries may belong to associations which are regular models
  belongs_to :commercial_association
  # Countries may be associated with
  has_many_through_identity :commercial_delegates

  # The identity is derived from the country-code. Being a single
  # column, we could skip it and have only the identity column,
  # but for test purposes, we'll keep a separate column to be used
  # for purposes other thant SDE-handling.
  def compute_identity
    self.identity = code
  end

  def to_s
    name
  end

  # To complicate things a little for the tests, we setup a default scope
  # default_scope ->{ order('name').select([:name, :code]) }

end
