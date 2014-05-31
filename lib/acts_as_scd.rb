module ActsAsScd

  begin
    require 'rails'

    class Railtie < Rails::Railtie
      initializer 'acts_as_scd.insert_into_active_record' do
        ActiveSupport.on_load :active_record do
          # ActiveRecord::Base.send(:include, ActsAsScd)
          ActiveRecord::Base.extend ActsAsScd::BaseClassMethods
        end
      end
    end
  rescue LoadError
    # ActiveRecord::Base.send(:include, ActAsScd) if defined?(ActiveRecord)
    ActiveRecord::Base.extend ActsAsScd::BaseClassMethods if defined?(ActiveRecord)
  end

  def self.included(model)
    model.extend ClassMethods
  end

  module BaseClassMethods

    def acts_as_scd(*args)
      has_identity *args
    end

    def has_identity(*args)
      # @slowly_changing_columns ||= []
      # @slowly_changing_indices ||= []
      # @slowly_changing_columns += [[IDENTITY_COLUMN, args], [START_COLUMN, [:integer, :default=>START_OF_TIME]], [END_COLUMN, [:integer, :default=>END_OF_TIME]]]
      # @slowly_changing_indices += [IDENTITY_COLUMN, START_COLUMN, END_COLUMN, [START_COLUMN, END_COLUMN]]
      include ActsAsScd
      # fields do
      #   identity *args
      #   effective_from :integer, :default=>START_OF_TIME
      #   effective_to :integer, :default=>END_OF_TIME
      # end
    end
  end

  module ClassMethods
    def acts_as_scd?
      true
    end
  end

end
