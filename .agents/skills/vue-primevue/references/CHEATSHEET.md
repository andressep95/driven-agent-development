# Vue 3 + PrimeVue — Quick Decision Guide

## Component scaffolding

```
Need a new component?
├─ Just display data?          → <script setup> + defineProps<T>()
├─ Accepts user input?         → Add defineEmits + v-model pattern
├─ Shares logic across pages?  → Extract to composables/useXxx.ts
└─ Needs global state?         → Pinia store or provide/inject
```

## Which input component?

| Need | Component |
|------|-----------|
| Short text | `InputText` |
| Long text | `Textarea` |
| Number | `InputNumber` |
| Date | `DatePicker` |
| Single option from list | `Select` |
| Multiple options from list | `MultiSelect` |
| Boolean toggle | `ToggleSwitch` or `Checkbox` |
| One of N mutually exclusive | `RadioButton` |
| Secret text | `Password` |

## DataTable mode

| Data source | Mode |
|-------------|------|
| All records in memory | Default (no `lazy`) |
| Backend pagination / filter / sort | `lazy` + `totalRecords` + event handlers |

## Feedback pattern

| Situation | Component |
|-----------|-----------|
| Transient notification | `Toast` via `useToast()` |
| Confirmation / action | `Dialog` with footer buttons |
| Inline validation | `:invalid` prop + `<small class="p-error">` |
| Full-page blocking | `loading` prop on `Button` / DataTable |

## Common mistakes

| Mistake | Fix |
|---------|-----|
| `:visible="show"` on Dialog | Use `v-model:visible="show"` |
| Multiple `<Toast />` in tree | Move to `App.vue` root only |
| DataTable row identity broken | Add `dataKey="id"` |
| Reactive loss after destructure | Keep `const { count } = storeToRefs(store)` or use `toRefs` |
| Prop mutation | Emit event, parent updates the ref |
