import { useCallback, useMemo, useState } from "react";
import {
  addEdge,
  Background,
  BackgroundVariant,
  Controls,
  Handle,
  MiniMap,
  Position,
  ReactFlow,
  useEdgesState,
  useNodesState,
  useReactFlow,
  type Connection,
  type Edge,
  type Node,
  type NodeProps,
} from "@xyflow/react";
import type { DragEvent } from "react";
import {
  createTaskNode,
  defaultParams,
  generateDagPython,
  operatorCatalog,
  parseDagDocument,
  parseOperatorManifest,
  type DagDocument,
  type OperatorData,
  type OperatorKind,
  type RegisteredOperator,
} from "./dag";

const initialNodes: Node<OperatorData>[] = [
  {
    id: "start",
    type: "task",
    position: { x: 110, y: 170 },
    data: { label: "Start", operator: "EmptyOperator", retries: 0, params: {} },
  },
  {
    id: "transform",
    type: "task",
    position: { x: 390, y: 170 },
    data: {
      label: "Transform data",
      operator: "BashOperator",
      retries: 2,
      params: { bash_command: "echo 'Run your transformation'" },
    },
  },
  {
    id: "finish",
    type: "task",
    position: { x: 670, y: 170 },
    data: { label: "Finish", operator: "EmptyOperator", retries: 1, params: {} },
  },
];

const initialEdges: Edge[] = [
  { id: "start-transform", source: "start", target: "transform", type: "smoothstep" },
  { id: "transform-finish", source: "transform", target: "finish", type: "smoothstep" },
];

const nodeTypes = { task: TaskNode };

function TaskNode({ data, selected }: NodeProps<Node<OperatorData>>) {
  const catalogEntry = operatorCatalog.find((item) => item.kind === data.operator);
  return (
    <div className={`task-node${selected ? " selected" : ""}`}>
      <Handle type="target" position={Position.Left} />
      <div className="task-node-icon">{catalogEntry?.badge ?? "OP"}</div>
      <div className="task-node-copy">
        <strong>{data.label}</strong>
        <span>{data.operator}</span>
      </div>
      <Handle type="source" position={Position.Right} />
    </div>
  );
}

function downloadFile(filename: string, content: string, type: string) {
  const url = URL.createObjectURL(new Blob([content], { type }));
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}

