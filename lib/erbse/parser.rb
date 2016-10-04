module Erbse
  class Parser
    # ERB_EXPR = /<%(=+|-|\#|%)?(.*?)([-=])?%>([ \t]*\r?\n)?/m
    ERB_EXPR = /<%(=|\#)?(.*?)%>(\n)*/m
    # BLOCK_EXPR     = /\s*((\s+|\))do|\{)(\s*\|[^|]*\|)?\s*\Z/
    BLOCK_EXPR = /\b(if|unless)\b|\bdo\b/

    def initialize(*)
    end

    def call(str)
      pos = 0
      buffers = []
      result = [:multi]
      buffers << result
      match = nil

      str.scan(ERB_EXPR) do |indicator, code, newlines|
        match = Regexp.last_match
        len  = match.begin(0) - pos

        text = str[pos, len]
        pos  = match.end(0)
        ch   = indicator ? indicator[0] : nil

        if text and !text.strip.empty? # text
          buffers.last << [:static, text]
        end

        if ch == ?= # <%= %>
          if code =~ BLOCK_EXPR
            buffers.last << [:erb, :block, code, block = [:multi]] # picked up by our own BlockFilter.
            buffers << block
          else
            buffers.last << [:dynamic, code]
          end
        elsif code =~ /\bend\b/ # <% end %>
          buffers.pop
        elsif ch =~ /#/ # DISCUSS: doesn't catch <% # this %>
          newlines = code.count("\n")
          buffers.last.concat  [[:newline]] * newlines if newlines > 0
        else # <% %>
          if code =~ BLOCK_EXPR
            buffers.last << [:block, code, block = [:multi]] # picked up by Temple's ControlFlow filter.
            buffers << block
          else
            buffers.last << [:code, code]
          end
        end

        # FIXME: only adds one newline.
        # TODO: does that influence speed?
        buffers.last << [:newline] if newlines
      end

      # add text after last/none ERB tag.
      buffers.last << [:static, str[pos..str.length]] if pos < str.length

      buffers.last
    end
  end
end
