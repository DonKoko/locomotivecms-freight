module Locomotivecms
  module Freight

    class Post < Squares::Base
      IMPORTABLE_PROPERTIES = [
        :title, :keywords, :posted_at, :body, :teaser, :source, :_visible
      ]
      properties :title, :keywords, :posted_at, :body, :teaser, :source,
        :wp_id
      property :_visible, default: true
      property :_id
      property :_slug
      property :xml

      def links
        body.scan(/^\[\d+\]\:.*$/).map do |link|
          link.chomp.gsub(/^\[.*?\]:\s?/, '')
        end
      end

      def image_urls
        body.scan(/^\[img-\d+\]:.*$/).map do |img_url|
          img_url.chomp.gsub(/^\[img-\d+\]:\s?/, '').gsub(/\s".*$/, '')
        end
      end

      def cms_params
        IMPORTABLE_PROPERTIES.reduce({}) do |params, property|
          params.tap do |p|
            p[property] = self.send property
          end
        end
      end
    end

  end
end
