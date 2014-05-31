module ActsAsScd

  # BlockUpdater is a utilty to batch-update a SCD table, in a way
  # in which at a given date all the identities of the table are updated.
  # No iteration will span the update date. Current iterations at the
  # update date will end at that date and new iterations will start at it.
  #
  # This update style simplifies managing tables with identities;
  # effective periods ara shared by all the identities.
  #
  class BlockUpdater

    # Block-Update a table with identities:
    #
    # ActsAsScd::BlockUpdater.update Model, date do |updater|
    #   new_records.each do |record_attributes|
    #     updater.add(record_attributes) do |record|
    #       raise "Error" if record.errors.present?
    #     end
    #   end
    # end
    #
    def self.update(model, fecha, options={})
      updater = new(model, fecha, options={})
      model.transaction do
        updater.start
        yield updater
        updater.finish
      end
      updater
    end

    # Delete a block-update.
    def self.delete(model, fecha, options={})
      updater = new(model, fecha, options={})
      updater.delete_all
    end

    # Check if a block-update has been performed at the given date
    def self.exists?(model, fecha, options={})
      updater = new(model, fecha, options={})
      updater.exists?
    end

    def self.count(model, fecha, options={})
      updater = new(model, fecha, options={})
      updater.count
    end

    def initialize(model, fecha, options={})
      @model = model
      @fecha = fecha
      @preterminate = false
      @raise_on_error = options.delete :raise_on_error
      @scope = options.delete :scope
      # @extend_from = options[:extend_from]
      # @unterminate = options[:unterminate]
      @iteration_options = options.dup
    end

    attr_reader :model, :fecha, :counters, :new_items, :old_items, :missing_items

    def scoped_model
      if @scope.present?
        if Symbol === @scope
          @model.send(@scope)
        else
          @model.where(scope)
        end
      else
        @model
      end
    end

    def start
      @new_items = 0
      @old_items = 0
      @missing_items = 0
      if @preterminate
        @pre_items = scoped_model.current.count
        scoped_model.current.update_all(:effective_to=>model.effective_date(fecha))
        # @unterminate = true
        @iteration_options[:unterminate] = true
      end
      self
    end

    def add(identity, attributes={})
      record = model.create_iteration(identity, attributes, fecha, @iteration_options)
      yield record if block_given?
      raise "Errors: #{record.errors.full_messages}" if @raise_on_error && record.errors.present?
      if record.antecessor
        @old_items += 1
      else
        @new_items += 1
      end
      record
    end

    def finish
      if @preterminate
        @missing_items = @pre_items - @old_items
      else
        scoped_model.current.where('effective_from < :fecha', fecha: model.effective_date(fecha)).each do |record|
          record.terminate_identity fecha
          @missing_items += 1
        end
      end
      self
    end

    def delete_all
      date = ActsAsScd::Period.date(fecha)
      query = scoped_model.where(effective_from: date)
      @missing_items = query.count
      query.destroy_all
      self
    end

    def identity_exists?(identity)
      date = ActsAsScd::Period.date(fecha)
      scoped_model.where(effective_from: date, identity: identity).exists?
    end

    def find_identity(identity)
      date = ActsAsScd::Period.date(fecha)
      scoped_model.where(effective_from: date, identity: identity).first
    end

    def exists?
      date = ActsAsScd::Period.date(fecha)
      scoped_model.where(effective_from: date).exists?
    end

    def count
      date = ActsAsScd::Period.date(fecha)
      scoped_model.where(effective_from: date).count
    end

  end

end
