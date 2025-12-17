import styles from "./page.module.css";

function AppleIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

function GitHubIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.865 8.17 6.839 9.49.5.092.682-.217.682-.482 0-.237-.008-.866-.013-1.7-2.782.604-3.369-1.34-3.369-1.34-.454-1.156-1.11-1.464-1.11-1.464-.908-.62.069-.608.069-.608 1.003.07 1.531 1.03 1.531 1.03.892 1.529 2.341 1.087 2.91.831.092-.646.35-1.086.636-1.336-2.22-.253-4.555-1.11-4.555-4.943 0-1.091.39-1.984 1.029-2.683-.103-.253-.446-1.27.098-2.647 0 0 .84-.269 2.75 1.025A9.578 9.578 0 0112 6.836c.85.004 1.705.114 2.504.336 1.909-1.294 2.747-1.025 2.747-1.025.546 1.377.203 2.394.1 2.647.64.699 1.028 1.592 1.028 2.683 0 3.842-2.339 4.687-4.566 4.935.359.309.678.919.678 1.852 0 1.336-.012 2.415-.012 2.743 0 .267.18.578.688.48C19.138 20.167 22 16.418 22 12c0-5.523-4.477-10-10-10z" />
    </svg>
  );
}

export default function Home() {
  return (
    <div className={styles.container}>
      <main className={styles.main}>
        <div className={styles.content}>
          <div className={styles.titleRow}>
            <h1 className={styles.title}>Hermes</h1>
            <span className={styles.badge}>Beta</span>
          </div>

          <div className={styles.subtitle}>
            <p>A discrete meeting recorder for macOS.</p>
            <p>Local-first.</p>
            <p>One click to record and transcribe.</p>
          </div>

          <a
            className={styles.downloadButton}
            href="https://github.com/viraatdas/Hermes/releases/download/v0.1.7/Hermes-v0.1.7.dmg"
            target="_blank"
            rel="noopener noreferrer"
          >
            <AppleIcon />
            <span>Download for macOS</span>
          </a>

          <div className={styles.links}>
            <div className={styles.linkRow}>
              <span className={styles.muted}>Open source</span>
              <span className={styles.dot}>·</span>
              <a
                className={styles.link}
                href="https://github.com/viraatdas/Hermes"
                target="_blank"
                rel="noopener noreferrer"
              >
                <GitHubIcon />
                <span>GitHub</span>
              </a>
            </div>
            <div className={styles.linkRow}>
              <span className={styles.muted}>Suggestions / contact:</span>
              <a className={styles.link} href="mailto:viraat@exla.ai">
                viraat@exla.ai
              </a>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
