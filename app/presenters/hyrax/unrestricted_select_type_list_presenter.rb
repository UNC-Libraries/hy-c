module Hyrax
  class UnrestrictedSelectTypeListPresenter < Hyrax::SelectTypeListPresenter
    def authorized_models
      Rails.logger.info 'Getting unrestricted models'
      @authorized_models ||= Hyrax::UnrestrictedClassificationQuery.new(@current_user).authorized_models
    end
  end
end
