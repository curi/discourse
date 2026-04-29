import Component from "@glimmer/component";
import EditCategoryTypeSchemaFields from "discourse/components/edit-category-type-schema-fields";
import { i18n } from "discourse-i18n";

export default class UpsertCategoryEvents extends Component {
  get isEventsCategory() {
    return this.args.category.isType("events");
  }

  <template>
    {{#if this.isEventsCategory}}
      <EditCategoryTypeSchemaFields
        @category={{@category}}
        @categoryType="events"
        @form={{@form}}
      />
    {{else}}
      {{i18n "discourse_calendar.category_type_events.not_events_type"}}
    {{/if}}
  </template>
}
