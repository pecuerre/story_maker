module StoryInterchange
  # One `## Dialog` block's turns.
  #
  # A turn starts with its speaker and an opening quote:
  # `@[[character:ada]] "The gate is open."`. The speaker is either a typed
  # Character link or a bare slug for a speaker with no entity file; the bare
  # form becomes a non-character turn whose body carries the tag. A quoted line
  # may wrap across physical lines; the turn continues until a line ends with the
  # closing quote, and the continuation lines are joined with a space because the
  # source's line break is the editor's, not the dialogue's.
  #
  # A nonblank line that does not start a turn, and a turn that reaches the next
  # turn or the end of the block without closing its quote, are returned as
  # invalid so the validator can refuse the Scene with a specific message.
  module SceneDialogue
    Turn = Data.define(:speaker, :body)
    Invalid = Data.define(:text, :reason)
    Result = Data.define(:turns, :invalid)

    START = /\A@(?<speaker>\[\[[^\[\]\n]+\]\]|[a-z0-9][a-z0-9-]*)[ \t]+"(?<text>.*)\z/

    module_function

    def parse(body)
      turns = []
      invalid = []
      lines = body.to_s.lines.map(&:strip)
      index = 0

      while index < lines.length
        line = lines[index]
        index += 1
        next if line.empty?

        match = START.match(line)
        unless match
          invalid << Invalid.new(text: line, reason: :not_a_turn)
          next
        end

        text = match[:text]
        if closed?(text)
          turns << Turn.new(speaker: match[:speaker], body: unquote(text))
          next
        end

        closed = false
        while index < lines.length
          continuation = lines[index]
          break if continuation.empty? || START.match?(continuation)

          index += 1
          text = "#{text} #{continuation}"
          if closed?(text)
            closed = true
            break
          end
        end

        if closed
          turns << Turn.new(speaker: match[:speaker], body: unquote(text))
        else
          invalid << Invalid.new(text: line, reason: :unterminated)
        end
      end

      Result.new(turns: turns, invalid: invalid)
    end

    def closed?(text)
      text.end_with?('"')
    end
    private_class_method :closed?

    def unquote(text)
      text.delete_suffix('"')
    end
    private_class_method :unquote
  end
end
