// ESLint reads this file to decide which code-quality rules to check.
// Run it with `npm run lint`. VS Code's ESLint extension uses the same file,
// so you see the same warnings as red/yellow squiggles while you type.
import js from '@eslint/js'
import globals from 'globals'
import react from 'eslint-plugin-react'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import prettier from 'eslint-config-prettier'

export default [
  // Folders ESLint should never look inside (build output, installed packages).
  { ignores: ['dist', 'node_modules'] },

  {
    files: ['**/*.{js,jsx}'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      // Our code runs in the browser, so `window`, `document`, etc. are allowed.
      globals: globals.browser,
      parserOptions: { ecmaFeatures: { jsx: true } },
    },
    // React needs to know which version it is checking against.
    settings: { react: { version: 'detect' } },
    plugins: {
      react,
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...js.configs.recommended.rules,
      ...react.configs.recommended.rules,
      // The modern JSX transform means we do not need `import React` in every
      // file, so these two older rules are switched off.
      ...react.configs['jsx-runtime'].rules,
      // We do not use PropTypes (that is what TypeScript is for later).
      'react/prop-types': 'off',
      // Catches the classic mistakes of using hooks like useState wrongly.
      ...reactHooks.configs.recommended.rules,
      // Keeps hot-reload working: files should export components only.
      'react-refresh/only-export-components': [
        'warn',
        { allowConstantExport: true },
      ],
    },
  },

  // Command-line scripts run in Node, not the browser, so they may use
  // Node's built-ins such as `process`.
  {
    files: ['scripts/**/*.{js,mjs}'],
    languageOptions: { globals: globals.node },
  },

  // Must come last: turns off any ESLint rule that would fight with Prettier
  // over spacing and quotes. Prettier owns formatting; ESLint owns correctness.
  prettier,
]
