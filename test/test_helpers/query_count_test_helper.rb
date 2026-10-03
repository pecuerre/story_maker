# One place to count the queries a block issues.
#
# A list page can be correct and still cost one query per row, and the rendered
# HTML cannot show that: the assertion that catches it has to read the queries.
# Each test that needs it had grown its own copy of the same subscription, so the
# counting rule lived in three files and could drift between them.
#
# `pattern` limits the count to statements whose SQL matches it. A page test wants
# that, because every query the layout, the sidebar, and `Current` add is noise:
# the number being asserted is "how many times did *this* page ask the database",
# and an unrelated query added elsewhere would otherwise change it.
#
# `SCHEMA` queries are never counted. Rails reads column and index metadata
# lazily, so those appear the first time a table is touched in a process rather
# than because of anything the block did.
module QueryCountTestHelper
  def count_queries(pattern = nil, &block)
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name] == "SCHEMA"

      count += 1 if pattern.nil? || payload[:sql].match?(pattern)
    end
    block.call
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include QueryCountTestHelper
end
