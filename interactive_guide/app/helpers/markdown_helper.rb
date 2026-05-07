module MarkdownHelper
  ALLOWED_TAGS = %w[
    a
    blockquote
    br
    code
    em
    h1
    h2
    h3
    h4
    hr
    li
    ol
    p
    pre
    strong
    ul
  ].freeze
  ALLOWED_ATTRIBUTES = %w[href].freeze

  def render_markdown(markdown)
    html = Kramdown::Document.new(markdown, input: "kramdown").to_html
    sanitize(html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
  end
end
