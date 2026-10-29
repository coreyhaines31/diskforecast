import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { runDiskForecast } from "./cli.js";

const VERSION = "0.1.0";

const server = new McpServer(
  { name: "diskforecast", version: VERSION },
  {
    instructions:
      "Disk Forecast answers disk space questions about this Mac: what's eating the disk, what can be cleaned up, " +
      "and how fast it's filling. Sizes are in bytes. These tools only read; moving anything to the Trash is done " +
      "by the person in the Disk Forecast app. For CPU and memory (what's slowing the Mac down), use Spare instead.",
  },
);

const readOnly = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
} as const;

async function respond(args: string[]) {
  const result = await runDiskForecast(args);
  return {
    content: [{ type: "text" as const, text: result.text }],
    ...(result.ok ? {} : { isError: true }),
  };
}

server.registerTool(
  "disk_status",
  {
    title: "Disk space and forecast",
    description:
      "Free space and capacity, how fast the disk is filling (bytesPerDay, daysUntilFull, a one-line forecast like " +
      "'Full in ~3 days'), whether it's low on space, purgeable space, and how much is safe to clear. " +
      "Start here for 'how much space do I have?' or 'how fast is my disk filling?'. " +
      "Covers disk space only; for CPU and memory, use Spare.",
    inputSchema: {},
    annotations: { ...readOnly, title: "Disk space and forecast" },
  },
  async () => respond(["status"]),
);

server.registerTool(
  "disk_changes",
  {
    title: "What's been filling the disk",
    description:
      "Which folders grew or shrank over the last N days, as a tree of home-relative paths with oldBytes and newBytes " +
      "(oldBytes 0 means new), plus outsideHomeBytes for System Data, other accounts, and apps. " +
      "Use for 'what's eating my disk?' or 'what filled it up this month?'.",
    inputSchema: {
      days: z
        .number()
        .int()
        .min(1)
        .max(120)
        .default(7)
        .describe("How many days back to compare, 1-120. Default 7."),
    },
    annotations: { ...readOnly, title: "What's been filling the disk" },
  },
  async ({ days }) => respond(["changes", "--days", String(days)]),
);

server.registerTool(
  "cleanup_list",
  {
    title: "What can be cleaned up",
    description:
      "What can be reclaimed, grouped as safeToClear (caches, logs, old build folders that rebuild themselves) and " +
      "worthALook (needs the person's judgment, like git worktrees, big downloads, or AI models). Each item has an id, " +
      "bytes, an explanation of why it's safe or worth a look, and its entries (paths with sizes). Items with a tool " +
      "are reclaimed with that tool's own command, not the Trash. Use for 'what can I clean up?'. " +
      "Read-only: to clear something, the person uses Cleanup in the Disk Forecast app.",
    inputSchema: {},
    annotations: { ...readOnly, title: "What can be cleaned up" },
  },
  async () => respond(["cleanup"]),
);

await server.connect(new StdioServerTransport());
