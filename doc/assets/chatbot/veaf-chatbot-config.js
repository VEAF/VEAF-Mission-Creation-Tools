/*
 * VEAF chatbot endpoint configuration.
 * Loaded before veaf-chatbot.js so it can set the Worker URL.
 *
 * Environment-aware: uses the local `wrangler dev` Worker when the docs are served from
 * localhost, and the deployed production Worker everywhere else (e.g. veaf.github.io).
 *
 * After `wrangler deploy`, set PROD_ENDPOINT to your Worker URL once. The same committed file
 * then works both locally and in production — no manual toggling.
 */
(function () {
  "use strict";
  var PROD_ENDPOINT = "https://veaf-docs-chatbot.veaf.workers.dev/chat";
  var LOCAL_ENDPOINT = "http://localhost:8787/chat";
  var isLocal = location.hostname === "localhost" || location.hostname === "127.0.0.1";
  window.VEAF_CHATBOT_ENDPOINT = isLocal ? LOCAL_ENDPOINT : PROD_ENDPOINT;
})();
