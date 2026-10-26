# A stored word count for one block of prose. A Story's total is a sum over
# every Element and Dialogue turn, and the Sections workspace shows the same
# number per Section; counting by loading every body on each request would put
# the whole manuscript in memory. The count is therefore recomputed from the text
# whenever the record is saved and read back with `SUM`, never derived at render
# time.
#
# `WordCounts` owns the Story and Section rollups; this concern owns only the one
# record's number, so a new block of prose joins a total by being counted here.
module WordCountable
  extend ActiveSupport::Concern

  included do
    before_save :refresh_word_count
  end

  class_methods do
    # The text attribute the count is derived from. Every current caller counts
    # its `body`; the DSL is here so a future prose field names its own source
    # instead of the concern assuming the column.
    def counts_words_from(attribute = :body)
      @word_count_attribute = attribute
    end

    def word_count_attribute
      @word_count_attribute || :body
    end
  end

  # Whitespace-delimited tokens, which is what a word processor reports for plain
  # prose: "one, two" is two words and a blank body is none.
  def self.words_in(text)
    text.to_s.split.size
  end

  private
    def refresh_word_count
      self.word_count = WordCountable.words_in(public_send(self.class.word_count_attribute))
    end
end
