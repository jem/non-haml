# Simple line-wise parser for converting special files into slightly-enhanced
# files. No need for anything too complicated like a full-on grammar.
# Similar syntax to haml.

# Example usage:
#   require 'non-haml'
#   NonHaml.generate source, local_vars|context
#   NonHaml.generate_file 'output/source.c', 'source.c', local_vars|context

module NonHaml
  class << self
    def generate out_name, in_name, context_or_vars={}, base_dir='./', verbose=false
      NonHamlParser.new.generate out_name, in_name, context_or_vars, base_dir, verbose
    end
  end

  class IndentError < StandardError
  end

  class ParseError < StandardError
  end

  class NonHamlParser
    attr_accessor :last_ok_line, :out, :base_dir
    def initialize
      self.out = ""
    end

    def concat spaces=nil, text=nil
      if spaces.nil? and text.nil?
        self.out << "\n"
      else
        text.to_s.lines do |l|
          self.out << "#{' '*spaces}#{l.rstrip}\n"
        end
      end
    end

    def filename
      # Retrieves the current filename.
      @filenames.last
    end

    def push_filename new_name
      @filenames ||= []
      @filenames << new_name
    end

    def pop_filename
      @filenames.pop
    end

    def current_filename
      "#{base_dir}#{filename}"
    end

    def parse text, base_control_indent=0, base_indent=0
      @s = ""
      def store text
        @s << "#{text}\n"
      end

      # Number of indents at the start of blocks.
      @block_starts = []
      @statements = []
      @base_control_indent = base_control_indent
      def control_indent
        '  ' * (@block_starts.length + @base_control_indent)
      end

      def dedent indent, suppress_end=false
        dedented = false
        @block_starts.reverse.take_while{|x| x >= indent}.each do |x|
          # Close some blocks to get back to the right indentation level.
          @block_starts.pop
          unless suppress_end and %w{if elsif else}.include?(@statements.pop) and x == indent
            store control_indent + 'end'
          end
          dedented = true  # return status so we know whether to skip a blank line.
        end
        dedented
      end

      text.lines.with_index do |line,i|
        line.rstrip!

        line =~ /^( *)(.*)$/
        indent, line = $1.length, $2
        indent += base_indent

        if (line =~ /^- *((if|unless|for|elsif|else)\b.*)$/) or (line =~ /^- *(.*\bdo\b *(|.*|)?)$/)
          # Entering a block.

          if %w{elsif else}.include? $2
            store control_indent + "self.last_ok_line = #{i}"
            dedent indent, %w{elsif else}.include?($2)
          else
            dedent indent, %w{elsif else}.include?($2)
            store control_indent + "self.last_ok_line = #{i}"
          end

          store control_indent + $1
          @block_starts << indent
          @statements << $2
          # Output should have same indent as block.
          concat_indent = indent
        elsif line =~ /= ?non_haml ['"](.*)['"]/
          store control_indent + "self.last_ok_line = #{i}"
          file = base_dir + $1
          if File.readable? file
            store control_indent + "push_filename '#{$1}'"
            @s += parse open(file).read, control_indent.length, indent
          else
            store control_indent + "raise Errno::ENOENT, '\"#{$1}\"'"
          end
          store control_indent + "pop_filename"
        elsif line.strip.length.zero?
          # Blank line. Output and move on. Don't change indent. Only do this
          # for if blocks though, so 'if false' doesn't generate optional blank
          # line and 'if true' does.
          #if @statements.last == 'if' or @statements.empty?
          # XXX disabled temporarily because it sucked.
          store control_indent + "self.last_ok_line = #{i}"
          #if @statements.empty?
            store "#{control_indent}concat"
          #end
        else
          dedented = dedent indent
          store control_indent + "self.last_ok_line = #{i}"

          # Now deal with whatever we have left.
          if line =~ /^- *(.*)$/
            # Generic Ruby statement that isn't entering/leaving a block.
            store control_indent + $1
          elsif line =~ /^= *(.*)$/
            # Concatenate this for evaluation.
            target_indent = indent - control_indent.length
            # Deal with blank lines.
            content = $1
            content = '""' if content.empty?
            store "#{control_indent}concat(#{target_indent}, (#{content}))"
          elsif dedented and line.strip.empty?
            puts 'skipping'
            # Skip up to one blank line after dedenting.
            next
          else
            # Concatenate this for output.
            target_indent = indent - control_indent.length
            # Replace #{} blocks, but completely quote the rest.
            # TODO clean up more nicely if we fail here!!!
            to_sub = []
            line.gsub!('%', '%%')
            line.gsub!(/#\{(.*?)\}/){to_sub << $1; '%s'}
            if to_sub.empty?
              # Must do pretend substitutions to get around %% characters.
              subst = " % []"
            else
              # Include brackets around all quantities, so bracket-free
              # functions get the right arguments.
              subst = " % [#{to_sub.map{|x| "(#{x})"}.join ', '}]"
            end
            store "#{control_indent}concat #{target_indent}, (%q##{line.gsub('#', '\\#')}##{subst})"
          end
        end
      end
      dedent 0
      @s
    end

    def evaluate(code)
      eval(code, @context)
    end

    def prepare_context(_context_or_vars)
      case _context_or_vars
      when Hash
        @context = binding
        _context_or_vars.each do |name, value|
          evaluate("#{name} = nil")
          setter = evaluate("lambda{|v| #{name} = v}")
          setter.call(value)
        end
      else
        raise TypeError, "cannot use context of type #{_context_or_vars.class}"
      end
      evaluate("concat = nil")
      setter = evaluate("lambda{|v| concat = v}")
    end

    def generate out_name, in_name, context_or_vars, base_dir, verbose
      self.base_dir = base_dir
      push_filename(in_name)

      context = prepare_context(context_or_vars)
      source = File.read(current_filename)
      parsed = parse(source)

      if verbose
        parsed.lines.each_with_index do |l,i|
          print Color.blue '%3d  ' % (i + 1)
          puts l
        end
      end

      begin
        evaluate(parsed)
      rescue Exception => e
        # Interrupt everything, give more info, then dump out the old exception.
        $stderr.puts "In #{current_filename}:"
        $stderr.puts Color.red " #{e.class.name}: #{Color.blue e.to_s}"
        File.read(current_filename).lines.each_with_index.drop([last_ok_line - 2, 0].max).first(5).each do |line,i|
          if i == last_ok_line
            $stderr.print Color.red ' %3d  ' % (i + 1)
            $stderr.print Color.red line
          else
            $stderr.print ' %3d  ' % (i + 1)
            $stderr.print line
          end
        end
        raise e
      else
        File.open(out_name, "w") do |f|
          f.write(out)
        end
      end
    end
  end
end
