# frozen_string_literal: true
# [hyc-override] Overriding to allow updated content jobs to run immediately so file reference isn't lost
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/actors/hyrax/actors/base_actor.rb
Hyrax::Actors::BaseActor.class_eval do
  alias_method :original_update, :update
  def update(env)
    # [hyc-override] Log deleted people objects
    original_update(env) && log_deleted_people_objects(env.attributes, env.curation_concern.id)
  end

  private
  alias_method :original_save, :save
  def save(env, use_valkyrie: false)
    # [hyc-override] Save updated nested objects individually; they will not be updated with the rest of the attributes
    env.attributes.each do |k, _v|
      next unless (k.ends_with? '_attributes') && (!env.curation_concern.attributes[k.gsub('_attributes', '')].nil?)

      env.curation_concern.attributes[k.gsub('_attributes', '')].each do |person|
        person.persist!
      end
    end
    original_save(env, use_valkyrie: use_valkyrie)
  end

  # Cast any singular values from the form to multiple values for persistence
  # also remove any blank assertions
  # TODO this method could move to the work form.
  def clean_attributes(attributes)
    attributes[:license] = Array(attributes[:license]) if attributes.key? :license
    # [hyc-override] Overriding actor to cast rights statements as single valued
    # removed rights_statement-specific line of code so that it could be cast in `remove_blank_attributes!`
    # [hyc-override] remove index field if for some reason is added to permissions_attributes hashes
    unless attributes['permissions_attributes'].blank?
      permission_attrs = {}
      attributes['permissions_attributes'].each do |k, v|
        permission_attrs[k] = if !v['index'].blank?
                                v.except('index')
                              else
                                v
                              end
        if v['name']&.include?('@')
          permission_attrs[k]['name'] = ::User.find_by(email: v['name']).uid
          Rails.logger.debug("BaseActor.clean_attributes removed email suffix, new id is #{permission_attrs[k]['name']}")
        end
      end
      # Rails.logger.error("===clean_attributes Setting perms #{permission_attrs}")
      attributes['permissions_attributes'] = permission_attrs
    end
    remove_blank_attributes!(attributes).except('file_set')
  end

  def log_deleted_people_objects(attributes, work_id)
    attributes.each do |attr, set|
      if set.present? && attr.match(/_attributes/)
        set.each do |_k, v|
          if v['_destroy']
            File.open(ENV['DELETED_PEOPLE_FILE'], 'a+') do |file|
              file.puts work_id
            end
          end
        end
      end
    end
    true
  end
end
