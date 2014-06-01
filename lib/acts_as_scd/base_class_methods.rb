module ActsAsScd


  module BaseClassMethods

    def acts_as_scd(*args)
      @slowly_changing_columns ||= []
      @slowly_changing_indices ||= []
      @slowly_changing_columns += [[IDENTITY_COLUMN, args], [START_COLUMN, [:integer, :default=>START_OF_TIME]], [END_COLUMN, [:integer, :default=>END_OF_TIME]]]
      @slowly_changing_indices += [IDENTITY_COLUMN, START_COLUMN, END_COLUMN, [START_COLUMN, END_COLUMN]]
      include ActsAsScd
    end

    def has_identity(*args)
      acts_as_scd *args
      if defined?(ModalFields) && respond_to?(:fields)
        fields do
          identity *args
          effective_from :integer, :default=>START_OF_TIME
          effective_to :integer, :default=>END_OF_TIME
        end
      end
    end

    # Association to be used in a child which belongs to a parent which has identity
    # (the identity is used for the association rather than the id).
    # The inverse assocation should be has_many_through_identity.
    def belongs_to_identity(assoc, options={})
      other_model = assoc.to_s.camelize.constantize
      fk = :"#{other_model.model_name.to_s.underscore}_identity"
      if defined?(@slowly_changing_columns)
        @slowly_changing_columns << [fk, other_model.identity_column_definition.last]
        @slowly_changing_indices << fk
      end
      belongs_to assoc, ->{ where "#{other_model.effective_to_column_sql()}=#{END_OF_TIME}" },
                 options.reverse_merge(foreign_key: fk, primary_key: IDENTITY_COLUMN)
      # For Rails 3 is this necessary?:
      # belongs_to assoc, {:foreign_key=>fk, :primary_key=>IDENTITY_COLUMN, :conditions=>"#{other_model.effective_to_column_sql()}=#{END_OF_TIME}"}.merge(options)
      define_method :"#{assoc}_at" do |date=nil|
        other_model.at(date).where(IDENTITY_COLUMN=>send(fk)).first
      end
    end

    # Association to be used in a parent class which has children which have identities
    # (the parent class is referenced by id and may not have identity)
    # The inverse association should be belongs_to
    def has_many_identities(assoc, options)
      fk =  options[:foreign_key] || :"#{model_name.to_s.underscore}_id"
      pk = primary_key
      other_model_name = options[:class_name] || assoc.to_s.singularize.camelize
      other_model = other_model_name.to_s.constantize

      # all children iterations
      has_many :"#{assoc}_iterations", class_name: other_model_name, foreign_key: fk

      # current children:
      # has_many assoc, options.merge(conditions: ["#{model.effective_to_column_sql} = :date", :date=>END_OF_TIME)]
      define_method assoc do
        send(:"#{assoc}_iterations").current
      end
      # children at some date
      define_method :"#{assoc}_at" do |date=nil|
        # has_many assoc, options.merge(conditions: [%{#{model.effective_from_column_sql}<=:date AND #{model.effective_to_column_sql}>:date}, :date=>model.effective_date(date)]
        send(:"#{assoc}_iterations").scoped.at(date) # scoped necessary here to avoid delegation to Array
      end

      # all children identities
      define_method :"#{assoc}_identities" do
        # send(:"#{assoc}_iterations").select("DISTINCT #{other_model.identity_column_sql}").order(other_model.identity_column_sql).pluck(:identity)
        # other_model.unscoped.where(fk=>send(pk)).identities
        send(:"#{assoc}_iterations").identities
      end

      # children identities at a date
      define_method :"#{assoc}_identities_at" do |date=nil|
        # send(:"#{assoc}_iterations_at", date).select("DISTINCT #{other_model.identity_column_sql}").order(other_model.identity_column_sql).pluck(:identity)
        # other_model.unscoped.where(fk=>send(pk)).identities_at(date)
        send(:"#{assoc}_iterations").identities_at(date)
      end

      # current children identities
      define_method :"#{assoc}_current_identities" do
        # send(assoc).select("DISTINCT #{other_model.identity_column_sql}").order(other_model.identity_column_sql).pluck(:identity)
        # other_model.unscoped.where(fk=>send(pk)).current_identities
        send(:"#{assoc}_iterations").current_identities
      end

    end

    # Since this code has been extracted from a Rails 3 project, we need to adapt to Rails 4
    # For a gradual transition and to allow compatibility with Rails 3 we'll provide this
    # for the time being:
    if ActiveRecord::VERSION::MAJOR > 3
      def scoped
        all
      end
    end

  end

end