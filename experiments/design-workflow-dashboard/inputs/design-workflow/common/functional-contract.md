# Functional contract

## Required surfaces and behavior
- Show operational KPIs and an hourly temperature-anomaly trend.
- Show all 64 shipments in a data table with row and visible-all selection, status, tracking code, cargo, route, driver, vehicle, current temperature, allowed range, ETA, and alert information.
- Apply date, status, hub, temperature-state, and driver filters; sort at least the temperature column.
- Apply an in-memory bulk status action to selected shipments.
- Open shipment detail without leaving the dashboard; include current information, temperature trend, sensor events, and action history with enough data to exceed the available display area.
- Edit driver name, phone, tracking code, assigned driver, vehicle, origin, destination, shipment status, minimum temperature, maximum temperature, and notes. Driver choice uses all 96 candidates. Save, cancel, validation error, and save success must work in memory.
- Put a notifications button in the dashboard header. It opens all 30 notifications without leaving the current dashboard and allows read and resolution state changes.
- Reproduce `?demo=loading`, `?demo=empty`, and `?demo=error`; default or `?demo=default` shows the working dashboard.

## Stable automation hooks
Place `data-testid` on the semantic control or state represented by each identifier:
`app-root`, `loading-state`, `empty-state`, `error-state`, `filter-trigger`, `filters-surface`, `filter-status`, `filter-status-option-temperature-excursion`, `filter-hub`, `filter-hub-option-HUB-12`, `filter-date`, `filter-temperature`, `filter-driver`, `filter-apply`, `results-count`, `sort-temperature`, `select-all-visible`, `row-select-SHP-001`, `bulk-action-trigger`, `bulk-resolve`, `shipment-status-SHP-001`, `notifications-trigger`, `notifications-surface`, `notification-ALT-030`, `notification-toggle-read-ALT-030`, `notification-state-ALT-030`, `notification-toggle-resolution-ALT-030`, `notification-resolution-ALT-030`, `shipment-open-SHP-001`, `shipment-detail`, `edit-dispatch`, `driver-control`, `driver-options`, `driver-option-DRV-096`, `dispatch-driver-name`, `dispatch-phone`, `dispatch-tracking`, `dispatch-min-temperature`, `dispatch-max-temperature`, `dispatch-notes`, `save-dispatch`, `cancel-dispatch`, `dispatch-driver`, `validation-error`, `save-success`.

Use native checkbox inputs for `select-all-visible` and row-selection hooks. For a native `<select>`, use the domain ID as the option value. For a custom selector, make the matching option hook clickable. Put `data-state="unread|read"` on `notification-state-ALT-030` and `data-state="open|acknowledged|resolved"` on `notification-resolution-ALT-030`. The six dispatch field hooks belong on their actual form controls. The hook names do not prescribe component type, layout, dimensions, list navigation, search, overlay behavior, or styling. Choose those as part of the implementation.

## Technical limits
Use React, TypeScript, Vite, `lucide-react`, CSS, HTML, SVG, and browser APIs already present in the root lockfile. Do not add dependencies or import runtime code from outside the assigned variant directory. Copy the supplied `types.ts` and `fixtures.ts` unchanged into `src/`.
