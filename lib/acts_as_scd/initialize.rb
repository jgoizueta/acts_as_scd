module ActsAsScd

  # Internal value to represent the start of time
  START_OF_TIME   = 0
  # Internal value to represent the end of time
  END_OF_TIME     = 99999999

  # TODO: paremeterize the column names

  # Column that represents the identity of an entity
  IDENTITY_COLUMN = :identity
  # Column that represents start of an iteration's life
  START_COLUMN    = :effective_from
  # Column that represents end of an iteration's life
  END_COLUMN      = :effective_to

  def self.initialize_scd(model)
    model.extend ClassMethods

    # Current iterations
    model.scope :current, ->{model.where("#{model.effective_to_column_sql} = :date", :date=>END_OF_TIME)}
    model.scope :initial, ->{model.where("#{model.effective_from_column_sql} = :date", :date=>START_OF_TIME)}
    # Iterations effective at given date
    # Note that since Array has an 'at' method, this cannot be applied directly to
    # associations (the Array method would be used after generating an Array from the query).
    # It is necessary to use .scoped.at(...) for associations.
    model.scope :at, ->(date=nil){
      # TODO: consider renaming this to current_at or active_at to avoid having to use
      # scoped with associations
      if date.present?
        model.where(%{#{model.effective_from_column_sql}<=:date AND #{model.effective_to_column_sql}>:date}, :date=>model.effective_date(date))
      else
        model.current
      end
    }
    # Iterations superseded/terminated
    model.scope :ended, ->{model.where("#{model.effective_to_column_sql} < :date", :date=>END_OF_TIME)}
    model.scope :earliest, ->(identity=nil){
      if identity
        identity_column = model.identity_column_sql('earliest_tmp')
        if Array==identity
          identity_list = identity.map{|i| model.connection.quote(i)}*','
          where_condition = "WHERE #{identity_column} IN (#{identity_list})"
        else
          where_condition = "WHERE #{identity_column}=#{model.connection.quote(identity)}"
        end
      end
      model.where(
        %{(#{model.identity_column_sql}, #{model.effective_from_column_sql}) IN
            (SELECT #{model.identity_column_sql('earliest_tmp')},
                    MIN(#{model.effective_from_column_sql('earliest_tmp')}) AS earliest_from
             FROM #{model.table_name} AS "earliest_tmp"
             #{where_condition}
             GROUP BY #{model.identity_column_sql('earliest_tmp')})
         }
      )
    }
    # Latest iteration (terminated or current) of each identity
    model.scope :latest, ->(identity=nil){
      if identity
        identity_column = model.identity_column_sql('latest_tmp')
        if Array===identity
          identity_list = identity.map{|i| model.connection.quote(i)}*','
          where_condition = "WHERE #{identity_column} IN (#{identity_list})"
        else
          where_condition = "WHERE #{identity_column}=#{model.connection.quote(identity)}"
        end
      end
      model.where(
        %{(#{model.identity_column_sql}, #{model.effective_to_column_sql}) IN
          (SELECT #{model.identity_column_sql('latest_tmp')},
                  MAX(#{model.effective_to_column_sql('latest_tmp')}) AS latest_to
           FROM #{model.table_name} AS "latest_tmp"
           #{where_condition}
           GROUP BY #{model.identity_column_sql('latest_tmp')})
         }
      )
    }
    # Last superseded/terminated iterations
    # model.scope :last_ended, ->{model.where(%{#{model.effective_to_column_sql} = (SELECT max(#{model.effective_to_column_sql('max_to_tmp')}) FROM "#{model.table_name}" AS "max_to_tmp" WHERE #{model.effective_to_column_sql('max_to_tmp')}<#{END_OF_TIME})})}
    # last iterations of terminated identities
    # model.scope :terminated, ->{model.where(%{#{model.effective_to_column_sql}<#{END_OF_TIME} AND #{model.effective_to_column_sql}=(SELECT max(#{model.effective_to_column_sql('max_to_tmp')}) FROM "#{model.table_name}" AS "max_to_tmp")})}
    model.scope :terminated, ->(identity=nil){
      where_condition = identity && " WHERE #{model.identity_column_sql('max_to_tmp')}=#{model.connection.quote(identity)} "
      model.where(
        %{#{model.effective_to_column_sql}<#{END_OF_TIME}
          AND (#{model.identity_column_sql}, #{model.effective_to_column_sql}) IN
            (SELECT #{model.identity_column_sql('max_to_tmp')},
                    max(#{model.effective_to_column_sql('max_to_tmp')})
             FROM "#{model.table_name}" AS "max_to_tmp" #{where_condition})
         }
      )
    }
    # iterations superseded
    model.scope :superseded, ->(identity=nil){
      where_condition = identity && " AND #{model.identity_column_sql('max_to_tmp')}=#{model.connection.quote(identity)} "
      model.where(
        %{(#{model.identity_column_sql}, #{model.effective_to_column_sql}) IN
          (SELECT #{model.identity_column_sql('max_to_tmp')},
                  max(#{model.effective_to_column_sql('max_to_tmp')})
           FROM "#{model.table_name}" AS "max_to_tmp"
           WHERE #{model.effective_to_column_sql('max_to_tmp')}<#{END_OF_TIME})
                 #{where_condition}
                 AND EXISTS (SELECT * FROM "#{model.table_name}" AS "ex_from_tmp"
                             WHERE #{model.effective_from_column_sql('ex_from_tmp')}==#{model.effective_to_column_sql})
        }
      )
    }
    model.before_validation :compute_identity
    model.validates_uniqueness_of IDENTITY_COLUMN, :scope=>[START_COLUMN, END_COLUMN], :message=>"El periodo de vigencia no es válido"
    model.before_destroy :remove_this_iteration
  end

end
