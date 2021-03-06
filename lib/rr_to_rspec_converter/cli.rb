require 'optparse'
require 'rr_to_rspec_converter/text_transformer'
require 'rr_to_rspec_converter/text_transformer_options'
require 'rr_to_rspec_converter/version'

module RrToRspecConverter
  class CLI
    def initialize
      @options = RrToRspecConverter::TextTransformerOptions.new
      OptionParser.new do |opts|
        opts.banner = "Usage: rr-to-rspec-converter [options] [files]"

        opts.on("--version", "Print version number") do |q|
          puts RrToRspecConverter::VERSION
          exit
        end

        opts.on("-q", "--quiet", "Run quietly") do |q|
          @options.quiet = q
        end
      end.parse!

      @files = ARGV
    end

    def run
      paths = @files.length > 0 ? @files : ["spec/**/*.rb", "test/**/*.rb"]

      paths.each do |path|
        Dir.glob(path) do |file_path|
          log "Processing: #{file_path}"

          original_content = File.read(file_path)
          @options.file_path = file_path
          transformed_content = RrToRspecConverter::TextTransformer.new(original_content, @options).transform
          File.write(file_path, transformed_content)
        end
      end
    end

    def log(str)
      return if @options.quiet?

      puts str
    end
  end
end
