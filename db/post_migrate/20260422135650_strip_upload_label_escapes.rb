# frozen_string_literal: true

# One-off cleanup for posts whose upload markdown labels accumulated backslash
# escapes through repeated rich-editor edits (regression from
# https://meta.discourse.org/t/401231). The backslashes doubled on each save
# (1 → 2 → 4 → … → 2^N). The engine-side fix prevents further damage; this
# heals existing posts.
#
# Pattern: match runs of `\` inside a label that closes with `](upload://…`.
# `[^\]\\]` excludes `\` from the prefix so the greedy match doesn't swallow
# a backslash that belongs to the run. `(?=…)` lookahead scopes the match to
# upload labels so user-written escapes elsewhere stay intact.
class StripUploadLabelEscapes < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE posts
      SET raw = regexp_replace(
        raw,
        '(\\[[^\\]\\\\]*)\\\\+([_*~|`])(?=[^\\]]*\\]\\(upload://)',
        '\\1\\2',
        'g'
      )
      WHERE raw ~ '\\[[^\\]\\\\]*\\\\+[_*~|`][^\\]]*\\]\\(upload://'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
