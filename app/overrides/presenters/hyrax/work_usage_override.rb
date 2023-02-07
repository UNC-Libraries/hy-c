Hyrax::WorkUsage.class_eval do
  def total_downloads
    downloads.reduce(0) { |total, result| total + result[1].to_i }
  end

  # Package data for visualization using JQuery Flot
  def to_flot
    [
      { label: "Pageviews",  data: pageviews },
      { label: "Downloads",  data: downloads }
    ]
  end

  private

  def downloads
    to_flots(FileDownloadStat.statistics(model, created, user_id))
  end
end