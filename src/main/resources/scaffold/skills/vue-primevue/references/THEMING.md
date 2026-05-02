# PrimeVue Theming Reference

## Available Presets

| Preset | Package | Style |
|--------|---------|-------|
| Aura | `@primeuix/themes/aura` | Modern, rounded |
| Lara | `@primeuix/themes/lara` | Clean, flat |
| Nora | `@primeuix/themes/nora` | Outlined |
| Material | `@primeuix/themes/material` | Material Design |

## Full Configuration

```javascript
// main.js
app.use(PrimeVue, {
    theme: {
        preset: Aura,           // swap to Lara, Nora, Material
        options: {
            prefix: 'p',        // CSS variable prefix: --p-primary-color
            darkModeSelector: '.dark-mode',  // or 'system' for OS preference
            cssLayer: false     // set true if using Tailwind CSS layers
        }
    },
    ripple: true,
    inputVariant: 'filled',     // 'outlined' (default) | 'filled'
    locale: {
        firstDayOfWeek: 1,      // Monday
        accept: 'Yes',
        reject: 'No'
    },
    zIndex: {
        modal: 1100,
        overlay: 1000,
        menu: 1000,
        tooltip: 1100
    }
});
```

## Dark Mode Toggle

```vue
<script setup>
function toggleDark() {
  document.documentElement.classList.toggle('dark-mode');
}
</script>
```

## Design Tokens (CSS variables)

PrimeVue exposes design tokens as CSS custom properties:

```css
/* Primary color scale */
--p-primary-50  through  --p-primary-900

/* Surface scale */
--p-surface-0   through  --p-surface-900

/* Semantic */
--p-text-color
--p-text-muted-color
--p-content-border-color
--p-focus-ring-color
```

## Scoped Component Overrides (PassThrough)

```vue
<!-- Override Dialog mask -->
<Dialog
  pt:root:class="!border-0 !bg-transparent"
  pt:mask:class="backdrop-blur-sm"
>
```

## Using with Tailwind CSS

```javascript
// main.js — enable CSS layer to avoid conflicts
app.use(PrimeVue, {
    theme: {
        preset: Aura,
        options: { cssLayer: { name: 'primevue', order: 'tailwind-base, primevue, tailwind-utilities' } }
    }
});
```
