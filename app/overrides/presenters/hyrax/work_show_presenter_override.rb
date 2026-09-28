# frozen_string_literal: true
# [hyc-override] Overriding helper in order to add doi to citation
# https://github.com/samvera/hyrax/blob/hyrax-v5.3.0/app/presenters/hyrax/work_show_presenter.rb
# Clover overrides https://github.com/samvera/hyrax/blob/main/app/presenters/hyrax/work_show_presenter.rb
Hyrax::WorkShowPresenter.class_eval do

  # [hyc-override] Add default scholarly? method
  # Indicates if the work is considered scholarly according to google scholar
  # This method is not defined in hyrax, but it is referenced by GoogleScholarPresenter
  def scholarly?
    false
  end

  # [hyc-override] Set the default IIIF viewer to Clover
  def iiif_viewer
    :clover
  end

  # @todo the following methods have been addd/updated on the main hyrax branch, but are not yet in a hyrax release.
  # Once hyrax is updated, these methods can probably be removed.

  def iiif_viewer?
    return @iiif_viewer if defined?(@iiif_viewer)
    @iiif_viewer = representative_viewable? || child_works_viewable?
  end
  alias universal_viewer? iiif_viewer?

  def iiif_viewer?(seen: Set.new)
    return @iiif_viewer if defined?(@iiif_viewer)
    @iiif_viewer = (representative_id.present? &&
      representative_presenter.present? &&
      (av_viewable? || image_viewable? || pdf_viewable?)) ||
                   child_works_viewable?(seen)
  end

  def representative_viewable?
    representative_id.present? &&
      representative_presenter.present? &&
      (av_viewable? || image_viewable? || pdf_viewable?)
  end

  def child_works_viewable?(seen)
    work_presenters.any? do |presenter|
      next unless seen.add?(presenter.id)
      presenter.iiif_viewer?(seen: seen)
    end
  end
end
