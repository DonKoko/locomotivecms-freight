require 'active_support/core_ext/object/blank'
require 'ostruct'

module Locomotivecms
  module Freight

    module HtmlToMarkdown
      class << self
        def convert_to_markdown html
          html = convert_italics html
          html = convert_bold html
          html = convert_tables html
          html = convert_preformatted html
          html = convert_paragraphs html
          html = convert_headings html
          html = convert_images html
          html = convert_links html
          html
        end

        def convert_italics html
          html \
            .gsub(/<(i .*?>|i>|em.*?>)[\n\s]*/i, '_')
            .gsub(/[\n\s]*\<(\/i|\/em)[^\>]*\>/i, '_')
        end

        def convert_bold html
          html \
            .gsub(/\<(b .*?>|b>|strong.*?>)[\n\s]*/i, '**')
            .gsub(/[\n\s]*\<(\/b|\/strong)[^\>]*\>/i, '**')
        end

        def convert_preformatted html
          html.gsub(/<pre.*?>.*?<\/pre.*?>/m) do |pre|
            text = pre.match(/<pre.*?>(.*?)<\/pre.*?>/m)[1]
            text \
              .strip
              .split(/\n\n/m)
              .map do |para|
                para.split(/\n/).join("<br />\n")
              end \
              .join("\n\n")
              .chomp
          end.gsub(/\n\n\n/, "\n\n")
        end

        def convert_tables html
          html.gsub(/\s*<table.*?>.*?<\/table>/mi) do |table|
            markdown = "\n\n|"
            table.scan(/<tr.*?>.*?<\/tr>/mi) do |row|
              row.scan(/<td.*?>.*?<\/td>/mi) do |cell|
                markdown << cell.gsub(/^<td.*?>/mi, '').gsub(/<\/td>$/mi, '')
                markdown << "|"
              end
            end
            markdown << "\n"
          end
        end

        def convert_paragraphs html
          if html.match(/<\/?p\s?.*?>/)
            html = html.dup \
              .split(/[\s\n]*\<\/{0,1}p.*?\>[\s\n]*/i)
              .reject{|chunk| chunk.match /^[\s\n]*$/ }
              .join("\n\n")
              .chomp + "\n"
          end
          html
        end

        def convert_headings html
          html.gsub(/\<h\d.*?\>.*?\<\/h\d\>/mi) { |heading|
            match = heading.match /\<h(\d).*?\>(.*?)\<\/h\d\>/mi
            heading_prefix = "#" * match[1].to_i
            heading_text = match[2].gsub(/\n/, ' ').gsub(/^\s*/, '').gsub(/\s*$/, '')
            "#{heading_prefix} #{heading_text}"
          }
        end

        def convert_links html
          html = html.dup
          urls = []
          html.gsub!(/\<a.*?\>.*?\<\/a\>/mi) { |link|
            index = urls.length
            match = link.match /\<a.*href=["']?([^\s"']+)["']?.*\>(.*?)\<\/a\>/mi
            if match.nil?
              raise "No match for link: #{link}"
            end
            link_href = match[1]
            link_text = match[2]
            urls[index] = link_href
            "[#{link_text}][#{index + 1}]"
          }
          html << "\n"
          html << urls.each_with_index.map do |url, i|
            index = i + 1
            "[#{index}]: #{url}"
          end.join("\n")
          html << "\n"
        end

        def convert_images html
          html = html.dup
          images = {}
          html.gsub!(/<img.*?\/?>/mi) { |img|
            index = images.length
            src_match = img.match /<img.*?src=["']?([^\s"']+)["']?.*?\/?>/mi
            return img unless src_match.present?
            src = src_match[1]
            alt_match = img.match /<img.*?alt=["']([^"']+)["'].*?\/?>/mi
            alt = alt_match[1] if alt_match.present?
            title_match = img.match /<img.*?title=["']([^"']+)["'].*?\/?>/mi
            title = title_match[1] if title_match.present?
            if alt.blank?
              if title.present?
                alt = title
              else
                alt = src.gsub(/^.*\//,'').gsub(/\..*$/,'')
              end
            elsif title.blank?
              title = alt
            end
            title = title.present? ? " \"#{title}\"" : nil
            index = "img-#{(images.size + 1).to_s.rjust(2, '0')}"
            images[index] = OpenStruct.new({ url: src, title: title })
            "![#{alt}][#{index}]"
          }
          html << "\n"
          html << images.each_pair.map do |index, img|
            "[#{index}]: #{img.url}#{img.title}"
          end.join("\n")
          html << "\n"
        end
      end
    end

  end
end
