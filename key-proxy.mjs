import http from "node:http";
const SECRET = process.env.MCP_PATH_SECRET, KEY = process.env.MCP_KEY;
const UP = parseInt(process.env.INTERNAL_PORT || "20128"), LISTEN = parseInt(process.env.PROXY_PORT || "7860");
const PREFIX = "/" + SECRET;
http.createServer((req, res) => {
  const headers = { ...req.headers };
  let path = req.url;
  const s = path === PREFIX || path.startsWith(PREFIX + "/") || path.startsWith(PREFIX + "?");
  if (s) { path = path.slice(PREFIX.length) || "/"; if (path.startsWith("?")) path = "/" + path; headers["authorization"] = "Bearer " + KEY; }
  else delete headers["authorization"];
  headers.host = "127.0.0.1:" + UP;
  const up = http.request({ host: "127.0.0.1", port: UP, method: req.method, path, headers }, (r) => {
    res.writeHead(r.statusCode, r.headers);
    console.log(new Date().toISOString(), req.method, s ? "[S]" + path.slice(0, 60) : path.slice(0, 60), r.statusCode);
    r.pipe(res);
  });
  up.on("error", () => { if (!res.headersSent) res.writeHead(502); res.end("upstream error"); });
  req.pipe(up);
}).listen(LISTEN, "0.0.0.0", () => console.log("proxy listening on", LISTEN));