export default function App() {
  const [nodes, setNodes, onNodesChange] = useNodesState<Node<OperatorData>>(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);
  const [plugins, setPlugins] = useState<RegisteredOperator[]>(() => {
    try {
      const saved = localStorage.getItem("airflow-dag-builder:operators");
      return saved ? (JSON.parse(saved) as unknown[]).map(parseOperatorManifest) : [];
    } catch (error) {
      console.error("Could not load registered operator manifests", error);
      return [];
    }
  });
  const [dagId, setDagId] = useState("my_first_dag");
  const [schedule, setSchedule] = useState("@daily");
  const [description, setDescription] = useState("A DAG created with Airflow DAG Builder.");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [showCode, setShowCode] = useState(false);
  const [notice, setNotice] = useState("");
  const [operatorSearch, setOperatorSearch] = useState("");
  const [showPluginModal, setShowPluginModal] = useState(false);
  const [pluginError, setPluginError] = useState("");
  const [pluginManifestText, setPluginManifestText] = useState(`{
  "name": "BigQueryCheckOperator",
  "module": "my_airflow_plugins.operators.bigquery_check",
  "label": "BigQuery check",
  "description": "Run a SQL assertion in BigQuery.",
  "fields": [
    { "name": "sql", "label": "SQL assertion", "type": "textarea", "defaultValue": "SELECT COUNT(*) > 0 FROM my_dataset.my_table" },
    { "name": "gcp_conn_id", "label": "GCP connection ID", "type": "text", "defaultValue": "google_cloud_default" }
  ]
}`);
  const { screenToFlowPosition, fitView, zoomIn, zoomOut } = useReactFlow();

  const selectedNode = nodes.find((node) => node.id === selectedId);
  const availableOperators = useMemo(
    () => [
      ...operatorCatalog,
      ...plugins.map((plugin) => ({
        kind: plugin.name,
        title: plugin.label,
        description: plugin.description,
        badge: "PL",
      })),
    ],
    [plugins],
  );
  const filteredOperators = availableOperators.filter((operator) =>
    `${operator.title} ${operator.kind} ${operator.description}`
      .toLowerCase()
      .includes(operatorSearch.toLowerCase()),
  );
  const selectedPlugin = selectedNode
    ? plugins.find((plugin) => plugin.name === selectedNode.data.operator)
    : undefined;
  const document: DagDocument = useMemo(
    () => ({
      version: 1,
      dag: { dagId, schedule, description },
      nodes,
      edges,
      plugins,
    }),
    [dagId, schedule, description, nodes, edges, plugins],
  );
  const generatedCode = useMemo(() => generateDagPython(document), [document]);

  const updateSelected = useCallback(
    (updates: Partial<OperatorData>) => {
      if (!selectedId) return;
      setNodes((current) =>
        current.map((node) =>
          node.id === selectedId ? { ...node, data: { ...node.data, ...updates } } : node,
        ),
      );
    },
    [selectedId, setNodes],
  );

  const addOperator = useCallback(
    (operator: OperatorKind, position?: { x: number; y: number }) => {
      const offset = nodes.length * 24;
      const plugin = plugins.find((item) => item.name === operator);
      const node = createTaskNode(operator, position ?? { x: 220 + offset, y: 280 + offset });
      if (plugin) {
        node.data.label = plugin.label;
        node.data.params = Object.fromEntries(
          plugin.fields.map((field) => [field.name, field.defaultValue]),
        );
      }
      setNodes((current) =>
        current.concat(node),
      );
    },
    [nodes.length, plugins, setNodes],
  );

  const onConnect = useCallback(
    (connection: Connection) =>
      setEdges((current) => addEdge({ ...connection, type: "smoothstep" }, current)),
    [setEdges],
  );

  const onDrop = useCallback(
    (event: DragEvent) => {
      event.preventDefault();
      const operator = event.dataTransfer.getData("application/airflow-operator") as OperatorKind;
      if (!availableOperators.some((item) => item.kind === operator)) return;
      addOperator(operator, screenToFlowPosition({ x: event.clientX, y: event.clientY }));
    },
    [addOperator, availableOperators, screenToFlowPosition],
  );

  const saveDraft = () => {
    localStorage.setItem("airflow-dag-builder:draft", JSON.stringify(document));
    setNotice("Draft saved in this browser");
    window.setTimeout(() => setNotice(""), 2600);
  };

  const loadDraft = () => {
    const saved = localStorage.getItem("airflow-dag-builder:draft");
    if (!saved) {
      setNotice("No saved draft found");
      window.setTimeout(() => setNotice(""), 2600);
      return;
    }
    try {
      const draft = parseDagDocument(JSON.parse(saved) as unknown);
      const savedPlugins = draft.plugins;
      localStorage.setItem("airflow-dag-builder:operators", JSON.stringify(savedPlugins));
      setDagId(draft.dag.dagId);
      setSchedule(draft.dag.schedule);
      setDescription(draft.dag.description);
      setNodes(draft.nodes);
      setEdges(draft.edges);
      setPlugins(savedPlugins);
      setSelectedId(null);
      setNotice("Draft loaded");
    } catch (error) {
      console.error("Could not load the saved DAG draft", error);
      setNotice("Saved draft is invalid");
    }
    window.setTimeout(() => setNotice(""), 2600);
  };

  const registerPlugin = () => {
    try {
      const plugin = parseOperatorManifest(JSON.parse(pluginManifestText) as unknown);
      if (
        operatorCatalog.some((operator) => operator.kind === plugin.name) ||
        plugins.some((registered) => registered.name === plugin.name)
      ) {
        throw new Error(`An operator named "${plugin.name}" is already registered.`);
      }
      const updatedPlugins = [...plugins, plugin];
      localStorage.setItem("airflow-dag-builder:operators", JSON.stringify(updatedPlugins));
      setPlugins(updatedPlugins);
      setPluginError("");
      setShowPluginModal(false);
      setNotice(`Registered ${plugin.label}`);
      window.setTimeout(() => setNotice(""), 2600);
    } catch (error) {
      setPluginError(error instanceof Error ? error.message : "Could not register this manifest.");
    }
  };

  return (
    <main className="app-shell">
      <header className="topbar">
        <div className="brand">
          <div className="brand-mark">A</div>
          <span>Airflow <b>DAG Builder</b></span>
          <span className="prototype-badge">EARLY ACCESS</span>
        </div>
        <div className="topbar-actions">
          {notice && <span className="notice">{notice}</span>}
          <button className="button button-quiet" onClick={loadDraft}>Open draft</button>
          <button className="button button-quiet" onClick={saveDraft}>Save draft</button>
          <button
            className="button button-quiet"
            onClick={() =>
              downloadFile(`${dagId || "dag"}.json`, JSON.stringify(document, null, 2), "application/json")
            }
          >
            Export JSON
          </button>
          <button className="button button-primary" onClick={() => setShowCode(true)}>
            <span className="play-icon">{"</>"}</span> Preview DAG
          </button>
        </div>
      </header>

      <section className="project-bar">
        <div className="breadcrumb"><span>Workspace</span><i>/</i><b>{dagId || "Untitled DAG"}</b></div>
        <div className="dag-settings">
          <label>
            <span>DAG ID</span>
            <input value={dagId} onChange={(event) => setDagId(event.target.value)} aria-label="DAG ID" />
          </label>
          <label>
            <span>Schedule</span>
            <select value={schedule} onChange={(event) => setSchedule(event.target.value)} aria-label="Schedule">
              <option value="@daily">@daily</option>
              <option value="@hourly">@hourly</option>
              <option value="@weekly">@weekly</option>
              <option value="0 8 * * *">0 8 * * *</option>
              <option value="">None (manual)</option>
            </select>
          </label>
        </div>
        <div className="environment"><span className="status-dot" /> Local draft</div>
      </section>

      <div className="workspace">
        <aside className="palette sidebar">
          <div className="sidebar-heading">
            <div>
              <h2>Operators</h2>
              <p>Drag onto canvas or click to add</p>
            </div>
            <button className="icon-button" title="Register custom operator" aria-label="Register custom operator" onClick={() => { setPluginError(""); setShowPluginModal(true); }}>+</button>
          </div>
          <div className="search-box"><span>⌕</span><input aria-label="Search operators" placeholder="Search operators" value={operatorSearch} onChange={(event) => setOperatorSearch(event.target.value)} /></div>
          <div className="operator-category">BASIC OPERATORS <span>{filteredOperators.length}</span></div>
          <div className="operator-list">
            {filteredOperators.map((operator) => (
              <button
                className="operator-card"
                key={operator.kind}
                draggable
                onClick={() => addOperator(operator.kind)}
                onDragStart={(event) => {
                  event.dataTransfer.setData("application/airflow-operator", operator.kind);
                  event.dataTransfer.effectAllowed = "move";
                }}
              >
                <span className={`operator-badge badge-${operator.badge.toLowerCase()}`}>{operator.badge}</span>
                <span className="operator-copy"><strong>{operator.title}</strong><small>{operator.description}</small></span>
                <span className="operator-add">+</span>
              </button>
            ))}
            {filteredOperators.length === 0 && <p className="empty-search">No matching operators</p>}
          </div>
          <div className="plugin-callout">
            <span className="plugin-icon">✳</span>
            <strong>Your operators</strong>
            <p>Register custom Airflow operators to use them in your DAGs.</p>
            <button onClick={() => { setPluginError(""); setShowPluginModal(true); }}>Register an operator <span>→</span></button>
          </div>
          <div className="sidebar-foot"><span className="green-dot" /> Editor ready <span>v0.1.0</span></div>
        </aside>

        <section
          className="canvas-area"
          onDrop={onDrop}
          onDragOver={(event) => {
            event.preventDefault();
            event.dataTransfer.dropEffect = "move";
          }}
        >
          <div className="canvas-toolbar">
            <div className="canvas-title"><span className="flow-icon">⌘</span><b>{dagId || "Untitled DAG"}</b><span className="unsaved">Unsaved</span></div>
            <div className="canvas-tools">
              <button title="Zoom out" aria-label="Zoom out" onClick={() => zoomOut()}>−</button>
              <button title="Zoom in" aria-label="Zoom in" onClick={() => zoomIn()}>+</button>
              <span className="tool-divider" />
              <button title="Fit view" aria-label="Fit view" onClick={() => fitView({ padding: 0.3 })}>⛶</button>
            </div>
          </div>
          <div className="canvas">
            <div className="canvas-hint"><span className="hint-key">TIP</span> Connect tasks by dragging from a dot to another task.</div>
            <ReactFlow
              nodes={nodes}
              edges={edges}
              nodeTypes={nodeTypes}
              onNodesChange={onNodesChange}
              onEdgesChange={onEdgesChange}
              onConnect={onConnect}
              onNodeClick={(_, node) => setSelectedId(node.id)}
              onPaneClick={() => setSelectedId(null)}
              fitView
              fitViewOptions={{ padding: 0.3 }}
              proOptions={{ hideAttribution: true }}
              defaultEdgeOptions={{ type: "smoothstep" }}
            >
              <Background variant={BackgroundVariant.Dots} gap={22} size={1} color="#29333e" />
              <Controls position="bottom-left" showInteractive={false} />
              <MiniMap
                position="bottom-right"
                pannable
                zoomable
                nodeColor={(node) => node.id === selectedId ? "#65d6b1" : "#516070"}
                maskColor="rgba(13, 17, 23, 0.72)"
              />
            </ReactFlow>
          </div>
          <div className="canvas-footer">
            <span>{nodes.length} tasks <i>·</i> {edges.length} connections</span>
            <span>Airflow DAG <i>·</i> Python</span>
          </div>
        </section>

        <aside className="properties sidebar">
          <div className="sidebar-heading">
            <div><h2>{selectedNode ? "Task settings" : "DAG settings"}</h2><p>{selectedNode ? "Configure selected task" : "Workflow configuration"}</p></div>
            {selectedNode && <button className="icon-button close-button" aria-label="Deselect task" onClick={() => setSelectedId(null)}>×</button>}
          </div>
          {selectedNode ? (
            <div className="property-form">
              <div className="selected-operator"><span className="operator-badge badge-op">{operatorCatalog.find((item) => item.kind === selectedNode.data.operator)?.badge}</span><div><strong>{selectedNode.data.operator}</strong><small>Apache Airflow operator</small></div></div>
              <label className="field"><span>Task name</span><input value={selectedNode.data.label} onChange={(event) => updateSelected({ label: event.target.value })} /></label>
              <label className="field"><span>Operator type</span><select value={selectedNode.data.operator} onChange={(event) => { const operator = event.target.value as OperatorKind; const plugin = plugins.find((item) => item.name === operator); updateSelected({ operator, params: plugin ? Object.fromEntries(plugin.fields.map((field) => [field.name, field.defaultValue])) : defaultParams(operator) }); }}><optgroup label="Built in"><option value="EmptyOperator">EmptyOperator</option><option value="BashOperator">BashOperator</option><option value="SQLExecuteQueryOperator">SQLExecuteQueryOperator</option></optgroup>{plugins.length > 0 && <optgroup label="Registered">{plugins.map((plugin) => <option key={plugin.name} value={plugin.name}>{plugin.label}</option>)}</optgroup>}</select></label>
              {selectedNode.data.operator === "BashOperator" && <label className="field"><span>Bash command</span><textarea rows={4} value={selectedNode.data.params.bash_command ?? ""} onChange={(event) => updateSelected({ params: { ...selectedNode.data.params, bash_command: event.target.value } })} /></label>}
              {selectedNode.data.operator === "SQLExecuteQueryOperator" && <>
                <label className="field"><span>Airflow connection ID</span><input value={selectedNode.data.params.conn_id ?? ""} onChange={(event) => updateSelected({ params: { ...selectedNode.data.params, conn_id: event.target.value } })} /></label>
                <label className="field"><span>SQL query</span><textarea rows={5} value={selectedNode.data.params.sql ?? ""} onChange={(event) => updateSelected({ params: { ...selectedNode.data.params, sql: event.target.value } })} /></label>
              </>}
              {selectedPlugin?.fields.map((field) => (
                <label className="field" key={field.name}>
                  <span>{field.label}</span>
                  {field.type === "textarea" ? (
                    <textarea rows={4} value={selectedNode.data.params[field.name] ?? ""} onChange={(event) => updateSelected({ params: { ...selectedNode.data.params, [field.name]: event.target.value } })} />
                  ) : (
                    <input value={selectedNode.data.params[field.name] ?? ""} onChange={(event) => updateSelected({ params: { ...selectedNode.data.params, [field.name]: event.target.value } })} />
                  )}
                </label>
              ))}
              <label className="field"><span>Retries</span><input type="number" min={0} value={selectedNode.data.retries} onChange={(event) => updateSelected({ retries: Math.max(0, Number(event.target.value)) })} /></label>
              <button className="delete-task" onClick={() => { setNodes((current) => current.filter((node) => node.id !== selectedId)); setEdges((current) => current.filter((edge) => edge.source !== selectedId && edge.target !== selectedId)); setSelectedId(null); }}>Delete task</button>
            </div>
          ) : (
            <>
              <div className="form-section-label">OVERVIEW</div>
              <label className="field"><span>Description</span><textarea rows={4} value={description} onChange={(event) => setDescription(event.target.value)} /></label>
              <div className="form-section-label spacing-top">WORKFLOW</div>
              <div className="summary-card"><div><span>Tasks</span><b>{nodes.length}</b></div><div><span>Dependencies</span><b>{edges.length}</b></div></div>
              <div className="info-card"><span className="info-mark">i</span><p>Select a task on the canvas to configure its operator and parameters.</p></div>
            </>
          )}
          <div className="properties-bottom"><span>Need help?</span><button onClick={() => setShowCode(true)}>View generated Python <span>→</span></button></div>
        </aside>
      </div>

      {showCode && (
        <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setShowCode(false); }}>
          <section className="code-modal" role="dialog" aria-modal="true" aria-labelledby="preview-title">
            <header><div><span className="modal-kicker">GENERATED FILE</span><h2 id="preview-title">{dagId || "dag"}.py</h2></div><button className="icon-button close-button" aria-label="Close preview" onClick={() => setShowCode(false)}>×</button></header>
            <p className="modal-description">Preview the Airflow Python generated from this workflow.</p>
            <pre><code>{generatedCode}</code></pre>
            <footer>
              <span>Review generated code before deploying to Airflow.</span>
              <div>
                <button className="button button-quiet" onClick={() => downloadFile(`${dagId || "dag"}.py`, generatedCode, "text/x-python")}>Download .py</button>
                <button className="button button-primary" onClick={async () => { await navigator.clipboard.writeText(generatedCode); setNotice("Python copied to clipboard"); setTimeout(() => setNotice(""), 2600); }}>Copy code</button>
              </div>
            </footer>
          </section>
        </div>
      )}
      {showPluginModal && (
        <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setShowPluginModal(false); }}>
          <section className="code-modal plugin-modal" role="dialog" aria-modal="true" aria-labelledby="plugin-title">
            <header><div><span className="modal-kicker">OPERATOR REGISTRY</span><h2 id="plugin-title">Register a custom operator</h2></div><button className="icon-button close-button" aria-label="Close registration" onClick={() => setShowPluginModal(false)}>×</button></header>
            <p className="modal-description">Add a JSON manifest for a Python operator already available in your Airflow environment. This registers its UI fields; it does not install Python code.</p>
            <label className="manifest-editor"><span>Operator manifest</span><textarea spellCheck={false} value={pluginManifestText} onChange={(event) => setPluginManifestText(event.target.value)} /></label>
            {pluginError && <p className="plugin-error" role="alert">{pluginError}</p>}
            <footer>
              <span>Python class and field names must be valid identifiers.</span>
              <div>
                <button className="button button-quiet" onClick={() => setShowPluginModal(false)}>Cancel</button>
                <button className="button button-primary" onClick={registerPlugin}>Register operator</button>
              </div>
            </footer>
          </section>
        </div>
      )}
    </main>
  );
}
