import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import UpsertCategoryEvents from "../components/upsert-category-events";

export default {
  name: "events-category-type-tab",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    withPluginApi((api) => {
      api.registerEditCategoryTab({
        id: "events",
        name: i18n("discourse_calendar.category_type_events.title"),
        primary: true,
        component: UpsertCategoryEvents,
        condition: ({ category }) => {
          return (
            category.isType("events") &&
            siteSettings.enable_events_category_type_setup
          );
        },
      });
    });
  },
};
