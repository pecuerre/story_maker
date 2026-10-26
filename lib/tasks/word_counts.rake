namespace :word_counts do
  desc "Recompute every Element's and Dialogue turn's stored word count"
  task recount: :environment do
    changed = 0

    [ SceneElement, SceneDialogueTurn ].each do |model|
      # Soft-deleted prose is included: a restored record returns with the count
      # it would have had, without waiting for someone to edit it again.
      model.with_deleted.find_each do |record|
        expected = WordCountable.words_in(record.body)
        next if record.word_count == expected

        record.update_columns(word_count: expected)
        changed += 1
      end
    end

    $stdout.puts("Recomputed #{changed} stored word count(s).")
  end
end
