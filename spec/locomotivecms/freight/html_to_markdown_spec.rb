require 'spec_helper'
require 'locomotivecms/freight/html_to_markdown'

module Locomotivecms
  module Freight

    describe HtmlToMarkdown do
      subject { HtmlToMarkdown }

      describe '#convert_italics' do
        Given(:html) { 'Content with STUFF in it' }
        Given(:expected) { 'Content with _italics_ in it' }
        When(:result) { subject.convert_italics html }

        context '<i>' do
          Given { html.gsub! /STUFF/, "<i>italics</i>" }
          Then { expect(result).to eq(expected) }
        end
        context '<i class="foo">' do
          Given { html.gsub! /STUFF/, '<i class="foo">italics</i>' }
          Then { expect(result).to eq(expected) }
        end
        context '<i>\n...\n</i>' do
          Given { html.gsub! /STUFF/, "<i>\n italics\n </i>" }
          Then { expect(result).to eq(expected) }
        end
        context '<em>' do
          Given { html.gsub! /STUFF/, '<em>italics</em>' }
          Then { expect(result).to eq(expected) }
        end
        context '<I>' do
          Given { html.gsub! /STUFF/, "<I>italics</I>" }
          Then { expect(result).to eq(expected) }
        end
        context "don't mess with images" do
          Given { html.gsub! /STUFF/, '<img src="foo" />' }
          Then { expect(result).to eq('Content with <img src="foo" /> in it') }
        end
      end

      describe '#convert_bold' do
        Given(:html) { 'Content with STUFF in it' }
        Given(:expected) { 'Content with **bold** in it' }
        When(:result) { subject.convert_bold html }

        context '<b>' do
          Given { html.gsub! /STUFF/, "<b>bold</b>" }
          Then { expect(result).to eq(expected) }
        end
        context '<b class="foo">' do
          Given { html.gsub! /STUFF/, '<b class="foo">bold</b>' }
          Then { expect(result).to eq(expected) }
        end
        context '<b>\n...\n</b>' do
          Given { html.gsub! /STUFF/, "<b>\n bold\n </b>" }
          Then { expect(result).to eq(expected) }
        end
        context '<strong>' do
          Given { html.gsub! /STUFF/, '<strong>bold</strong>' }
          Then { expect(result).to eq(expected) }
        end
        context '<B>' do
          Given { html.gsub! /STUFF/, "<B>bold</B>" }
          Then { expect(result).to eq(expected) }
        end
        context "don't mess with <br />" do
          Given { html.gsub! /STUFF/, "<br />" }
          Then { expect(result).to eq('Content with <br /> in it') }
        end
        context "don't mess with <br>" do
          Given { html.gsub! /STUFF/, "<br>" }
          Then { expect(result).to eq('Content with <br> in it') }
        end
      end

      describe '#convert_headings' do
        Given(:html) do
          <<-HTML.strip_heredoc
          Some stuff.

          HEADING

          More stuff.
          HTML
        end
        When(:result) { subject.convert_headings html }

        context 'h1' do
          Given { html.gsub! /HEADING/, "<h1>Heading</h1>" }
          Then { expect(result).to match("\n# Heading\n") }
        end
        context 'h2' do
          Given { html.gsub! /HEADING/, "<h2>Heading</h2>" }
          Then { expect(result).to match("\n## Heading\n") }
        end
        context 'h3 with newlines' do
          Given { html.gsub! /HEADING/, "<h3>\n  Heading\n</h3>" }
          Then { expect(result).to match("\n### Heading\n") }
        end
      end

      describe '#convert_tables' do
        Given(:html) do
          <<-HTML.strip_heredoc
          before
          <table class="foo" border="1" cellpadding=0>
            <tr>
              <td>some content</td>
              <td>more content</td>
            </tr>
          </table>
          after
          HTML
        end
        Given(:expected) { "before\n\n|some content|more content|\n\nafter\n" }
        When(:result) { subject.convert_tables html }
        context 'without surrounding whitespace' do
          Then { expect(result).to eq(expected) }
        end
        context 'with surrounding whitespace' do
          Given do
            html.gsub(/before/, "before\n\n")
            html.gsub(/after/, "\nafter")
          end
          Then { expect(result).to eq(expected) }
        end
      end

      describe '#convert_paragraphs' do
        Given(:expected) do
          <<-MARKDOWN.strip_heredoc
          As we all know, the rain in span
          falls mainly on the plain.

          But let sleeping dogs lie!
          MARKDOWN
        end
        When(:result) { subject.convert_paragraphs html }

        context 'without closing tag' do
          Given(:html) do
            <<-HTML.strip_heredoc
            <p>
            As we all know, the rain in span
            falls mainly on the plain.

            <p>
            But let sleeping dogs lie!
            HTML
          end
          Then { expect(result).to eq(expected) }
        end
        context 'with closing tag' do
          Given(:html) do
            <<-HTML.strip_heredoc
            <p>
            As we all know, the rain in span
            falls mainly on the plain.
            </p>

            <p>
            But let sleeping dogs lie!
            </p>
            HTML
          end
          Then { expect(result).to eq(expected) }
        end
        context 'already in markdown' do
          Given(:html) do

            <<-MARKDOWN.strip_heredoc
            As we all know, the rain in span
            falls mainly on the plain.

            But let sleeping dogs lie!
            MARKDOWN
          end
          Then { expect(result).to eq(expected) }
        end
      end

      describe '#convert_links' do
        Given(:html) do
          <<-HTML.strip_heredoc
          Here is content with LINK in it.
          HTML
        end
        When(:result) { subject.convert_links html }

        context 'href' do
          Given(:expected) do
            <<-MARKDOWN.strip_heredoc
            Here is content with [a link][1] in it.

            [1]: /foo/bar
            MARKDOWN
          end

          context 'in double quotes' do
            Given { html.gsub! /LINK/, '<a href="/foo/bar">a link</a>' }
            Then { expect(result).to eq(expected) }
          end

          context 'in single quotes' do
            Given { html.gsub! /LINK/, "<a href='/foo/bar'>a link</a>" }
            Then { expect(result).to eq(expected) }
          end

          context 'with no quotes' do
            Given { html.gsub! /LINK/, "<a href=/foo/bar>a link</a>" }
            Then { expect(result).to eq(expected) }
          end
        end
      end

      describe '#convert_images' do
        Given(:html) do
          <<-HTML.strip_heredoc
          IMAGE
          Here is a caption
          HTML
        end
        When(:result) { subject.convert_images html }

        context 'with alt but no title' do
          Given(:expected) do
            <<-MARKDOWN.strip_heredoc
            ![alt text][img-01]
            Here is a caption

            [img-01]: /foo.jpg "alt text"
            MARKDOWN
          end
          context 'with double quotes' do
            Given { html.gsub! /IMAGE/, '<img src="/foo.jpg" alt="alt text" />' }
            Then { expect(result).to eq(expected) }
          end
          context 'with single quotes' do
            Given { html.gsub! /IMAGE/, "<img src='/foo.jpg' alt='alt text' />" }
          end
        end

        context 'with alt and title' do
          Given(:expected) do
            <<-MARKDOWN.strip_heredoc
            ![alt text][img-01]
            Here is a caption

            [img-01]: /foo.jpg "title text"
            MARKDOWN
          end

          Given { html.gsub! /IMAGE/, '<img src="/foo.jpg" alt="alt text" title="title text" />' }
          Then { expect(result).to eq(expected) }
        end

        context 'without alt but with title' do
          Given(:expected) do
            <<-MARKDOWN.strip_heredoc
            ![title text][img-01]
            Here is a caption

            [img-01]: /foo.jpg "title text"
            MARKDOWN
          end
          Given { html.gsub! /IMAGE/, '<img src="/foo.jpg" title="title text" />' }
          Then { expect(result).to eq(expected) }
        end

        context 'with neither alt nor title' do
          Given(:expected) do
            <<-MARKDOWN.strip_heredoc
            ![foo][img-01]
            Here is a caption

            [img-01]: /foo.jpg
            MARKDOWN
          end
          Given { html.gsub! /IMAGE/, '<img src="/foo.jpg" />' }
          Then { expect(result).to eq(expected) }
        end
      end

      describe '#convert_preformatted' do
        Given(:html) do
          <<-HTML.strip_heredoc
          Here is a poem:

          POEM

          And that was a poem.
          HTML
        end
        Given(:poem) do
          <<-POEM.strip_heredoc
          Roses are red,
          Violets are blue,
          You're gonna need kleenex;
          I'll loan you a few.
          POEM
        end
        Given(:expected) do
          <<-MARKDOWN.strip_heredoc
          Here is a poem:

          Roses are red,<br />
          Violets are blue,<br />
          You're gonna need kleenex;<br />
          I'll loan you a few.

          And that was a poem.
          MARKDOWN
        end
        When(:result) { subject.convert_preformatted html }
        context '<pre> on a separate line' do
          Given { html.gsub! /POEM/, "<pre>\n#{poem}</pre>" }
          Then { expect(result).to eq(expected) }
        end
        context '<pre> inline with another line' do
          Given do
            poem.gsub! /Roses/, "<pre>Roses"
            poem.gsub! /a few\./, "a few.</pre>"
            html.gsub! /POEM/, poem
          end
          Then { expect(result).to eq(expected) }
        end
      end

    end

  end
end
