# Descriptors for the "Appears in Scenes" section on a shared universe record's
# details page. The section is the reverse of the Scene workspace tabs, so it
# states the same two things the tabs do: which Scene, and for what reason.
#
# The reason strings are the ones the three tabs also use, so a Character linked
# in the Characters tab and the same Character on this page are labelled
# identically; only the *count* in the speaker badge needs a `count:`, and
# `count_with_label` chooses the plural.
module SceneAppearancesHelper
  # Why a record appears in a Scene. A record can appear for more than one reason
  # in the same Scene, and the reasons are always listed rather than collapsed,
  # because "linked with a role" and "speaks in a dialogue" are different facts.
  def scene_appearance_badges(entry)
    badges = []
    badges << t("scenes.participation.linked") if entry.linked?
    badges << t("scenes.participation.speaks_in",
      count: count_with_label(entry.speaking_elements.size, "element")) if entry.speaks?
    badges << t("scenes.participation.depicted") if entry.depicted?
    badges
  end

  # The free-text role, or the honest statement that the author recorded the
  # appearance without saying how. Only a stored link has a role at all: a derived
  # speaker and a depicted Event never carry one.
  def scene_appearance_role_label(entry)
    return unless entry.linked?

    entry.role.presence || t("scenes.participation.no_role")
  end

  # Where a derived speaker's appearance comes from. A stored link has no such
  # list, because the link itself is the fact.
  def scene_appearance_speaking_in(entry)
    return nil unless entry.speaks?

    entry.speaking_elements
  end

  # The label the section carries, which always names the Story whose Scenes it
  # lists. A Scene has no Universe-level URL, so a link without this scope would
  # be pointing at a story the author never chose. The Story's name is the
  # author's own record name, so it is interpolated rather than translated.
  def scene_appearances_title(appearances, story)
    t("scenes.appearances.title", story: story.name)
  end
end
