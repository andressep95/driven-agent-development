# PrimeVue Component Reference

## Form Inputs

| Component | Import | Key Props |
|-----------|--------|-----------|
| `InputText` | `primevue/inputtext` | `v-model`, `:invalid`, `fluid` |
| `Select` | `primevue/select` | `v-model`, `:options`, `optionLabel`, `optionValue`, `placeholder`, `filter`, `showClear` |
| `MultiSelect` | `primevue/multiselect` | `v-model`, `:options`, `optionLabel`, `display="chip"`, `:maxSelectedLabels` |
| `DatePicker` | `primevue/datepicker` | `v-model`, `dateFormat`, `showIcon`, `showButtonBar`, `:minDate`, `:maxDate` |
| `InputNumber` | `primevue/inputnumber` | `v-model`, `mode="currency"`, `currency`, `locale`, `:min`, `:max` |
| `Checkbox` | `primevue/checkbox` | `v-model`, `:value`, `inputId` |
| `RadioButton` | `primevue/radiobutton` | `v-model`, `:value`, `inputId` |
| `ToggleSwitch` | `primevue/toggleswitch` | `v-model`, `inputId` |
| `Textarea` | `primevue/textarea` | `v-model`, `:rows`, `autoResize` |
| `Password` | `primevue/password` | `v-model`, `toggleMask`, `:feedback` |
| `FloatLabel` | `primevue/floatlabel` | Wraps any input; `<label>` inside |

## Overlay & Feedback

### Dialog — key props
| Prop | Type | Default | Notes |
|------|------|---------|-------|
| `v-model:visible` | boolean | false | **Required** for open/close |
| `header` | string | — | Title text |
| `modal` | boolean | false | Block background |
| `closable` | boolean | true | Show X button |
| `dismissableMask` | boolean | false | Click outside to close |
| `closeOnEscape` | boolean | true | Esc key closes |
| `maximizable` | boolean | false | Full-screen toggle |
| `position` | string | center | left, right, top, bottom, topleft, topright, bottomleft, bottomright |
| `breakpoints` | object | — | `{ '960px': '75vw', '640px': '90vw' }` |
| `pt` | object | — | PassThrough to override inner DOM |

### Toast — key props
| Prop | Type | Default | Notes |
|------|------|---------|-------|
| `position` | string | top-right | top-left, top-center, bottom-* , center |
| `group` | string | — | Scoped group key |
| `baseZIndex` | number | 0 | Layer base |
| `autoZIndex` | boolean | true | Auto-manage z |

```typescript
// Severity values
toast.add({ severity: 'success' | 'info' | 'warn' | 'error', summary, detail, life });
```

## DataTable — key props

| Prop | Notes |
|------|-------|
| `:value` | Array of rows |
| `dataKey` | Unique field name (required for selection) |
| `lazy` | Enable server-side mode |
| `paginator` | Show paginator |
| `:rows` | Rows per page |
| `:totalRecords` | Total for lazy mode |
| `:loading` | Show spinner |
| `v-model:filters` | Filter state object |
| `filterDisplay` | `"row"` or `"menu"` |
| `:globalFilterFields` | Array of field paths |
| `v-model:selection` | Selected row(s) |
| `selectionMode` | `"single"` or `"multiple"` |
| `sortMode` | `"single"` or `"multiple"` |
| `removableSort` | Allow un-sorted state |

### Column — key props

| Prop | Notes |
|------|-------|
| `field` | Data path (supports dot notation) |
| `header` | Column header label |
| `sortable` | Enable sorting on this column |
| `filterMatchMode` | `startsWith`, `contains`, `equals`, `notContains`, `endsWith` |
| `filterField` | Override field for filter (useful for nested paths) |
| `selectionMode` | `"multiple"` on first Column for checkboxes |

### Column slots

```vue
<Column field="status" header="Status">
  <!-- Custom cell renderer -->
  <template #body="{ data }">
    <Tag :value="data.status" :severity="data.status === 'active' ? 'success' : 'danger'" />
  </template>

  <!-- Custom filter widget in row mode -->
  <template #filter="{ filterModel, filterCallback }">
    <InputText v-model="filterModel.value" @keydown.enter="filterCallback()" placeholder="Search" />
  </template>
</Column>
```

## Button

```vue
<Button label="Save" icon="pi pi-check" severity="success" :loading="loading" @click="save" />
<Button label="Cancel" severity="secondary" text />
<Button icon="pi pi-trash" severity="danger" rounded outlined />
```

Severity values: `success`, `info`, `warn`, `danger`, `secondary`, `contrast`
