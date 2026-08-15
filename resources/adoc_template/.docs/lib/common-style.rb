require 'asciidoctor/extensions'
require 'asciidoctor-pdf'

Asciidoctor::Extensions.register do
  treeprocessor do
    process do |document|
      styles = ['upperalpha', 'upperroman', 'lowergreek', 'lowerroman']
      walk = lambda do |node, depth|
        node.blocks.each do |block|
          # A dlist's blocks are [terms, description] Array pairs, not nodes.
          next unless block.respond_to?(:context)
          # Shrink each wide verbatim block (diagram or code) just enough to
          # fit the page width. A block whose longest line would fall below the
          # theme's minimum font size anyway -- a prose-like prompt line -- is
          # left alone, so it keeps its normal size and wraps instead.
          if [:literal, :listing].include?(block.context)
            longest = Array(block.lines).map(&:length).max.to_i
            block.set_attr('autofit-option', '') if longest.between?(1, 125)
          end
          # A table cell takes its alignment from the cell's `halign`
          # attribute, and AsciiDoc's column spec can only set that to left,
          # center, or right -- there is no justify operator. The body prose
          # is justified (the theme's `base text_align`), so a prose cell
          # would read ragged beside it. Prawn accepts :justify, so promote
          # the default left alignment on body and footer cells, leaving a
          # cell the author aligned right or centre untouched. A header
          # column (`h` in the column spec) holds labels, not prose, so it
          # keeps its left alignment: justifying a label that wraps spreads
          # its words across the column.
          if block.context == :table
            (block.rows.body + block.rows.foot).each do |row|
              row.each do |cell|
                next if cell.style == :header
                next unless (cell.attr 'halign') == 'left'
                cell.set_attr 'halign', 'justify'
              end
            end
          end
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

# A bibliography entry's metadata block (`[horizontal.source-fields]`) is a
# machine-facing record: it renders small and muted so it recedes behind the
# prose, and its monospaced values (paths, digests) take the same muted color
# instead of the code accent. The stock horizontal-dlist table carries row
# spacing this block can't tune away, so the rows are drawn directly: term
# floated left in a fixed column, value indented beside it, a hair of space
# between rows. The sizes and colors live in the theme under `source_fields`.
# Any incompatibility with a future asciidoctor-pdf falls back to the stock
# renderer instead of failing the export.
module SourceFieldsRole
  TERM_COLUMN_WIDTH = 68
  TERM_GUTTER = 8
  ROW_GAP = 1.5

  def convert_dlist node
    return super unless (node.roles || []).include? 'source-fields'
    # Inline code colors are compiled into the text formatter's Transform at
    # converter startup, so a theme override mid-render has no effect; the
    # compiled setting itself is swapped for the duration of the block.
    code_settings = text_formatter.instance_variable_get(:@transform)
      &.instance_variable_get(:@theme_settings)&.dig(:code)
    saved_code = code_settings && code_settings[:color]
    muted = @theme.source_fields_font_color
    code_settings[:color] = muted if code_settings && muted
    begin
      # The DOCX export sets a symmetric 6pt gap above and below the record;
      # match it here: halve the inherited top margin, close with 6pt.
      move_up 6 unless at_page_top?
      theme_font :source_fields do
        line_height = @theme.source_fields_line_height || 1.2
        node.items.each do |terms, desc|
          term_text = terms.map(&:text).join ' '
          desc_text = desc && desc.text? ? desc.text : ''
          advance_page if !at_page_top? && cursor < 16
          float do
            bounding_box [0, cursor], width: TERM_COLUMN_WIDTH do
              theme_font :description_list_term do
                ink_prose term_text, margin_bottom: 0,
                          line_height: line_height
              end
            end
          end
          indent TERM_COLUMN_WIDTH + TERM_GUTTER do
            ink_prose desc_text, margin_bottom: ROW_GAP,
                      line_height: line_height
          end
        end
      end
      move_down 6
    rescue StandardError
      super
    ensure
      code_settings[:color] = saved_code if code_settings
    end
  end
end

Asciidoctor::PDF::Converter.prepend SourceFieldsRole
