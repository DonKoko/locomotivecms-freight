require 'active_support/core_ext/object/blank'
require 'ostruct'
require 'squares'
require 'locomotivecms/freight/post'
require 'locomotivecms/freight/html_to_markdown'

module Locomotivecms
  module Freight

    class WordpressImporter
      attr_reader :client

      SOURCE='WordPress Importer'

      def initialize(client)
        @client = client
      end

      def all_links input_file
        parse_all_posts(input_file).map do |item|
          body = item.xpath('content:encoded').text
          body.scan(/<a .*?<\/a>/mi).map{|link| link.strip }
        end.flatten
      end

      def all_images input_file
        parse_all_posts(input_file).map do |item|
          body = item.xpath('content:encoded').text
          body.scan(/<img.*?>/mi).map{|img| img.strip }
        end.flatten
      end

      def all_tables input_file
        parse_all_posts(input_file).map do |item|
          body = item.xpath('content:encoded').text
          body.scan(/<table.*?<\/table>/i).map{|table| table.strip }
        end.flatten
      end

      def all_imported_posts filter={ source: SOURCE }
        [].tap do |all_posts|
          page = 1
          while page do
            posts = client.contents.posts.all(filter, page: page)
            all_posts << posts
            page = posts._next_page
          end
        end.flatten
      end

      def all_comments filter={}
        [].tap do |all_comments|
          page = 1
          while page do
            comments = client.contents.comments.all(filter, page: page)
            all_comments << comments
            page = comments._next_page
          end
        end.flatten
      end

      def import import_file, format=html
        metrics = OpenStruct.new posts: 0, comments: 0
        parse_all_posts(import_file).each do |item|

          post = post_for item
          puts "creating post [[ #{post.title} ]]"
          p = client.contents.posts.create post.cms_params
          post._id = p._id
          post.save
          metrics.posts += 1

          comments = comments_for item, post
          unless comments.empty?
            puts "  -- creating #{comments.count} comments..."
            comments.each do |comment|
              client.contents.comments.create comment
              metrics.comments += 1
            end
          end
        end
        puts "Imported #{metrics.posts} posts and #{metrics.comments} comments."
      end

      def rewrite_internal_urls
        return unless Post.any?
        metrics = OpenStruct.new links: 0

        Post.each do |post|
          needs_update = false
          post.links.each do |link|
            if linked_post = Post[link]
              metrics.links += 1
              puts "[ #{post.title} ]: rewriting \"#{link}\" -> \"/posts/#{linked_post._slug}\""
              post.body.gsub! /#{link}/, "/posts/#{linked_post._slug}"
              post.save
              needs_update = true
            end
          end
          client.contents.posts.update(post._id, { body: post.body }) if needs_update
        end

        puts "Rewrote #{metrics.links} links in #{Post.count} posts."
      end

      def rewrite_images
        return unless Post.any?
        metrics = OpenStruct.new images: 0

        # ensure /public/images/posts exists

        Post.each do |post|
          needs_update = false
          default_host = post.id.gsub(/^(https?:\/\/[^\/]*).*$/, '\1')

          post.image_urls.each do |image_url|
            original_image_url = image_url.dup
            image_url = "#{default_host}#{image_url}" if image_url.match(/^\//)
            unless (File.directory?('public/images/posts'))
              Dir.mkdir('public/images/posts')
            end

            image_file_name = image_url.gsub(/^.*\//, '')
            puts <<-TEXT.strip_heredoc

              image_url: #{image_url}
              image_file_name: #{image_file_name}
              ================================================================================
            TEXT
            curl = `curl #{image_url} > public/images/posts/#{image_file_name}`
            puts curl
            if curl.match /<url> malformed/m
              raise <<-ERROR.strip_heredoc
                Problem downloading image "#{image_url}"
                image_file_name: #{image_file_name}
                post.body:

                #{post.body}

              ERROR
            end
            metrics.images += 1

            post.body.gsub! /#{original_image_url}/, "/sites/#{site_id}/theme/images/posts/#{image_file_name}"
            post.save
            needs_update = true
          end
          client.contents.posts.update(post._id, { body: post.body }) if needs_update
        end

        puts "Rewrote #{metrics.images} images in #{Post.count} posts."
        puts "Don't forget to `bundle exec wagon push ENV -r theme_assets`"
      end

      def clean!
        remove_posts
      end

      def remove_non_visible_posts!
        remove_posts _visible: false
      end

      def destroy thing
        content_type = thing.content_type_slug.to_sym
        contents_action content_type, :destroy, thing._id
      end

      def create content_type, params
        contents_action content_type.to_sym, :create, params
      end

      private

      def contents_action content_type, action, params
        client.contents.send(content_type).send(action, params)
      end

      def parse_xml input_file
        File.open(input_file) { |fh| Nokogiri::XML(fh) }
      end

      def parse_all_posts import_file
        parse_xml(import_file).xpath('//item').select do |item|
          item.xpath('wp:post_type').text == 'post' && filtered?(item)
        end
      end

      def filtered? item
        !ENV['NAME'] || item.xpath('wp:post_name').text == ENV['NAME']
      end

      def remove_posts filter={ source: SOURCE }
        metrics = OpenStruct.new posts: 0, comments: 0
        posts = all_imported_posts filter
        puts "Preparing to delete #{posts.count} posts..."
        posts.each do |post|
          puts "removing [[ #{post.title} ]]"
          destroy post
          metrics.posts += 1
          post_comments = all_comments post: post._id
          if post_comments.count > 0
            puts "  -- also removing #{post_comments.count} comments..."
            post_comments.each do |comment|
              destroy comment
              metrics.comments += 1
            end
          end
        end
        puts "Removed #{metrics.posts} posts and #{metrics.comments} comments."
      end

      def post_for item
        post = Post.new item.xpath('link').text,
          title:     resolve_post_title(item),
          keywords:  item.xpath('category').text,
          posted_at: item.xpath('pubDate').text,
          body:      HtmlToMarkdown.convert_to_markdown(item.xpath('content:encoded').text),
          teaser:    item.xpath('excerpt:encoded').text,
          wp_id:     item.xpath('wp:post_id').text,
          source:    SOURCE
        post.tap do |post|
          if post.teaser.nil? || post.teaser == ""
            post[:teaser] = post[:body].gsub(/\<.*?\>/, '')[0..300] + '...'
          end
          post.save
        end
      end

      def comments_for item, post
        item.xpath('wp:comment').map do |comment|
          {
            name:         comment.xpath('wp:comment_author').text,
            email:        comment.xpath('wp:comment_author_email').text,
            url:          comment.xpath('wp:comment_author_url').text,
            commented_at: comment.xpath('wp:comment_date').text,
            content:      comment.xpath('wp:comment_content').text,
            post:         post._id
          }.tap do |comment|
            if comment[:email].nil? || comment[:email] == ''
              comment[:email] = "n/a (#{comment[:name]})"
            end
          end
        end
      end

      def resolve_post_title item
        title = item.xpath('title').text
        title = item.xpath('wp:post_name').text if title.blank?
        title = item.xpath('wp:post_id').text if title.blank?
        title
      end

      def site_id
        @handle ||= @client.options['handle']
        @site_id ||= @client.sites.all.select{ |site| site.handle == @handle }.first._id
      end

    end

  end
end
