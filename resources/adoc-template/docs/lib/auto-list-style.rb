require 'asciidoctor/extensions'

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
