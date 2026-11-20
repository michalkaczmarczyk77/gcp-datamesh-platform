import type { Edge, Node } from "@xyflow/react";

export type OperatorKind =
  | "EmptyOperator"
  | "BashOperator"
  | "SQLExecuteQueryOperator"
  | (string & {});

export interface OperatorField {
  name: string;
  label: string;
  type: "text" | "textarea";
  defaultValue: string;
}

export interface RegisteredOperator {
  name: string;
  module: string;
  label: string;
  description: string;
  fields: OperatorField[];
}

export interface OperatorData extends Record<string, unknown> {
  label: string;
  operator: OperatorKind;
  retries: number;
  params: Record<string, string>;
}

export interface DagDocument {
  version: 1;
  dag: {
    dagId: string;
    schedule: string;
    description: string;
  };
  nodes: Node<OperatorData>[];
  edges: Edge[];
  plugins: RegisteredOperator[];
}

export const operatorCatalog: {
  kind: OperatorKind;
  title: string;
  description: string;
  badge: string;
}[] = [
  {
    kind: "EmptyOperator",
    title: "Empty task",
    description: "A lightweight task for organizing dependencies.",
    badge: "OP",
  },
  {
    kind: "BashOperator",
    title: "Run Bash",
    description: "Execute a shell command in a task.",
    badge: "SH",
  },
  {
    kind: "SQLExecuteQueryOperator",
    title: "Run SQL",
    description: "Execute SQL using an Airflow connection.",
    badge: "DB",
  },
];

export function defaultParams(operator: OperatorKind): Record<string, string> {
  if (operator === "BashOperator") return { bash_command: "echo 'Hello from Airflow'" };
  if (operator === "SQLExecuteQueryOperator") {
    return { conn_id: "my_database", sql: "SELECT 1;" };
  }
  return {};
}

export function createTaskNode(
  operator: OperatorKind,
  position: { x: number; y: number },
): Node<OperatorData> {
  return {
    id: `task_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 6)}`,
    type: "task",
    position,
    data: {
      label: operatorCatalog.find((item) => item.kind === operator)?.title ?? operator,
      operator,
      retries: 1,
      params: defaultParams(operator),
    },
  };
}

export function parseOperatorManifest(value: unknown): RegisteredOperator {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Manifest must be a JSON object.");
  }
  const manifest = value as Record<string, unknown>;
  const identifier = /^[A-Za-z_][A-Za-z0-9_]*$/;
  const moduleName = /^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$/;

  if (typeof manifest.name !== "string" || !identifier.test(manifest.name)) {
    throw new Error("name must be a valid Python class name.");
  }
  if (typeof manifest.module !== "string" || !moduleName.test(manifest.module)) {
    throw new Error("module must be a dotted Python import path.");
  }
  if (typeof manifest.label !== "string" || !manifest.label.trim()) {
    throw new Error("label must be a non-empty string.");
  }
  if (typeof manifest.description !== "string") {
    throw new Error("description must be a string.");
  }
  if (!Array.isArray(manifest.fields)) {
    throw new Error("fields must be an array.");
  }

  const fields: OperatorField[] = manifest.fields.map((field: unknown) => {
    if (!field || typeof field !== "object" || Array.isArray(field)) {
      throw new Error("Each field must be an object.");
    }
    const item = field as Record<string, unknown>;
    if (typeof item.name !== "string" || !identifier.test(item.name)) {
      throw new Error("Field names must be valid Python identifiers.");
    }
    if (item.name === "task_id" || item.name === "retries") {
      throw new Error(`The field name "${item.name}" is reserved.`);
    }
    if (typeof item.label !== "string" || !item.label.trim()) {
      throw new Error(`Field "${item.name}" must have a non-empty label.`);
    }
    if (item.type !== "text" && item.type !== "textarea") {
      throw new Error(`Field "${item.name}" type must be "text" or "textarea".`);
    }
    if (item.defaultValue !== undefined && typeof item.defaultValue !== "string") {
      throw new Error(`Field "${item.name}" defaultValue must be a string.`);
    }
    return {
      name: item.name,
      label: item.label,
      type: item.type,
      defaultValue: typeof item.defaultValue === "string" ? item.defaultValue : "",
    };
  });

  if (new Set(fields.map((field) => field.name)).size !== fields.length) {
    throw new Error("Field names must be unique.");
  }

  return {
    name: manifest.name,
    module: manifest.module,
    label: manifest.label.trim(),
    description: manifest.description,
    fields,
  };
}

