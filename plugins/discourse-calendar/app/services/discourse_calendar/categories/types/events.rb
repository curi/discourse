# frozen_string_literal: true

module DiscourseCalendar
  module Categories
    module Types
      class Events < ::Categories::Types::Base
        type_id :events

        class << self
          def visible?
            SiteSetting.enable_events_category_type_setup
          end

          def enable_plugin
            SiteSetting.calendar_enabled = true
            SiteSetting.discourse_post_event_enabled = true
          end

          def category_matches?(category)
            events_calendar_category_ids.include?(category.id.to_s)
          end

          def find_matches
            Category.where(id: events_calendar_category_ids)
          end

          def configure_category(category, guardian:, configuration_values: {})
            add_to_events_calendar_categories(category)
            update_calendar_categories_entry(
              category,
              default_view: configuration_values.fetch(:events_calendar_default_view, "month").to_s,
              display_weekends:
                ActiveModel::Type::Boolean.new.cast(
                  configuration_values.fetch(:events_calendar_display_weekends, true),
                ),
            )
          end

          def unconfigure_category(category, guardian:)
            remove_from_events_calendar_categories(category)
            remove_calendar_categories_entry(category)
          end

          def configuration_schema
            {
              general_category_settings: {
                name: {
                  default: I18n.t("category_types.events.name"),
                  type: :string,
                },
                style_type: {
                  default: "emoji",
                  type: :string,
                },
                emoji: {
                  default: "spiral_calendar",
                  type: :string,
                },
              },
              category_settings: {
                events_calendar_default_view: {
                  default: "month",
                  type: :enum,
                  choices: [
                    {
                      name: I18n.t("discourse_calendar.category_type.default_calendar_view.day"),
                      value: "day",
                    },
                    {
                      name: I18n.t("discourse_calendar.category_type.default_calendar_view.week"),
                      value: "week",
                    },
                    {
                      name: I18n.t("discourse_calendar.category_type.default_calendar_view.month"),
                      value: "month",
                    },
                    {
                      name: I18n.t("discourse_calendar.category_type.default_calendar_view.year"),
                      value: "year",
                    },
                  ],
                  label: I18n.t("discourse_calendar.category_type.default_calendar_view.label"),
                },
                events_calendar_display_weekends: {
                  default: true,
                  type: :bool,
                  label: I18n.t("discourse_calendar.category_type.display_weekends.label"),
                },
              },
              site_settings: {
                discourse_post_event_allowed_on_groups: {
                  default: "",
                  type: :group_list,
                  label:
                    I18n.t(
                      "discourse_calendar.category_type.discourse_post_event_allowed_on_groups.label",
                    ),
                },
                use_local_event_date: {
                  default: false,
                  type: :enum,
                  choices: [
                    {
                      name: I18n.t("discourse_calendar.category_type.use_local_event_date.local"),
                      value: true,
                    },
                    {
                      name:
                        I18n.t("discourse_calendar.category_type.use_local_event_date.relative"),
                      value: false,
                    },
                  ],
                  label: I18n.t("discourse_calendar.category_type.use_local_event_date.label"),
                },
                sort_categories_by_event_start_date_enabled: {
                  default: true,
                  type: :enum,
                  choices: [
                    {
                      name:
                        I18n.t(
                          "discourse_calendar.category_type.sort_categories_by_event_start_date_enabled.event_date",
                        ),
                      value: true,
                    },
                    {
                      name:
                        I18n.t(
                          "discourse_calendar.category_type.sort_categories_by_event_start_date_enabled.latest_post",
                        ),
                      value: false,
                    },
                  ],
                  label:
                    I18n.t(
                      "discourse_calendar.category_type.sort_categories_by_event_start_date_enabled.label",
                    ),
                },
                sidebar_show_upcoming_events: {
                  default: true,
                  type: :bool,
                  label:
                    I18n.t("discourse_calendar.category_type.sidebar_show_upcoming_events.label"),
                },
              },
            }
          end

          def icon
            "spiral_calendar"
          end

          private

          def events_calendar_category_ids
            SiteSetting.events_calendar_categories.split("|")
          end

          def add_to_events_calendar_categories(category)
            ids = events_calendar_category_ids
            return if ids.include?(category.id.to_s)

            SiteSetting.events_calendar_categories = (ids << category.id.to_s).join("|")
          end

          def remove_from_events_calendar_categories(category)
            ids = events_calendar_category_ids - [category.id.to_s]
            SiteSetting.events_calendar_categories = ids.join("|")
          end

          def update_calendar_categories_entry(category, default_view:, display_weekends:)
            entry =
              "categoryId=#{category.id};weekends=#{display_weekends};defaultView=#{default_view}"

            entries = SiteSetting.calendar_categories.split("|")
            existing_index =
              entries.find_index { |e| e.split(";").include?("categoryId=#{category.id}") }

            if existing_index
              entries[existing_index] = entry
            else
              entries << entry
            end

            SiteSetting.calendar_categories = entries.join("|")
          end

          def remove_calendar_categories_entry(category)
            entries =
              SiteSetting
                .calendar_categories
                .split("|")
                .reject { |e| e.split(";").include?("categoryId=#{category.id}") }
            SiteSetting.calendar_categories = entries.join("|")
          end
        end
      end
    end
  end
end
