# Generated via
#  `rails generate hyrax:work General`
module Hyrax
  module Actors
    class GeneralActor < Hyrax::Actors::BaseActor

      protected

      def save(env)
        env.attributes.each do |k,v|
          next unless (k.ends_with? '_attributes') && (!env.curation_concern.attributes[k.gsub('_attributes', '')].nil?)
          env.curation_concern.attributes[k.gsub('_attributes', '')].each do |person|
            person.persist!
          end
        end
        super
      end
    end
  end
end
