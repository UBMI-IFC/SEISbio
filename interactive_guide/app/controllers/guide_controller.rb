class GuideController < ApplicationController
  def index
    @sections = guide_sections.map do |section|
      section.merge(content: load_markdown(section.fetch(:file)))
    end
  end

  private

  def guide_sections
    [
      { id: "overview", title: "Panorama", file: "00_overview.md" },
      { id: "miniforge", title: "Miniforge", file: "01_miniforge.md" },
      { id: "buscar", title: "Buscar e instalar", file: "02_buscar_instalar.md" },
      { id: "ambientes", title: "Ambientes", file: "03_ambientes.md" },
      { id: "seisbio", title: "SEISbio", file: "04_seisbio.md" },
      { id: "uninstall", title: "Desinstalar", file: "05_uninstall.md" },
      { id: "recomendados", title: "Flujos recomendados", file: "06_recomendados.md" }
    ]
  end

  def load_markdown(filename)
    path = Rails.root.join("app", "content", "guide", filename)
    File.read(path, encoding: "UTF-8")
  end
end
