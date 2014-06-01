class CommercialAssociation < ActiveRecord::Base

  def to_s
    name
  end

  has_many_identities :country

end
