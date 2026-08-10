const MODE_KEY = "pdf-dark-mode";

async function main() {
  const streamInfo = await chrome.mimeHandler.getStreamInfo();

  const response = await fetch(streamInfo.streamUrl);

  if (!response.ok) {
    throw new Error(`Failed to read PDF stream: ${response.status}`);
  }

  const data = await response.arrayBuffer();

  const blob = new Blob([data], {
    type: "application/pdf",
  });

  const url = URL.createObjectURL(blob);

  const pdf = document.querySelector("#pdf");
  const toggle = document.querySelector("#mode-toggle");

  let mode = localStorage.getItem(MODE_KEY) ?? "normal";

  function applyMode() {
    const dark = mode === "dark";

    pdf.classList.toggle("dark", dark);

    toggle.textContent = dark ? "Dark" : "Normal";
    toggle.setAttribute("aria-pressed", dark.toString());

    localStorage.setItem(MODE_KEY, mode);
  }

  toggle.addEventListener("click", () => {
    mode = mode === "dark" ? "normal" : "dark";
    applyMode();
  });

  applyMode();

  pdf.src = url;

  window.addEventListener("beforeunload", () => URL.revokeObjectURL(url), {
    once: true,
  });
}

main().catch(console.error);
