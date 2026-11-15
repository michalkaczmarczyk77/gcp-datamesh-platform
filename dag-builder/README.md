# Airflow DAG Builder

A React + TypeScript visual editor for building Apache Airflow DAGs. The same
frontend runs in a browser and in an Electron desktop shell.

## Requirements

- Node.js 18.18 or newer
- npm

## Run the web app

```sh
npm install
npm run dev
```

## Run the desktop app

```sh
npm run desktop:dev
```

## Build

```sh
npm run build
npm run desktop:build
```

The desktop build is packaged for the current platform. Configure platform
signing and publishing separately before distributing production releases.

## Current prototype

- Drag operators from the palette to the canvas, then connect task handles.
- Configure DAG metadata and task parameters in the side panels.
- Save and reopen a draft in the current browser profile.
- Preview or download generated Python, and export the editor document as JSON.
- Register a custom operator manifest, configure its fields, and generate the matching import and task arguments.
- The Electron shell uses the same frontend as the web app.

Custom operator registration stores a manifest only; its Python package must
already be installed in the target Airflow environment. Airflow validation, Git
integration, and deployment are planned follow-on work. The generated Python is
a preview and should be reviewed and validated against the target Airflow
environment before use.
