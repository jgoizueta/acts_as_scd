require 'test_helper'

class Region <   ActiveRecord::Base

  has_identity :string

  def compute_identity
    self.identity = code
  end

  def to_s
    name
  end

end
