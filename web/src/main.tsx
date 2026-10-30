// A redeploy invalidates old lazy-chunk URLs; stale tabs would otherwise
// break on the next dynamic import (e.g. the PDF viewer). Reload once.
window.addEventListener("vite:preloadError", (event) => {
  event.preventDefault();
  window.location.reload();
});

import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import "./index.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