export function parseDagDocument(value: unknown): DagDocument {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("DAG document must be a JSON object.");
  }
  const document = value as Record<string, unknown>;
  const dag = document.dag as Record<string, unknown> | undefined;
  if (
    !dag ||
    typeof dag.dagId !== "string" ||
    typeof dag.schedule !== "string" ||
    typeof dag.description !== "string"
  ) {
    throw new Error("DAG document has invalid DAG settings.");
  }
  if (!Array.isArray(document.nodes) || !Array.isArray(document.edges)) {
    throw new Error("DAG document must include nodes and edges.");
  }

  const nodes: Node<OperatorData>[] = document.nodes.map((value: unknown) => {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new Error("Each DAG node must be an object.");
    }
    const node = value as Record<string, unknown>;
    const position = node.position as Record<string, unknown> | undefined;
    const data = node.data as Record<string, unknown> | undefined;
    const params = data?.params as Record<string, unknown> | undefined;
    if (
      typeof node.id !== "string" ||
      !position ||
      typeof position.x !== "number" ||
      typeof position.y !== "number" ||
      !data ||
      typeof data.label !== "string" ||
      typeof data.operator !== "string" ||
      typeof data.retries !== "number" ||
      !params ||
      Object.values(params).some((item) => typeof item !== "string")
    ) {
      throw new Error("A DAG node has invalid task settings.");
    }
    return {
      id: node.id,
      type: "task",
      position: { x: position.x, y: position.y },
      data: {
        label: data.label,
        operator: data.operator,
        retries: data.retries,
        params: params as Record<string, string>,
      },
    };
  });

  const edges: Edge[] = document.edges.map((value: unknown) => {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new Error("Each DAG connection must be an object.");
    }
    const edge = value as Record<string, unknown>;
    if (typeof edge.id !== "string" || typeof edge.source !== "string" || typeof edge.target !== "string") {
      throw new Error("A DAG connection has invalid endpoints.");
    }
    return { id: edge.id, source: edge.source, target: edge.target, type: "smoothstep" };
  });

  const plugins = Array.isArray(document.plugins) ? document.plugins.map(parseOperatorManifest) : [];
  return {
    version: 1,
    dag: { dagId: dag.dagId, schedule: dag.schedule, description: dag.description },
    nodes,
    edges,
    plugins,
  };
}

function pythonString(value: string): string {
  return JSON.stringify(value);
}

function pythonIdentifier(value: string, fallback: string): string {
  const normalized = value.toLowerCase().replace(/[^a-z0-9_]+/g, "_").replace(/^_+|_+$/g, "");
  const identifier = normalized || fallback;
  return /^[a-z_]/.test(identifier) ? identifier : `task_${identifier}`;
}

export function generateDagPython(document: DagDocument): string {
  const imports = new Set<string>();
  const taskNames = new Map<string, string>();
  const usedNames = new Set<string>();
  const plugins = new Map(document.plugins.map((plugin) => [plugin.name, plugin]));

  document.nodes.forEach((node, index) => {
    const baseName = pythonIdentifier(node.data.label, `task_${index + 1}`);
    let taskName = baseName;
    let suffix = 2;
    while (usedNames.has(taskName)) taskName = `${baseName}_${suffix++}`;
    usedNames.add(taskName);
    taskNames.set(node.id, taskName);
    if (node.data.operator === "EmptyOperator") {
      imports.add("from airflow.operators.empty import EmptyOperator");
    } else if (node.data.operator === "BashOperator") {
      imports.add("from airflow.operators.bash import BashOperator");
    } else if (node.data.operator === "SQLExecuteQueryOperator") {
      imports.add("from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator");
    } else {
      const plugin = plugins.get(node.data.operator);
      if (plugin) imports.add(`from ${plugin.module} import ${plugin.name}`);
    }
  });

  const lines = [
    'from datetime import datetime',
    "from airflow import DAG",
    ...Array.from(imports).sort(),
    "",
    `with DAG(`,
    `    dag_id=${pythonString(pythonIdentifier(document.dag.dagId, "new_dag"))},`,
    `    description=${pythonString(document.dag.description)},`,
    `    schedule=${document.dag.schedule ? pythonString(document.dag.schedule) : "None"},`,
    "    start_date=datetime(2026, 1, 1),",
    "    catchup=False,",
    ") as dag:",
  ];

  for (const node of document.nodes) {
    const taskName = taskNames.get(node.id)!;
    const args = [`task_id=${pythonString(taskName)}`, `retries=${Math.max(0, node.data.retries)}`];
    if (node.data.operator === "BashOperator") {
      args.push(`bash_command=${pythonString(node.data.params.bash_command ?? "")}`);
    }
    if (node.data.operator === "SQLExecuteQueryOperator") {
      args.push(`conn_id=${pythonString(node.data.params.conn_id ?? "")}`);
      args.push(`sql=${pythonString(node.data.params.sql ?? "")}`);
    } else if (plugins.has(node.data.operator)) {
      const plugin = plugins.get(node.data.operator)!;
      for (const field of plugin.fields) {
        args.push(`${field.name}=${pythonString(node.data.params[field.name] ?? "")}`);
      }
    }
    lines.push(`    ${taskName} = ${node.data.operator}(`);
    args.forEach((arg) => lines.push(`        ${arg},`));
    lines.push("    )");
  }

  if (document.edges.length) {
    lines.push("");
    for (const edge of document.edges) {
      const source = taskNames.get(edge.source);
      const target = taskNames.get(edge.target);
      if (source && target) lines.push(`    ${source} >> ${target}`);
    }
  }

  return `${lines.join("\n")}\n`;
}
