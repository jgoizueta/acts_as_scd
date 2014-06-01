class CommercialDelegate < ActiveRecord::Base

  def to_s
    name
  end

  belongs_to_identity :country

end
