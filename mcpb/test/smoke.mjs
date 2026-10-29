// Starts the built server over stdio, calls every tool against this Mac, and fails
// if a call that should work errors or a call that should fail doesn't.
// Run: npm test. SERVER=<path> runs an unpacked .mcpb instead of server/index.mjs.
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const ok = true;
const fails = false;
// [tool, arguments, should work, top-level key the CLI's JSON must have]
const calls = [
  ["disk_status", {}, ok, "status"],
  ["disk_changes", {}, ok, "changes"],
  ["disk_changes", { days: 30 }, ok, "changes"],
  ["disk_changes", { days: 0 }, fails],
  ["disk_changes", { days: 121 }, fails],
  ["disk_changes", { days: 2.5 }, fails],
  ["cleanup_list", {}, ok, "cleanup"],
  ["disk_trash", { id: "logs" }, fails],
];
// Against a fake CLI: the exact argv each tool sends, and how CLI errors come back.
const fakeCalls = [
  ["echo", "disk_status", {}, ok, "status --json"],
  ["echo", "disk_changes", {}, ok, "changes --days 7 --json"],
  ["echo", "disk_changes", { days: 120 }, ok, "changes --days 120 --json"],
  ["echo", "cleanup_list", {}, ok, "cleanup --json"],
  ["json-error", "disk_status", {}, fails, "fake json error"],
  ["stderr", "disk_status", {}, fails, "fake stderr error"],
];
const expectedTools = ["cleanup_list", "disk_changes", "disk_status"];
const server = process.env.SERVER ?? new URL("../server/index.mjs", import.meta.url).pathname;
const fakeCli = new URL("./fake-cli.sh", import.meta.url).pathname;
const max = Number(process.env.SMOKE_CHARS ?? 600);
const failures = [];

async function connect(env) {
  const transport = new StdioClientTransport({ command: process.execPath, args: [server], env: { ...process.env, ...env } });
  const client = new Client({ name: "diskforecast-smoke", version: "0.0.0" });
  await client.connect(transport);
  return client;
}

async function call(client, name, args) {
  let result;
  try {
    result = await client.callTool({ name, arguments: args });
  } catch (error) {
    result = { isError: true, content: [{ type: "text", text: `protocol error: ${error.message}` }] };
  }
  return { isError: Boolean(result.isError), text: result.content.map((c) => c.text).join("\n") };
}

function show(label, { isError, text }) {
  const shown = text.length > max ? `${text.slice(0, max)}\n… (${text.length} chars)` : text;
  console.log(`\n### ${label}${isError ? " [isError]" : ""}\n${shown}`);
}

const client = await connect({ DISKFORECAST_CLI: process.env.DISKFORECAST_CLI ?? "" });
const { tools } = await client.listTools();
console.log(`tools: ${tools.map((t) => t.name).join(", ")}`);
if (tools.map((t) => t.name).sort().join() !== expectedTools.join()) {
  throw new Error(`expected exactly these tools: ${expectedTools.join(", ")}`);
}
for (const tool of tools) {
  if (!tool.annotations?.readOnlyHint || tool.annotations?.destructiveHint !== false) {
    throw new Error(`${tool.name} is not annotated read-only`);
  }
}

for (const [name, args, shouldWork, key] of calls) {
  const label = `${name} ${JSON.stringify(args)}`;
  const result = await call(client, name, args);
  show(label, result);
  if (result.isError === shouldWork) failures.push(label);
  else if (shouldWork) {
    let parsed;
    try {
      parsed = JSON.parse(result.text);
    } catch {
      parsed = null;
    }
    if (!parsed?.[key]) failures.push(`${label} (no "${key}" in the output)`);
  }
}
await client.close();

for (const [mode, name, args, shouldWork, expected] of fakeCalls) {
  const label = `fake CLI (${mode}) ${name} ${JSON.stringify(args)}`;
  const fake = await connect({ DISKFORECAST_CLI: fakeCli, FAKE_MODE: mode });
  const result = await call(fake, name, args);
  await fake.close();
  show(label, result);
  const wanted = shouldWork ? JSON.stringify({ argv: expected }) : expected;
  if (result.isError === shouldWork || result.text !== wanted) failures.push(label);
}

if (failures.length) {
  console.error(`\nFAILED: ${failures.join("; ")}`);
  process.exit(1);
}
console.log(`\nAll ${calls.length + fakeCalls.length} calls behaved as expected.`);
