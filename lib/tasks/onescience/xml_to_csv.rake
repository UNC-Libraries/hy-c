namespace :onescience do
  desc 'convert xml from scopus to csv'
  task :xml_to_csv, [:xml_file] => :environment do |t, args|
    # parse xml
    scopus_xml = Nokogiri::XML(File.open(args[:xml_file]))
    puts scopus_xml.xpath('//affiliation[not(@*)]').count
    puts scopus_xml.xpath('//organization[@type="array"]').count

    output_file = File.new('tmp/affilname_file15.csv', 'a+')
    File.open(output_file, 'a+') do |f|
      f.puts 'affiliation_id,department_id,organizations'
      scopus_xml.xpath('//affiliation[not(@*)]').each_with_index do |affiliation, index|
        organization = affiliation.xpath('organization').map(&:text).first
        affiliation_id = affiliation.xpath('afid').text
        department_id = affiliation.xpath('dptid').text
        if !organization.blank? && (!affiliation_id.blank? || !department_id.blank?)
          f.puts "#{affiliation_id},#{department_id},#{organization.strip.split("\n").map(&:strip).join("; ")}"
        end
      end
    end
  end
end
