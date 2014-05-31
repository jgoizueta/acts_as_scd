require 'test_helper'

class Region <   ActiveRecord::Base

  acts_as_scd

  def to_s
    name
  end

end
