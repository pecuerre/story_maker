module TagDetails
  extend ActiveSupport::Concern

  private
    def load_tag_details(tag)
      if tag.taggable
        @include_descendants = params[:include_descendants] != "0"
        @tagged_records = if @include_descendants
          tag.tagged_records_including_descendants
        else
          tag.tagged_records
        end
      else
        @child_tags = tag.children.order(:position, :id).to_a
        @records_by_child_tag = TaggedRecordsByTag.for(@child_tags)
        records = @records_by_child_tag.values.flatten.uniq
        @tags_by_record = RecordTags.for(records)
      end
    end
end
