module ActsAsScd


  module ClassMethods

    # Return objects representing identities; (with a single attribute, :identity)
    # Warning: do not chain this method after other queries;
    # any query should be applied after this method.
    # If identities are required for an association, either latest, earliest or initial can be used
    # (which one is appropriate depends on desired result, data contents, etc.; initial/current are faster)
    def distinct_identities
      # Note that since Rails 2.3.13, when pluck(col) is applied to distinct_identities
      # the "DISTINCT" is lost from the SELECT if added explicitly  as in .select('DISTINCT #{col}'),
      # so we have avoid explicit use of DISTINCT in distinct_identities.
      # This can be used on association queries
      if ActiveRecord::VERSION::MAJOR > 3
        unscope(:select).reorder(identity_column_sql).select(identity_column_sql).uniq
      else
        query = scoped.with_default_scope
        query.select_values.clear
        query.reorder(identity_column_sql).select(identity_column_sql).uniq
      end
    end

    def ordered_identities
      distinct_identities.pluck(identity_column_sql)
    end

    # This can be applied to an ordered query (but returns an Array, not a query)
    def identities
      # pluck(identity_column_sql).uniq # does not work if select has been applied
      scoped.map(&IDENTITY_COLUMN).uniq
    end

    def identities_at(date=nil)
      at(date).identities
    end

    def current_identities
      current.identities
    end

    def identity_column_sql(table_alias=nil)
      %{"#{table_alias || table_name}"."#{IDENTITY_COLUMN}"}
    end

    def effective_from_column_sql(table_alias=nil)
      %{"#{table_alias || table_name}"."#{START_COLUMN}"}
    end

    def effective_to_column_sql(table_alias=nil)
      %{"#{table_alias || table_name}"."#{END_COLUMN}"}
    end

    def effective_date(d)
      Period.date(d)
    end

    # Note that find_by_identity will return nil if there's not a current iteration of the identity
    def find_by_identity(identity, at_date=nil)
      # (at_date.nil? ? current : at(at_date)).where(IDENTITY_COLUMN=>identity).first
      if at_date.nil?
        q = current
      else
        q = at(at_date)
      end
      q = q.where(IDENTITY_COLUMN=>identity)
      q.first
    end

    def identity_exists?(identity, at_date=nil)
      (at_date.nil? ? self : at(at_date)).where(IDENTITY_COLUMN=>identity).exists?
    end

    # The first iteration can be defined with a specific start date, but
    # that is in general a bad idea, since it complicates obtaining
    # the first iteration
    def create_identity(attributes, start=nil)
      start ||= START_OF_TIME
      create(attributes.merge(START_COLUMN=>start || START_OF_TIME))
    end

    # Create a new iteration
    # options
    # :unterminate - if the identity exists and is terminated, unterminate it (extending the last iteration to the new date)
    # :extend_from - if no prior iteration exists, extend effective_from to the start-of-time
    # (TODO: consider making :extend_from the default, adding an option for the opposite...)
    def create_iteration(identity, attribute_changes, start=nil, options={})
      start = effective_date(start || Date.today)
      transaction do
        current_record = find_by_identity(identity)
        if !current_record && options[:unterminate]
          current_record = latest_of(identity) # terminated.where(IDENTITY_COLUMN=>identity).first
          #   where(IDENTITY_COLUMN=>identity).where("#{effective_to_column_sql} < #{END_OF_TIME}").reorder("#{effective_to_column_sql} desc").limit(1).first
        end
        attributes = {IDENTITY_COLUMN=>identity}.with_indifferent_access
        if current_record
          non_replicated_attrs = %w[id effective_from effective_to updated_at created_at]
          attributes = attributes.merge current_record.attributes.with_indifferent_access.except(*non_replicated_attrs)
        end
        start = START_OF_TIME if options[:extend_from] && !identity_exists?(identity)
        attributes = attributes.merge(START_COLUMN=>start).merge(attribute_changes.with_indifferent_access.except(START_COLUMN, END_COLUMN))
        new_record = create(attributes)
        if new_record.errors.blank? && current_record
          # current_record.update_attributes END_COLUMN=>start
          current_record.send :"#{END_COLUMN}=", start
          current_record.save validate: false
        end
        new_record
      end
    end

    def terminate_identity(identity, finish=Date.today)
       finish = effective_date(finish)
       transaction do
         current_record = find_by_identity(identity)
         current_record.update_attributes END_COLUMN=>finish
       end
    end

    # Association yo be used in a parent class which has identity and has children
    # which have identities too;
    # the association is implemented through the identity, not the PK.
    # The inverse association should be belongs_to_identity
    def has_many_iterations_through_identity(assoc, options={})
      fk =  options[:foreign_key] || :"#{model_name.to_s.underscore}_identity"
      assoc_singular = assoc.to_s.singularize
      other_model_name = options[:class_name] || assoc_singular.camelize
      other_model = other_model_name.constantize
      pk = IDENTITY_COLUMN

      # all children iterations
      has_many :"#{assoc_singular}_iterations", class_name: other_model_name, foreign_key: fk, primary_key: pk

      # current_children
      has_many assoc, ->{ where "#{other_model.effective_to_column_sql}=#{END_OF_TIME}" },
               options.reverse_merge(foreign_key: fk, primary_key: pk)
      # has_many assoc, {:foreign_key=>fk, :primary_key=>pk, :conditions=>"#{other_model.effective_to_column_sql}=#{END_OF_TIME}"}.merge(options)

      # children at some date
      define_method :"#{assoc}_at" do |date|
        # other_model.unscoped.at(date).where(fk=>send(pk))
        send(:"#{assoc_singular}_iterations").scoped.at(date)
      end

      # all children identities
      define_method :"#{assoc_singular}_identities" do
        # send(:"#{assoc}_iterations").select("DISTINCT #{other_model.identity_column_sql}").reorder(other_model.identity_column_sql).pluck(:identity)
        # other_model.unscoped.where(fk=>send(pk)).identities
        send(:"#{assoc_singular}_iterations").identities
      end

      # children identities at a date
      define_method :"#{assoc_singular}_identities_at" do |date=nil|
        # send(:"#{assoc}_iterations_at", date).select("DISTINCT #{other_model.identity_column_sql}").reorder(other_model.identity_column_sql).pluck(:identity)
        # other_model.unscoped.where(fk=>send(pk)).identities_at(date)
        send(:"#{assoc_singular}_iterations").identities_at(date)
      end

      # current children identities
      define_method :"#{assoc_singular}_current_identities" do
        # send(assoc).select("DISTINCT #{other_model.identity_column_sql}").reorder(other_model.identity_column_sql).pluck(:identity)
        # other_mode.unscoped.where(fk=>send(pk)).current_identities
        send(:"#{assoc_singular}_iterations").current_identities
      end

    end

    # Association to be used in a parent class which has identity and has children
    # which don't have identities;
    # the association is implemented through the identity, not the PK.
    # The inverse association should be belongs_to_identity
    def has_many_through_identity(assoc, options={})
      fk = :"#{model_name.to_s.underscore}_identity"
      pk = IDENTITY_COLUMN

      has_many assoc, {:foreign_key=>fk, :primary_key=>pk}.merge(options)
    end

    def identity_column_definition
      @slowly_changing_columns.first
    end

    def slow_changing_migration
      migration = ""

      migration << "def up\n"
      @slowly_changing_columns.each do |col, args|
        migration << "  add_column :#{table_name}, :#{col}, #{args.inspect.unwrap('[]')}\n"
      end
      @slowly_changing_indices.each do |index|
        migration << "  add_index :#{table_name}, #{index.inspect}\n"
      end
      migration << "end\n"

      migration << "def down\n"
      @slowly_changing_columns.each do |col, args|
        migration << "  remove_column :#{table_name}, :#{col}\n"
      end
      migration << "end\n"

    end

    def effective_periods(*args)
      # periods = unscoped.select("DISTINCT effective_from, effective_to").order('effective_from, effective_to')
      if ActiveRecord::VERSION::MAJOR > 3
        # periods = unscope(where: [:effective_from, :effective_to]).select("DISTINCT effective_from, effective_to").reorder('effective_from, effective_to')
        periods = unscope(where: [:effective_from, :effective_to]).select([:effective_from, :effective_to]).uniq.reorder('effective_from, effective_to')
      else
        query = scoped.with_default_scope
        query.select_values.clear
        periods = query.reorder('effective_from, effective_to').select([:effective_from, :effective_to]).uniq
      end

      # formerly unscoped was used, so any desired condition had to be defined here
      periods = periods.where(*args) if args.present?

      periods.map{|p| Period[p.effective_from, p.effective_to]}
    end

    # def effective_spans
    #   # select all distinct effective_from, and effective_to, order, return in pairs
    # end

    # Most recent iteration (terminated or not)
    def latest_of(identity)
      where(identity:identity).reorder('effective_to desc').limit(1).first
    end

    def earliest_of(identity)
      where(identity:identity).reorder('effective_to asc').limit(1).first
    end

    def all_of(identity)
      where(identity:identity).reorder('effective_from asc')
    end

  end

end
