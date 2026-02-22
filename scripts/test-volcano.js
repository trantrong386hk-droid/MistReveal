#!/usr/bin/env node
/**
 * 火山引擎凭证验证脚本
 * 用法：node scripts/test-volcano.js
 */
const crypto = require("crypto");
const https  = require("https");
const fs     = require("fs");
const path   = require("path");

// ---------- 读取 .env ----------
const envPath = path.join(__dirname, "../.env");
const env = {};
fs.readFileSync(envPath, "utf8").split("\n").forEach(line => {
  const m = line.match(/^(\w+)\s*=\s*(.+)$/);
  if (m) env[m[1]] = m[2].trim();
});

const ak = env["VOLC_AK"];
const sk = env["VOLC_SK"];
if (!ak || !sk) { console.error("❌ .env 中 VOLC_AK 或 VOLC_SK 未填写"); process.exit(1); }
console.log(`AK 前8位: ${ak.slice(0,8)}  SK 前8位: ${sk.slice(0,8)}  SK 末4位: ${sk.slice(-4)}`);

// ---------- 签名工具 ----------
const HOST    = "visual.volcengineapi.com";
const REGION  = "cn-north-1";
const SERVICE = "cv";
const VERSION = "2022-08-31";

function sha256Hex(str) {
  return crypto.createHash("sha256").update(str, "utf8").digest("hex");
}
function hmacSHA256(key, data) {
  return crypto.createHmac("sha256", key).update(data, "utf8").digest();
}
function pad(n) { return String(n).padStart(2, "0"); }

function buildAuth(action, bodyStr) {
  const now = new Date();
  const xDate = `${now.getUTCFullYear()}${pad(now.getUTCMonth()+1)}${pad(now.getUTCDate())}T${pad(now.getUTCHours())}${pad(now.getUTCMinutes())}${pad(now.getUTCSeconds())}Z`;
  const dateStamp = xDate.slice(0, 8);

  const bodyHash   = sha256Hex(bodyStr);
  const contentType = "application/json";
  const canonicalHeaders = `content-type:${contentType}\nhost:${HOST}\nx-content-sha256:${bodyHash}\nx-date:${xDate}\n`;
  const signedHeaders    = "content-type;host;x-content-sha256;x-date";
  const cr = `POST\n/\nAction=${action}&Version=${VERSION}\n${canonicalHeaders}\n${signedHeaders}\n${bodyHash}`;

  const algorithm  = "HMAC-SHA256";
  const credScope  = `${dateStamp}/${REGION}/${SERVICE}/request`;
  const hashedCR   = sha256Hex(cr);
  const sts        = `${algorithm}\n${xDate}\n${credScope}\n${hashedCR}`;

  const kDate    = hmacSHA256(Buffer.from(sk, "utf8"),  dateStamp);
  const kRegion  = hmacSHA256(kDate,   REGION);
  const kService = hmacSHA256(kRegion, SERVICE);
  const kSigning = hmacSHA256(kService,"request");
  const signature = hmacSHA256(kSigning, sts).toString("hex");

  return {
    authorization: `${algorithm} Credential=${ak}/${credScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`,
    xDate, bodyHash, contentType,
  };
}

// ---------- 发送请求（用不存在的 task_id 查询，不产生费用）----------
const body    = JSON.stringify({ req_key: "jimeng_t2i_v40", task_id: "test-credential-check-000" });
const action  = "CVSync2AsyncGetResult";
const { authorization, xDate, bodyHash, contentType } = buildAuth(action, body);

const options = {
  hostname: HOST,
  path: `/?Action=${action}&Version=${VERSION}`,
  method: "POST",
  headers: {
    "Content-Type":    contentType,
    "Host":            HOST,
    "X-Date":          xDate,
    "X-Content-Sha256": bodyHash,
    "Authorization":   authorization,
    "Content-Length":  Buffer.byteLength(body),
  },
};

console.log("\n正在调用火山引擎 API...");
const req = https.request(options, res => {
  let data = "";
  res.on("data", chunk => data += chunk);
  res.on("end", () => {
    console.log(`HTTP 状态: ${res.statusCode}`);
    try {
      const json = JSON.parse(data);
      const err  = json?.ResponseMetadata?.Error;
      if (!err) {
        console.log("✅ 调用成功:", JSON.stringify(json, null, 2));
      } else if (err.Code === "SignatureDoesNotMatch") {
        console.log("❌ 签名错误 (SignatureDoesNotMatch) — AK/SK 有误");
      } else {
        // 任何其他错误（如 task 不存在）说明签名已通过
        console.log(`✅ 签名验证通过！（Volcano 返回业务错误: ${err.Code} — ${err.Message}）`);
      }
    } catch {
      console.log("原始响应:", data.slice(0, 500));
    }
  });
});
req.on("error", e => console.error("网络错误:", e.message));
req.write(body);
req.end();
