require 'parser/current'
require 'astrolabe/builder'
require 'rails5/spec_converter/text_transformer_options'
require 'rails5/spec_converter/hash_node_text_analyzer'
require 'rails5/spec_converter/hash_rewriter'

module Rails5
  module SpecConverter
    HTTP_VERBS = %i(get post put patch delete)

    class TextTransformer
      def initialize(content, options = TextTransformerOptions.new)
        @options = options
        @content = content

        @source_buffer = Parser::Source::Buffer.new('(string)')
        @source_buffer.source = @content

        ast_builder = Astrolabe::Builder.new
        @parser = Parser::CurrentRuby.new(ast_builder)

        @source_rewriter = Parser::Source::Rewriter.new(@source_buffer)
      end

      def transform
        root_node = @parser.parse(@source_buffer)
        root_node.each_node(:send) do |node|
          target, verb, action, *args = node.children
          next unless args.length > 0
          next unless target.nil? && HTTP_VERBS.include?(verb)

          if args[0].hash_type?
            if args[0].children.length == 0
              wrap_arg(args[0], 'params')
            else
              next if looks_like_route_definition?(args[0])
              next if has_key?(args[0], :params)
              if has_kwsplat?(args[0])
                warn_about_ambiguous_params(node) if @options.warn_about_ambiguous_params?
                next unless @options.wrap_ambiguous_params?
              end

              hash_rewriter = HashRewriter.new(
                content: @content,
                options: @options,
                hash_node: args[0],
                original_indent: node.loc.expression.source_line.match(/^(\s*)/)[1]
              )

              @source_rewriter.replace(
                args[0].loc.expression,
                hash_rewriter.rewritten_params_hash
              ) if hash_rewriter.should_rewrite_hash?
            end
          else
            warn_about_ambiguous_params(node) if @options.warn_about_ambiguous_params?
            wrap_arg(args[0], 'params') if @options.wrap_ambiguous_params?
          end

          wrap_arg(args[1], 'headers') if args[1]
        end

        @source_rewriter.process
      end

      private

      def looks_like_route_definition?(hash_node)
        keys = hash_node.children.map { |pair| pair.children[0].children[0] }
        route_definition_keys = [:to, :controller]
        return true if route_definition_keys.all? { |k| keys.include?(k) }

        hash_node.children.each do |pair|
          key = pair.children[0].children[0]
          if key == :to
            if pair.children[1].str_type?
              value = pair.children[1].children[0]
              return true if value.match(/^\w+#\w+$/)
            end
          end
        end

        false
      end

      def has_kwsplat?(hash_node)
        hash_node.children.any? { |node| node.kwsplat_type? }
      end

      def has_key?(hash_node, key)
        hash_node.children.any? { |pair| pair.children[0].children[0] == key }
      end

      def wrap_arg(node, key)
        node_loc = node.loc.expression
        node_source = node_loc.source
        if node.hash_type? && !node_source.match(/^\s*\{.*\}$/m)
          node_source = "{ #{node_source} }"
        end
        @source_rewriter.replace(node_loc, "#{key}: #{node_source}")
      end

      def warn_about_ambiguous_params(node)
        log "Ambiguous params found"
        log "#{@options.file_path}:#{node.loc.line}" if @options.file_path
        log "```\n#{node.loc.expression.source}\n```\n\n"
      end

      def log(str)
        return if @options.quiet?

        puts str
      end
    end
  end
end
