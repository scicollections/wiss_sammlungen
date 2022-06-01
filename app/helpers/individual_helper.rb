module IndividualHelper
  def url_for_individual indi
    [request.base_url, indi.type, indi.id].join('/')
  end

  # Chooses the correct template to render depending on
  # the individual's class. For a class name to be mapped to a specific template
  # it should live in app/views/individual/ and be named like the lowercased
  # class name. If no such template is found, a default template is used.
  #
  # @example
  #   # in ERB view
  #   <%= render_individual @record %>
  #
  def render_individual individual
    begin
      render individual.class.to_s.downcase
    rescue ActionView::MissingTemplate
      render "fallback_view"
    end
  end
  
  def render_internal_tab individual
    begin
      render "individual/internal_tab/"+individual.class.to_s.downcase
    rescue ActionView::MissingTemplate
      return nil
    end
  end

  EXTERNAL_LINK_ICON = <<-HTML.strip.html_safe
    <span class="linker glyphicon glyphicon-new-window"
          data-toggle="tooltip"
          data-placement="top"
          data-title="Link in neuem Fenster öffnen"></span>
  HTML

  # Format the value of text properties.
  #
  # - Ersetzt "\n" mit "<br>" und "\n\n" mit "<p>"
  # - Erkennt Links
  def format_text str
    html = simple_format(str)
    auto_link(html, html: { target: :_blank }) do |url|
      url + EXTERNAL_LINK_ICON
    end
  end

  def external_link url, text=url
    link_to(h(text) + EXTERNAL_LINK_ICON, url, target: :_blank)
  end
end
