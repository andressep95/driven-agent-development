---
name: vue-primevue
description: >
  Builds Vue 3 frontends with PrimeVue using Composition API, script setup, Aura/Lara theming,
  form components, DataTable, Dialog, Toast, and composables.
  Trigger: When creating or modifying Vue 3 components, pages, or forms that use PrimeVue UI components.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "Create Vue component with PrimeVue"
    - "Build a form with PrimeVue inputs"
    - "Add DataTable with pagination and filtering"
    - "Configure PrimeVue in main.js"
    - "Use PrimeVue Dialog or Toast"
    - "Setup PrimeVue theme with Aura or Lara"
    - "Write Vue 3 composable"
    - "Add script setup component"
    - "Vue 3 frontend with PrimeVue"
    - "Implement lazy loading DataTable"
    - "PrimeVue form validation"
    - "Vue 3 Composition API component"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
---

# Vue 3 + PrimeVue

Guide for building Vue 3 frontends with PrimeVue using `<script setup>`, Composition API, and design tokens from Aura/Lara presets.

## When to Use (and When NOT to)

| Use When | Skip When |
|----------|-----------|
| Creating or editing `.vue` files with PrimeVue components | Plain HTML/CSS with no framework |
| Configuring PrimeVue theme or plugin in `main.js` | Using a different UI library (Vuetify, Quasar) |
| Building forms with PrimeVue inputs | Options API — migrate to `<script setup>` first |
| Adding DataTable, Dialog, or Toast | Simple text/layout with no interactive components |
| Writing composables shared across components | One-off logic better inlined in the component |

## Quick Diagnosis

```
What do I need?
├─ New component          → Use <script setup> + defineProps/defineEmits
├─ Form with inputs       → FloatLabel + InputText/Select/DatePicker + Button
├─ Table with server data → DataTable lazy + paginator + @page/@sort/@filter
├─ Modal/popup            → Dialog v-model:visible + #container slot
├─ User feedback          → useToast() + <Toast /> in App.vue
├─ Shared reactive logic  → Composable in composables/useXxx.ts
└─ App bootstrap          → main.js with PrimeVue + Aura preset
```

## Critical Rules

| Rule | Why |
|------|-----|
| **Always use `<script setup>`** | Less boilerplate, better TS inference, smaller bundle |
| **Never mutate props directly** | Breaks one-way data flow — emit an event instead |
| **Register `<Toast />` once in App.vue** | Multiple instances cause duplicate notifications |
| **Always set `dataKey` on DataTable** | Required for selection and row identity |
| **Use `v-model:visible` for Dialog** | Two-way binding is required by the component |
| **Import PrimeVue components individually** | Tree-shaking; avoid global auto-import if bundle size matters |

## Patterns

### 1. App Bootstrap — PrimeVue with Aura theme

```javascript
// main.js
import { createApp } from 'vue';
import PrimeVue from 'primevue/config';
import Aura from '@primeuix/themes/aura';
import ToastService from 'primevue/toastservice';
import App from './App.vue';

const app = createApp(App);

app.use(PrimeVue, {
    theme: {
        preset: Aura,
        options: {
            prefix: 'p',
            darkModeSelector: '.dark-mode',
            cssLayer: false
        }
    },
    ripple: true
});

app.use(ToastService);
app.mount('#app');
```

### 2. Component — `<script setup>` with props and emits

```vue
<script setup lang="ts">
import { ref, computed } from 'vue';

const props = defineProps<{
  title: string;
  items?: string[];
}>();

const emit = defineEmits<{
  (e: 'select', value: string): void;
}>();

const selected = ref('');
const count = computed(() => props.items?.length ?? 0);

function handleSelect(value: string) {
  selected.value = value;
  emit('select', value);
}
</script>

<template>
  <div>
    <h2>{{ title }} ({{ count }})</h2>
    <Button label="Select" @click="handleSelect(selected)" />
  </div>
</template>
```

### 3. Form with PrimeVue inputs

```vue
<script setup lang="ts">
import { ref } from 'vue';
import InputText from 'primevue/inputtext';
import Select from 'primevue/select';
import Button from 'primevue/button';
import FloatLabel from 'primevue/floatlabel';

const form = ref({ name: '', country: null });
const countries = ref([
  { name: 'Colombia', code: 'CO' },
  { name: 'United States', code: 'US' }
]);
const errors = ref<Record<string, string>>({});
const loading = ref(false);

async function handleSubmit() {
  errors.value = {};
  if (!form.value.name) errors.value.name = 'Required';
  if (Object.keys(errors.value).length) return;

  loading.value = true;
  try {
    // call API
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <form @submit.prevent="handleSubmit" class="flex flex-col gap-4">
    <FloatLabel>
      <InputText id="name" v-model="form.name" :invalid="!!errors.name" />
      <label for="name">Name</label>
    </FloatLabel>
    <small v-if="errors.name" class="p-error">{{ errors.name }}</small>

    <Select
      v-model="form.country"
      :options="countries"
      optionLabel="name"
      optionValue="code"
      placeholder="Select Country"
      showClear
    />

    <Button type="submit" label="Submit" :loading="loading" />
  </form>
</template>
```

