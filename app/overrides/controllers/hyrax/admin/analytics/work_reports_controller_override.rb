Hyrax::Admin::Analytics::WorkReportsController.class_eval do
    private
        def accessible_works
          models = Hyrax.config.curation_concerns.map { |m| "\"#{m}\"" }
          if current_user.ability.admin?
            ActiveFedora::SolrService.query("has_model_ssim:(#{models.join(' OR ')})",
              fl: 'title_tesim, id, member_of_collections',
              rows: 50_000)
          else
             ActiveFedora::SolrService.query(
              "edit_access_person_ssim:#{current_user} AND has_model_ssim:(#{models.join(' OR ')})",
              fl: 'title_tesim, id, member_of_collections',
              rows: 50_000
            )
          end
        end
end