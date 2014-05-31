require 'modalsupport'
require 'acts_as_scd/initialize'
require 'acts_as_scd/period'
require 'acts_as_scd/instance_methods'
require 'acts_as_scd/class_methods'
require 'acts_as_scd/base_class_methods'
require 'acts_as_scd/block_updater'

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
    initialize_scd model
  end

end
