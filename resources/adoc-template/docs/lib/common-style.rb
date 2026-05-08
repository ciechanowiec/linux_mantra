require 'asciidoctor/extensions'
require 'asciidoctor-pdf'

Asciidoctor::Extensions.register do
  treeprocessor do
    process do |document|
      styles = ['upperalpha', 'upperroman', 'lowergreek', 'lowerroman']
      walk = lambda do |node, depth|
        node.blocks.each do |block|
          if block.context == :olist
            block.style = styles[depth] || styles.last
            block.set_attr('style', styles[depth] || styles.last)
            walk.call(block, depth + 1)
          else
            walk.call(block, depth) if block.respond_to?(:blocks)
          end
        end
      end
      walk.call(document, 0)
      nil
    end
  end
end

module ExampleBlockRoleColors
  ROLE_COLORS = {
    'bad-example'  => { background: 'FDECEA', border: 'D9534F' },
    'good-example' => { background: 'E6F4EA', border: '28A745' },
  }.freeze

  def convert_example node
    role = (node.roles || []).find { |r| ROLE_COLORS.key? r }
    return super unless role

    if role == 'bad-example' && (parent = node.parent) && parent.respond_to?(:blocks)
      idx = parent.blocks.index node
      if idx && idx > 0
        prev = parent.blocks[idx - 1]
        if prev.context == :example && (prev.roles || []).include?('good-example')
          move_down((@theme.vertical_rhythm || 12).to_f)
        end
      end
    end

    colors = ROLE_COLORS[role]
    saved = {
      bg: @theme.example_background_color,
      bc: @theme.example_border_color,
      bw: @theme.example_border_width,
    }
    @theme.example_background_color = colors[:background]
    @theme.example_border_color = colors[:border]
    @theme.example_border_width = saved[:bw] || 0.75
    begin
      super
    ensure
      @theme.example_background_color = saved[:bg]
      @theme.example_border_color = saved[:bc]
      @theme.example_border_width = saved[:bw]
    end
  end
end

Asciidoctor::PDF::Converter.prepend ExampleBlockRoleColors
