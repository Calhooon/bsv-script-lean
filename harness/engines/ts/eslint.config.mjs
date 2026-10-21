// bsv-script-lean #136 (2026-10-14): the flat configuration of the tslint leg (tools/check.sh): ESLint's recommended
// set and the typescript-eslint recommended sets, the type-checked one included (its type information from
// tsconfig.json through the project service), over the ts-sdk adapter; every version pinned exactly in package.json.
import { defineConfig } from 'eslint/config'
import js from '@eslint/js'
import tseslint from 'typescript-eslint'
import globals from 'globals'

export default defineConfig(
  { ignores: ['node_modules/'] },
  js.configs.recommended,
  tseslint.configs.recommendedTypeChecked,
  {
    files: ['**/*.mjs'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: globals.node,
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname }
    }
  }
)