### 4. DataTable — lazy loading with pagination, sort, filter

```vue
<script setup lang="ts">
import { ref, onMounted } from 'vue';
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import InputText from 'primevue/inputtext';

const rows = ref([]);
const totalRecords = ref(0);
const loading = ref(false);
const first = ref(0);
const filters = ref({
  name: { value: '', matchMode: 'contains' }
});
const lazyParams = ref({ first: 0, rows: 10, sortField: null, sortOrder: null, filters: filters.value });

async function loadData(event?: any) {
  loading.value = true;
  lazyParams.value = { ...lazyParams.value, first: event?.first ?? first.value };
  try {
    const data = await fetchFromApi(lazyParams.value);
    rows.value = data.items;
    totalRecords.value = data.total;
  } finally {
    loading.value = false;
  }
}

onMounted(() => loadData());

const onPage = (e: any) => { lazyParams.value = e; loadData(e); };
const onSort = (e: any) => { lazyParams.value = e; loadData(e); };
const onFilter = (e: any) => { lazyParams.value.filters = filters.value; loadData(e); };
</script>

<template>
  <DataTable
    :value="rows"
    lazy paginator
    :first="first"
    :rows="10"
    :totalRecords="totalRecords"
    :loading="loading"
    v-model:filters="filters"
    filterDisplay="row"
    dataKey="id"
    @page="onPage"
    @sort="onSort"
    @filter="onFilter"
  >
    <Column field="name" header="Name" sortable>
      <template #filter="{ filterModel, filterCallback }">
        <InputText v-model="filterModel.value" @keydown.enter="filterCallback()" placeholder="Search" fluid />
      </template>
    </Column>
    <Column field="email" header="Email" sortable />
  </DataTable>
</template>
```

### 5. Dialog

```vue
<script setup lang="ts">
import { ref } from 'vue';
import Dialog from 'primevue/dialog';
import Button from 'primevue/button';

const visible = ref(false);
</script>

<template>
  <Button label="Open" @click="visible = true" />

  <Dialog
    v-model:visible="visible"
    header="Confirm"
    :modal="true"
    :closable="true"
    :dismissableMask="true"
    style="width: 30rem"
  >
    <p>Are you sure?</p>
    <template #footer>
      <Button label="Cancel" severity="secondary" @click="visible = false" />
      <Button label="Confirm" @click="visible = false" />
    </template>
  </Dialog>
</template>
```

### 6. Toast notifications

```vue
<!-- App.vue — register once -->
<template>
  <Toast />
  <RouterView />
</template>

<!-- Any component -->
<script setup lang="ts">
import { useToast } from 'primevue/usetoast';

const toast = useToast();

function notifySuccess() {
  toast.add({ severity: 'success', summary: 'Done', detail: 'Record saved', life: 3000 });
}
function notifyError(msg: string) {
  toast.add({ severity: 'error', summary: 'Error', detail: msg, life: 5000 });
}
</script>
```

### 7. Composable pattern

```typescript
// composables/useUsers.ts
import { ref } from 'vue';

export function useUsers() {
  const users = ref([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchUsers() {
    loading.value = true;
    error.value = null;
    try {
      const res = await fetch('/api/users');
      users.value = await res.json();
    } catch (e) {
      error.value = 'Failed to load users';
    } finally {
      loading.value = false;
    }
  }

  return { users, loading, error, fetchUsers };
}
```

### 8. Provide / Inject across component tree

```vue
<!-- Parent -->
<script setup>
import { provide, ref } from 'vue';

const theme = ref('light');
provide('theme', { theme, toggleTheme: () => { theme.value = theme.value === 'light' ? 'dark' : 'light'; } });
</script>

<!-- Child (any depth) -->
<script setup>
import { inject } from 'vue';
const { theme, toggleTheme } = inject('theme');
</script>
```

## Install Commands

```bash
# Install PrimeVue + themes
npm install primevue @primeuix/themes

# Optional: icons
npm install primeicons

# Vite project scaffold
npm create vue@latest my-app
cd my-app && npm install
```

## Review Checklist

```
[ ] Using <script setup> — no Options API
[ ] Props declared with defineProps<T>() using TypeScript generics
[ ] Events declared with defineEmits<T>()
[ ] PrimeVue plugin registered in main.js with theme preset
[ ] ToastService registered in main.js if using Toast
[ ] <Toast /> present once in App.vue root template
[ ] DataTable has dataKey set
[ ] DataTable lazy mode has @page, @sort, @filter handlers
[ ] Dialog uses v-model:visible (not :visible)
[ ] Forms handle loading and error states
[ ] Composables return { data, loading, error, action }
```

## Internal Reference

| File | Content |
|------|---------|
| [references/COMPONENTS.md](references/COMPONENTS.md) | Full PrimeVue component prop reference |
| [references/THEMING.md](references/THEMING.md) | Aura/Lara presets, design tokens, dark mode |
| [references/CHEATSHEET.md](references/CHEATSHEET.md) | Quick decision guide |
