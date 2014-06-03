module ActsAsScd

  # TODO: replace identity by send(IDENTITY_COLUMN)...

  def current
    self.class.find_by_identity(identity)
  end

  def initial
    self.class.initial.where(IDENTITY_COLUMN=>identity).first
  end

  def at(date=nil)
    if date.present?
      self.class.find_by_identity(identity, date)
    else
      current
    end
  end

  def successor
    return nil if effective_to==END_OF_TIME
    self.class.where(identity:identity, effective_from:effective_to).first
  end

  def antecessor
    return nil if effective_from==START_OF_TIME
    self.class.where(identity:identity, effective_to:effective_from).first
  end

  def successors
    return self.class.where('1=0') if effective_to==END_OF_TIME
    self.class.where(identity:identity).where('effective_from>=:date', date: effective_to).reorder('effective_from')
  end

  def antecessors
    return self.class.where('1=0') if effective_from==START_OF_TIME
    self.class.where(identity:identity).where('effective_to<=:date', date: effective_from).reorder('effective_to')
  end

  def history
    self.class.all_of(identity)
  end

  def latest
    self.class.where(identity:identity).reorder('effective_to desc').limit(1).first
  end

  def earliest
    self.class.where(identity:identity).reorder('effective_from asc').limit(1).first
  end

  def terminate_identity(finish=Date.today)
     finish = self.class.effective_date(finish)
     update_attributes END_COLUMN=>finish
  end

  def ended?
    effective_to < END_OF_TIME
  end

  def ended_at?(date)
    effective_to <= self.class.effective_date(date)
  end

  def effective_period
    Period[effective_from, effective_to]
  end

  def effective_from_date
    case effective_from
    when END_OF_TIME
      raise "Invalid effective_from value: #{END_OF_TIME}"
    else
      Period::DateValue[effective_from].to_date
    end
  end

  def effective_to_date
    case effective_to
    when START_OF_TIME
      raise "Invalid effective_to value #{START_OF_TIME}"
    else
      Period::DateValue[effective_to].to_date
    end
  end

  def initial?
    effective_period.initial?
  end

  def current?
    effective_period.current?
  end

  def past_limited?
    effective_period.past_limited?
  end

  def future_limited?
    effective_period.future_limited?
  end

  def limited?
    effective_period.limited?
  end

  def remove_this_iteration
    s = successor
    s.update_attributes effective_from: self.effective_from if s
    a = antecessor
    a.update_attributes effective_to: self.effective_to if a
  end

end
