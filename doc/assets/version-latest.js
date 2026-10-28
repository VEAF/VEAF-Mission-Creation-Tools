// Version selector: the release carrying the "latest" alias opens /latest/, not its number.
//
// Material links every entry of the selector to `../<version>/`, so picking the newest release
// lands on /6.33.0/ and that is the URL people copy — stale on the next release. mike already
// serves the same pages under /latest/; this sends the reader there, on the same page when it
// exists. Needs `extra.version.alias: true`, which renders the alias next to the version.
(function () {
  "use strict";

  function versionRoot() {
    var config = document.getElementById("__config");
    var base = config ? JSON.parse(config.textContent).base : ".";
    return new URL(base.replace(/\/?$/, "/"), location.href);
  }

  // Capture phase, so this runs before Material's own handler on document.body.
  document.addEventListener(
    "click",
    function (event) {
      if (event.metaKey || event.ctrlKey || !(event.target instanceof Element)) {
        return;
      }
      var link = event.target.closest(".md-version__link");
      var alias = link && link.querySelector(".md-version__alias");
      if (!alias || alias.textContent.trim() !== "latest") {
        return;
      }
      event.preventDefault();
      event.stopPropagation();

      var root = versionRoot();
      var latest = new URL("../latest/", root);
      var page = location.href.startsWith(root.href) ? location.href.slice(root.href.length) : "";
      var samePage = new URL(page, latest);
      fetch(samePage.href, { method: "HEAD" })
        .then(function (response) {
          location.href = response.ok ? samePage.href : latest.href;
        })
        .catch(function () {
          location.href = latest.href;
        });
    },
    true
  );
})();
